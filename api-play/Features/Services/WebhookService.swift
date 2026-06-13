import Foundation
import Network
import Observation

struct WebhookPayload: Identifiable, Codable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    let method: String
    let path: String
    let headers: [String: String]
    let body: String
}

@Observable
class WebhookService {
    var isListening = false
    var port: UInt16 = 8080
    var payloads: [WebhookPayload] = []
    var errorMessage: String? = nil
    
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.apiplay.webhook")
    
    func startListening() {
        guard !isListening else { return }
        errorMessage = nil
        
        do {
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isListening = true
                        self?.errorMessage = nil
                    case .failed(let error):
                        print("Webhook listener failed: \(error)")
                        self?.isListening = false
                        if case .posix(let code) = error, code == .EADDRINUSE {
                            self?.errorMessage = "Port \(self?.port ?? 8080) is already in use by another application. Please choose a different port."
                        } else {
                            self?.errorMessage = error.localizedDescription
                        }
                    case .cancelled:
                        self?.isListening = false
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: queue)
        } catch {
            self.errorMessage = error.localizedDescription
            self.isListening = false
            print("Failed to start webhook listener: \(error)")
        }
    }
    
    func stopListening() {
        listener?.cancel()
        listener = nil
        isListening = false
        errorMessage = nil
    }
    
    func clearPayloads() {
        payloads.removeAll()
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        readRequest(connection: connection, accumulatedData: Data())
    }
    
    private func readRequest(connection: NWConnection, accumulatedData: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error receiving data: \(error)")
                connection.cancel()
                return
            }
            
            var currentData = accumulatedData
            if let data = data, !data.isEmpty {
                currentData.append(data)
            }
            
            if let requestStringASCII = String(data: currentData, encoding: .ascii) {
                let headerSeparator = requestStringASCII.contains("\r\n\r\n") ? "\r\n\r\n" : (requestStringASCII.contains("\n\n") ? "\n\n" : nil)
                
                if let separator = headerSeparator {
                    let components = requestStringASCII.components(separatedBy: separator)
                    let headerSection = components[0]
                    
                    let lines = headerSection.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
                    var contentLength = 0
                    for line in lines {
                        let parts = line.split(separator: ":", maxSplits: 1)
                        if parts.count == 2 {
                            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            if key == "content-length" {
                                contentLength = Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                            }
                        }
                    }
                    
                    let headerDataSize = headerSection.data(using: .ascii)?.count ?? 0
                    let separatorDataSize = separator.data(using: .ascii)?.count ?? 0
                    let currentBodySize = currentData.count - (headerDataSize + separatorDataSize)
                    
                    if currentBodySize >= contentLength || isComplete {
                        let fullRequestString = String(data: currentData, encoding: .utf8) ?? requestStringASCII
                        self.parseAndStoreRequest(fullRequestString)
                        
                        let responseString = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK"
                        let responseData = responseString.data(using: .utf8)!
                        connection.send(content: responseData, completion: .contentProcessed { _ in
                            connection.cancel()
                        })
                    } else {
                        self.readRequest(connection: connection, accumulatedData: currentData)
                    }
                } else {
                    if isComplete {
                        connection.cancel()
                    } else {
                        self.readRequest(connection: connection, accumulatedData: currentData)
                    }
                }
            } else {
                connection.cancel()
            }
        }
    }
    
    private func parseAndStoreRequest(_ requestString: String) {
        let separator = requestString.contains("\r\n\r\n") ? "\r\n\r\n" : "\n\n"
        let components = requestString.components(separatedBy: separator)
        guard !components.isEmpty else { return }
        
        let headerSection = components[0]
        let body = components.dropFirst().joined(separator: separator)
        
        let lines = headerSection.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        guard let firstLine = lines.first else { return }
        
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return }
        
        let method = String(parts[0])
        let path = String(parts[1])
        
        var parsedHeaders: [String: String] = [:]
        for line in lines.dropFirst() {
            let kv = line.split(separator: ":", maxSplits: 1)
            if kv.count == 2 {
                let key = kv[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = kv[1].trimmingCharacters(in: .whitespacesAndNewlines)
                parsedHeaders[key] = value
            }
        }
        
        let payload = WebhookPayload(
            method: method,
            path: path,
            headers: parsedHeaders,
            body: body
        )
        
        DispatchQueue.main.async {
            self.payloads.insert(payload, at: 0)
        }
    }
}
