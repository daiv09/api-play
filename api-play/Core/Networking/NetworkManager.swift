import Foundation
import Combine
import SwiftUI

// MARK: - NetworkError

enum NetworkError: LocalizedError {
    case invalidURL
    case noResponse
    case httpError(Int)
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "The URL is invalid."
        case .noResponse:           return "No HTTP response received."
        case .httpError(let code):  return "HTTP \(code)"
        case .underlying(let err):  return err.localizedDescription
        }
    }
}

// MARK: - NetworkManager

@MainActor
final class NetworkManager: ObservableObject {

    @Published var isLoading = false
    @Published var response: APIResponse?
    @Published var error: NetworkError?

    // MARK: - Execute Request

    func execute(_ request: APIRequest, env: APIEnvironment?, isRetry: Bool = false) async -> APIResponse? {
            guard let url = buildURL(from: request, environment: env) else {
                self.error = .invalidURL
                return nil
            }

            isLoading = true
            error = nil

            var urlRequest = URLRequest(url: url)

            // METHOD (GraphQL always POST)
            if request.requestType == .graphql {
                urlRequest.httpMethod = "POST"
            } else {
                urlRequest.httpMethod = request.httpMethod.rawValue
            }

            // MARK: - Headers
            for pair in request.headers where pair.isEnabled && !pair.key.isEmpty {
                urlRequest.setValue(
                    interpolate(pair.value, env: env),
                    forHTTPHeaderField: pair.key
                )
            }

            // MARK: - Auth
            applyAuth(to: &urlRequest, from: request, env: env)

            // MARK: - Body
            if request.requestType == .graphql {
                applyGraphQLBody(to: &urlRequest, request: request)
            } else {
                applyRESTBody(to: &urlRequest, request: request)
            }

            // MARK: - Execute
            let start = Date()

            do {
                let isStreamingRequested = request.headers.contains(where: { 
                    $0.isEnabled && $0.key.lowercased() == "accept" && 
                    ($0.value.lowercased().contains("event-stream") || $0.value.lowercased().contains("ndjson")) 
                })
                
                let data: Data?
                let asyncBytes: URLSession.AsyncBytes?
                let urlResponse: URLResponse
                
                if isStreamingRequested {
                    let res = try await URLSession.shared.bytes(for: urlRequest)
                    asyncBytes = res.0
                    urlResponse = res.1
                    data = nil
                } else {
                    let res = try await URLSession.shared.data(for: urlRequest)
                    data = res.0
                    urlResponse = res.1
                    asyncBytes = nil
                }
                
                let elapsed = Date().timeIntervalSince(start)

                guard let http = urlResponse as? HTTPURLResponse else {
                    self.error = .noResponse
                    isLoading = false
                    return nil
                }
                
                // MARK: - Smart Auth Token Refresh (401 Interceptor)
                if http.statusCode == 401 && !isRetry {
                    if let refreshUrlStr = env?.variables.first(where: { $0.key == "refresh_url" })?.value,
                       let refreshUrl = URL(string: interpolate(refreshUrlStr, env: env)) {
                        
                        var refreshReq = URLRequest(url: refreshUrl)
                        refreshReq.httpMethod = "POST"
                        
                        let refreshToken = KeychainHelper.read(forKey: "refresh_token") ?? env?.variables.first(where: { $0.key == "refresh_token" })?.value
                        
                        if let token = refreshToken {
                            refreshReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                        }
                        
                        if let (refreshData, refreshResp) = try? await URLSession.shared.data(for: refreshReq),
                           let refreshHttp = refreshResp as? HTTPURLResponse, refreshHttp.statusCode == 200 {
                            
                            if let json = try? JSONSerialization.jsonObject(with: refreshData) as? [String: Any],
                               let newAccessToken = json["access_token"] as? String {
                                
                                if let tokenVar = env?.variables.first(where: { $0.key == "access_token" }) {
                                    tokenVar.value = newAccessToken
                                }
                                KeychainHelper.write(newAccessToken, forKey: "access_token")
                                
                                return await execute(request, env: env, isRetry: true)
                            }
                        }
                    }
                }

                let headers = Dictionary(uniqueKeysWithValues:
                    http.allHeaderFields.compactMap { k, v -> (String, String)? in
                        guard let key = k as? String,
                              let value = v as? String else { return nil }
                        return (key, value)
                    }
                )

                let contentType = headers["Content-Type"]?.lowercased() ?? ""
                let isStreamingResponse = contentType.contains("text/event-stream") || contentType.contains("application/x-ndjson")
                let isBinary = contentType.contains("image/") || contentType.contains("pdf") || contentType.contains("video/") || contentType.contains("audio/")
                
                if isStreamingResponse, let bytes = asyncBytes {
                    var bodyString = ""
                    var dataBuffer = Data()
                    
                    var apiResponse = APIResponse(
                        statusCode: http.statusCode,
                        bodyData: nil,
                        headers: headers,
                        body: "",
                        elapsedSeconds: elapsed,
                        byteCount: 0,
                        url: url.absoluteString
                    )
                    
                    self.response = apiResponse
                    request.lastResponse = apiResponse
                    isLoading = false
                    
                    for try await line in bytes.lines {
                        bodyString += line + "\n"
                        if let lineData = (line + "\n").data(using: .utf8) {
                            dataBuffer.append(lineData)
                        }
                        
                        apiResponse.bodyData = dataBuffer
                        apiResponse.body = bodyString
                        apiResponse.byteCount = dataBuffer.count
                        
                        self.response = apiResponse
                        request.lastResponse = apiResponse
                    }
                    
                    return apiResponse
                    
                } else {
                    let finalData: Data
                    if let d = data {
                        finalData = d
                    } else if let bytes = asyncBytes {
                        var temp = Data()
                        for try await b in bytes { temp.append(b) }
                        finalData = temp
                    } else {
                        finalData = Data()
                    }
                    
                    let bodyString: String
                    if isBinary {
                        bodyString = "[Binary Data: \(ByteCountFormatter.string(fromByteCount: Int64(finalData.count), countStyle: .file))]"
                    } else {
                        bodyString = String(data: finalData, encoding: .utf8) ?? "<Unable to decode string>"
                    }

                    let apiResponse = APIResponse(
                        statusCode: http.statusCode,
                        bodyData: finalData,
                        headers: headers,
                        body: bodyString,
                        elapsedSeconds: elapsed,
                        byteCount: finalData.count,
                        url: url.absoluteString
                    )

                    self.response = apiResponse
                    isLoading = false
                    
                    // Track Schema Drift
                    if let jsonData = finalData as Data?, let json = try? JSONSerialization.jsonObject(with: jsonData) {
                        let currentSchema = SchemaDriftMonitor.generateSchema(for: json)
                        if request.baselineSchema == nil {
                            request.baselineSchema = currentSchema
                        } else if request.baselineSchema != currentSchema {
                            request.hasDrifted = true
                        } else {
                            request.hasDrifted = false
                        }
                    }

                    return apiResponse
                }

            } catch {
                self.error = .underlying(error)
                isLoading = false
                return nil
            }
        }
    // MARK: - REST Body 

    /// Extracts a value from a JSON response body using dot-notation (e.g. "data.user.id" or "items[0].id")
    func extractValue(from response: APIResponse, keyPath: String) -> String? {
        guard let data = response.bodyData,
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        
        let components = keyPath.split(separator: ".").map(String.init)
        var current: Any = json
        
        for component in components {
            if let bracketStart = component.firstIndex(of: "["),
               let bracketEnd = component.firstIndex(of: "]"),
               bracketStart < bracketEnd {
                
                let arrayName = String(component[..<bracketStart])
                let indexString = String(component[component.index(after: bracketStart)..<bracketEnd])
                
                guard let index = Int(indexString) else { return nil }
                
                if arrayName.isEmpty {
                    if let array = current as? [Any], index < array.count {
                        current = array[index]
                    } else { return nil }
                } else {
                    if let dict = current as? [String: Any], let array = dict[arrayName] as? [Any], index < array.count {
                        current = array[index]
                    } else { return nil }
                }
            } else {
                if let dict = current as? [String: Any], let val = dict[component] {
                    current = val
                } else {
                    return nil
                }
            }
        }
        
        return "\(current)"
    }
    
    private func applyRESTBody(to requestObj: inout URLRequest, request: APIRequest) {
        guard !request.requestBody.isEmpty,
              request.httpMethod != .GET else { return }

        requestObj.httpBody = request.requestBody.data(using: .utf8)

        if requestObj.value(forHTTPHeaderField: "Content-Type") == nil {
            requestObj.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
    }

    // MARK: - GraphQL Body

    private func applyGraphQLBody(to requestObj: inout URLRequest, request: APIRequest) {

        let variables = parseJSON(request.graphqlVariables)

        let body: [String: Any] = [
            "query": request.graphqlQuery,
            "variables": variables
        ]

        requestObj.httpBody = try? JSONSerialization.data(withJSONObject: body)

        requestObj.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    // MARK: - Auth

    private func applyAuth(to requestObj: inout URLRequest, from request: APIRequest, env: APIEnvironment?) {
        switch request.auth {

        case .bearer:
            let token = interpolate(request.authToken, env: env)
            requestObj.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        case .basic:
            let user = "admin" // Replace later with actual model
            let pass = interpolate(request.authToken, env: env)
            let creds = Data("\(user):\(pass)".utf8).base64EncodedString()
            requestObj.setValue("Basic \(creds)", forHTTPHeaderField: "Authorization")

        case .apiKey:
            let key = interpolate(request.authToken, env: env)
            requestObj.setValue(key, forHTTPHeaderField: "X-API-Key")

        case .none:
            break
        }
    }

    // MARK: - URL Builder

    private func buildURL(from request: APIRequest, environment: APIEnvironment?) -> URL? {

        let interpolated = interpolate(request.urlString, env: environment)
        let trimmed = interpolated.trimmingCharacters(in: .whitespacesAndNewlines)

        guard var components = URLComponents(string: trimmed) else {
            return URL(string: trimmed)
        }

        var queryItems = components.queryItems ?? []

        for param in request.params where param.isEnabled && !param.key.isEmpty {
            let value = interpolate(param.value, env: environment)
            queryItems.append(URLQueryItem(name: param.key, value: value))
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        return components.url
    }

    // MARK: - Interpolation

    func interpolate(_ text: String, env: APIEnvironment?) -> String {
        guard text.contains("{{") else { return text }

        var result = text
        let vars = env?.variables.filter { $0.isEnabled } ?? []

        for v in vars {
            guard !v.key.isEmpty else { continue }

            let placeholder = "{{\(v.key)}}"
            result = result.replacingOccurrences(of: placeholder, with: v.value)
        }

        return result
    }

    // MARK: - JSON Parser (for GraphQL variables)

    private func parseJSON(_ text: String) -> Any {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            return [:]
        }
        return obj
    }
}

// MARK: - Schema Drift Monitor

class SchemaDriftMonitor {
    static func generateSchema(for json: Any) -> String {
        if let dict = json as? [String: Any] {
            let sortedKeys = dict.keys.sorted()
            let schemaParts = sortedKeys.map { "\($0):\(generateSchema(for: dict[$0]!))" }
            return "{" + schemaParts.joined(separator: ",") + "}"
        } else if let array = json as? [Any] {
            if let first = array.first {
                return "[\(generateSchema(for: first))]"
            }
            return "[]"
        } else if let number = json as? NSNumber {
            // Distinguish boolean from other numbers
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return "Bool"
            }
            return "Number"
        } else if json is String {
            return "String"
        } else if json is NSNull {
            return "Null"
        }
        return "Unknown"
    }
}
