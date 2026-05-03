import Foundation
import Network
import Observation

struct WebhookPayload: Identifiable, Codable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    let method: String
    let path: String
    let body: String
}

@Observable
class WebhookService {
    var isListening = false
    var port: UInt16 = 8080
    var payloads: [WebhookPayload] = []
    
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.apiplay.webhook")
    
    func startListening() {
        guard !isListening else { return }
        
        do {
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isListening = true
                    case .failed(let error):
                        print("Webhook listener failed: \(error)")
                        self?.isListening = false
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
            print("Failed to start webhook listener: \(error)")
        }
    }
    
    func stopListening() {
        listener?.cancel()
        listener = nil
        isListening = false
    }
    
    func clearPayloads() {
        payloads.removeAll()
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
            if let data = data, let requestString = String(data: data, encoding: .utf8) {
                self?.parseAndStoreRequest(requestString)
                
                // Send a 200 OK response
                let responseString = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK"
                let responseData = responseString.data(using: .utf8)!
                connection.send(content: responseData, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            } else {
                connection.cancel()
            }
        }
    }
    
    private func parseAndStoreRequest(_ requestString: String) {
        let lines = requestString.components(separatedBy: .newlines)
        guard let firstLine = lines.first else { return }
        
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return }
        
        let method = String(parts[0])
        let path = String(parts[1])
        
        // Find body (everything after double newline)
        let components = requestString.components(separatedBy: "\r\n\r\n")
        let body = components.count > 1 ? components[1] : ""
        
        let payload = WebhookPayload(method: method, path: path, body: body)
        
        DispatchQueue.main.async {
            self.payloads.insert(payload, at: 0)
        }
    }
}
