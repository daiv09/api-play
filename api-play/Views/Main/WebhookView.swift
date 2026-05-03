import SwiftUI

struct WebhookView: View {
    @Environment(WebhookService.self) private var webhookService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Local Webhook Receiver")
                        .font(.headline)
                    Text(webhookService.isListening ? "Listening on port \(webhookService.port)" : "Offline")
                        .font(.subheadline)
                        .foregroundStyle(webhookService.isListening ? .green : .secondary)
                }
                
                Spacer()
                
                Button(action: {
                    if webhookService.isListening {
                        webhookService.stopListening()
                    } else {
                        webhookService.startListening()
                    }
                }) {
                    Text(webhookService.isListening ? "Stop" : "Start")
                }
                .buttonStyle(.borderedProminent)
                .tint(webhookService.isListening ? .red : .blue)
                
                Button("Clear") {
                    webhookService.clearPayloads()
                }
                .disabled(webhookService.payloads.isEmpty)
                
                Button("Close") { dismiss() }
            }
            .padding()
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Payload List
            if webhookService.payloads.isEmpty {
                ContentUnavailableView("No Webhooks Received", systemImage: "network", description: Text("Start the listener and send a request to localhost:\(webhookService.port)"))
            } else {
                List {
                    ForEach(webhookService.payloads) { payload in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(payload.method)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(methodColor(payload.method).opacity(0.2))
                                    .foregroundStyle(methodColor(payload.method))
                                    .cornerRadius(4)
                                Text(payload.path)
                                    .font(.body.monospaced())
                                Spacer()
                                Text(payload.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if !payload.body.isEmpty {
                                Text(payload.body)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(nsColor: .textBackgroundColor))
                                    .cornerRadius(6)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 400, minHeight: 400)
    }
    
    private func methodColor(_ method: String) -> Color {
        switch method {
        case "GET": return .green
        case "POST": return .orange
        case "PUT": return .blue
        case "DELETE": return .red
        default: return .secondary
        }
    }
}
