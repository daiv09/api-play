import SwiftUI
import AppKit

struct QuickRequestView: View {
    @State private var urlString: String = ""
    @State private var isExecuting: Bool = false
    @State private var response: APIResponse?
    @State private var viewMode: Int = 0 // 0: JSON, 1: Raw
    @State private var copied: Bool = false
    @StateObject private var networkManager = NetworkManager()
    
    private var dummyRequest: APIRequest {
        // Automatically prepend http:// if missing and not localhost
        var finalURL = urlString
        if !finalURL.lowercased().hasPrefix("http") {
            finalURL = "https://" + finalURL
        }
        let req = APIRequest(name: "Quick Request")
        req.urlString = finalURL
        req.httpMethod = .GET
        return req
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.blue)
                Text("api-play Quick Request")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            
            // Input Area
            HStack {
                TextField("Paste Local or Web URL...", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        executeRequest()
                    }
                
                Button(action: {
                    executeRequest()
                }) {
                    HStack {
                        Text("Send")
                        Image(systemName: "paperplane.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlString.isEmpty || isExecuting)
            }
            
            if isExecuting {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.top, 10)
            }
            
            // Error Banner
            if let error = networkManager.error, response == nil, !isExecuting {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error.localizedDescription)
                        .font(.caption)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .cornerRadius(6)
            }
            
            // Response Area
            if let response = response, !isExecuting {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Response")
                            .font(.subheadline)
                            .bold()
                        Spacer()
                        Picker("", selection: $viewMode) {
                            Text("JSON").tag(0)
                            Text("Raw").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                    
                    ScrollView {
                        Text(viewMode == 0 ? formatJSON(response.body) : response.body)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(height: 250)
                    // Match the glassmorphic dark look from the mockup
                    .background(Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05))
                    .cornerRadius(8)
                    
                    HStack {
                        Text("Status: \(response.statusCode)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(response.statusCode < 400 ? .green : .red)
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("\(String(format: "%.0f", response.elapsedSeconds * 1000))ms")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(response.body, forType: .string)
                            withAnimation { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { copied = false }
                            }
                        }) {
                            HStack {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                Text(copied ? "Copied" : "Copy Response")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
            }
        }
        .padding(16)
        .frame(width: 450)
        // Let it size dynamically vertically
        .fixedSize(horizontal: false, vertical: true)
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    private func executeRequest() {
        guard !urlString.isEmpty else { return }
        
        withAnimation {
            isExecuting = true
            self.response = nil
            networkManager.error = nil
        }
        
        Task {
            if let result = await networkManager.execute(dummyRequest, env: nil) {
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.response = result
                        self.isExecuting = false
                    }
                }
            } else {
                await MainActor.run {
                    self.isExecuting = false
                }
            }
        }
    }
    
    private func formatJSON(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .withoutEscapingSlashes]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return raw
        }
        return prettyString
    }
}
