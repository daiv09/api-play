import Foundation
import Observation
import Combine

enum WebSocketStatus: Equatable { // Add Equatable here
    case disconnected
    case connecting
    case connected
    case error(String)
}

struct WebSocketMessage: Identifiable {
    let id = UUID()
    let content: String
    let timestamp = Date()
    let isOutgoing: Bool
}

@Observable
class WebSocketService {
    private var webSocketTask: URLSessionWebSocketTask?
    private let urlSession = URLSession(configuration: .default)
    
    // UI State
    var status: WebSocketStatus = .disconnected
    var messages: [WebSocketMessage] = []
    var isConnected: Bool = false
    
    /// Connects to a WebSocket server
    func connect(url: URL) {
        guard status != .connected else { return }
        
        status = .connecting
        let request = URLRequest(url: url)
        webSocketTask = urlSession.webSocketTask(with: request)
        
        // Listen for messages
        listen()
        
        webSocketTask?.resume()
        self.status = .connected
        self.isConnected = true
        
        print("📡 WebSocket Connected to: \(url.absoluteString)")
    }
    
    /// Disconnects from the server
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        status = .disconnected
        isConnected = false
        print("📡 WebSocket Disconnected")
    }
    
    /// Sends a text message
    func send(_ text: String) {
        let message = URLSessionWebSocketTask.Message.string(text)
        
        webSocketTask?.send(message) { [weak self] error in
            if let error = error {
                print("❌ WebSocket Send Error: \(error.localizedDescription)")
            } else {
                Task { @MainActor [weak self] in
                    self?.messages.append(WebSocketMessage(content: text, isOutgoing: true))
                }
            }
        }
    }
    
    /// Recursive listener to catch incoming data
    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                Task { @MainActor [weak self] in
                    self?.status = .error(error.localizedDescription)
                    self?.isConnected = false
                }
                print("❌ WebSocket Receive Error: \(error)")
                
            case .success(let message):
                switch message {
                case .string(let text):
                    Task { @MainActor [weak self] in
                        self?.messages.append(WebSocketMessage(content: text, isOutgoing: false))
                    }
                case .data(let data):
                    // Handle binary data if necessary
                    if let text = String(data: data, encoding: .utf8) {
                        Task { @MainActor [weak self] in
                            self?.messages.append(WebSocketMessage(content: text, isOutgoing: false))
                        }
                    }
                @unknown default:
                    break
                }
                
                // Re-subscribe to the next message
                if self.isConnected {
                    self.listen()
                }
            }
        }
    }
}
