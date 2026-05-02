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

    func execute(_ request: APIRequest, env: APIEnvironment?) async -> APIResponse? {
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
                let (data, urlResponse) = try await URLSession.shared.data(for: urlRequest)
                let elapsed = Date().timeIntervalSince(start)

                guard let http = urlResponse as? HTTPURLResponse else {
                    self.error = .noResponse
                    isLoading = false
                    return nil
                }

                // Extract Headers
                let headers = Dictionary(uniqueKeysWithValues:
                    http.allHeaderFields.compactMap { k, v -> (String, String)? in
                        guard let key = k as? String,
                              let value = v as? String else { return nil }
                        return (key, value)
                    }
                )

                // 📎 THE FIX: Handle Body String Safely
                // If it's an image, video, audio or PDF, we don't want to display "broken" text in the JSON/Raw view.
                let contentType = headers["Content-Type"]?.lowercased() ?? ""
                let isBinary = contentType.contains("image/") || contentType.contains("pdf") || contentType.contains("video/") || contentType.contains("audio/")
                
                let bodyString: String
                if isBinary {
                    bodyString = "[Binary Data: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))]"
                } else {
                    bodyString = String(data: data, encoding: .utf8) ?? "<Unable to decode string>"
                }

                // Create the APIResponse with BOTH raw data and the string representation
                let apiResponse = APIResponse(
                    statusCode: http.statusCode,
                    bodyData: data, // 👈 CRITICAL: Save raw bytes for Quick Look
                    headers: headers,
                    body: bodyString,
                    elapsedSeconds: elapsed,
                    byteCount: data.count,
                    url: url.absoluteString
                )

                self.response = apiResponse
                isLoading = false

                return apiResponse

            } catch {
                self.error = .underlying(error)
                isLoading = false
                return nil
            }
        }
    // MARK: - REST Body

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
