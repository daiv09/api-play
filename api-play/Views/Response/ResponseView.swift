import SwiftUI
import QuickLook
import UniformTypeIdentifiers
import WebKit
import Vision

struct ResponseView: View {
    let response: APIResponse?
    let requestId: UUID
    @State private var viewMode: ViewMode = .json
    
    @Environment(AICoordinator.self) private var ai
    @State private var isShowingAI = false
    @State private var isAnalyzingVision = false

    enum ViewMode: String, CaseIterable {
        case json = "JSON", raw = "Raw", headers = "Headers", preview = "Preview"
    }

    var body: some View {
        VStack(spacing: 0) {
            if let response = response {
                enhancedToolbar(for: response)
                
                Divider()

                ZStack {
                    Color(nsColor: .textBackgroundColor)
                    
                    switch viewMode {
                    case .json:
                        jsonContentView(content: response.body)
                    case .raw:
                        rawContentView(content: response.body)
                    case .headers:
                        headersContentView(headers: response.headers)
                    case .preview:
                        enhancedPreviewContent(for: response)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .inspector(isPresented: $isShowingAI) {
                    AIInspectorView(ai: ai, bodyText: response.body)
                        .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
                }
                
                Divider()
                footerStatusBar(for: response)
                
            } else {
                emptyStateView
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Component: Enhanced Preview
    @ViewBuilder
    private func enhancedPreviewContent(for response: APIResponse) -> some View {
        VStack(spacing: 0) {
            // The Web Content
            WebView(
                htmlString: response.body,
                baseURL: URL(string: response.url),
                data: response.bodyData,
                mimeType: response.headers.first(where: { $0.key.lowercased() == "content-type" })?.value
            )
                .id(requestId)
            
            HStack {
                Label("Internal HTML Preview", systemImage: "safari")
                    .font(.caption2)
                
                Spacer()
                
                // VISION TRIGGER BUTTON
                Button {
                    analyzeViewVisually()
                } label: {
                    HStack {
                        if isAnalyzingVision {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "eye.circle.fill")
                        }
                        Text("Visual Explain")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.blue)
                .disabled(isAnalyzingVision)
                
                if let url = URL(string: response.url) {
                    Button("Open Link") {
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(10)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Computer Vision Logic
    
    private func analyzeViewVisually() {
        isAnalyzingVision = true
        
        // 1. Capture the current window/view as an image
        // In a real implementation, you'd target the WebView's layer
        let screenshot = capturePreviewSnapshot()
        
        // 2. Use Vision Framework to perform OCR or Saliency Analysis
        performVisionAnalysis(on: screenshot)
        
        // 3. Toggle the AI panel to show results
        isShowingAI = true
        isAnalyzingVision = false
    }
    
    private func capturePreviewSnapshot() -> NSImage {
        // This captures the current view as a bitmap for the Vision framework
        let view = NSApplication.shared.windows.first?.contentView
        let imageRep = view?.bitmapImageRepForCachingDisplay(in: view?.bounds ?? .zero)
        if let rep = imageRep {
            view?.cacheDisplay(in: view?.bounds ?? .zero, to: rep)
            let image = NSImage(size: view?.bounds.size ?? .zero)
            image.addRepresentation(rep)
            return image
        }
        return NSImage()
    }
    
    private func performVisionAnalysis(on image: NSImage) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // Example: Detect Rectangles/Buttons or Text in the UI
        let textRequest = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            let detectedText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            
            // Send the detected visual data to your AI Coordinator
            Task { @MainActor in
                ai.analyzeVisualContext(text: detectedText)
            }
        }
        
        try? requestHandler.perform([textRequest])
    }

    // MARK: - Supporting Views (Toolbar, Status, etc. - Kept Same)
    
    private func enhancedToolbar(for response: APIResponse) -> some View {
        HStack(spacing: 16) {
            statusLabel(code: response.statusCode)
            HStack(spacing: 8) {
                Label("\(Int(response.elapsedSeconds * 1000))ms", systemImage: "clock")
                Text("•")
                Text(formatSize(response.body.count))
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).frame(width: 240).controlSize(.small)
            Button { copyToClipboard(text: response.body) } label: { Image(systemName: "doc.on.doc") }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    @ViewBuilder
    private func statusLabel(code: Int) -> some View {
        let (color, label) = (code < 400 ? Color.green : Color.red, code < 400 ? "OK" : "Error")
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(code) \(label)").font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundStyle(color).padding(.horizontal, 10).padding(.vertical, 4)
        .background(color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func jsonContentView(content: String) -> some View {
        ScrollView {
            Text(prettify(content)).font(.system(size: 12, design: .monospaced))
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
        }
    }

    private func rawContentView(content: String) -> some View {
        TextEditor(text: .constant(content)).font(.system(size: 12, design: .monospaced))
            .scrollContentBackground(.hidden).padding(8)
    }

    private func headersContentView(headers: [String: String]) -> some View {
        List {
            ForEach(headers.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                HStack(alignment: .top) {
                    Text(key).font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary).frame(width: 140, alignment: .leading)
                    Text(value).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                }
                Divider()
            }
        }.listStyle(.inset)
    }

    private func footerStatusBar(for response: APIResponse) -> some View {
        HStack {
            Image(systemName: "info.circle")
            Text(response.headers["Content-Type"] ?? "text/html")
            Spacer()
            Text("ID: \(requestId.uuidString.prefix(8))")
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(.secondary).padding(.horizontal, 12).padding(.vertical, 6)
    }

    private var emptyStateView: some View {
        ContentUnavailableView { Label("No Response", systemImage: "bolt.fill") }
    }

    private func formatSize(_ bytes: Int) -> String { ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file) }
    private func prettify(_ input: String) -> String { input } // Simplified for code length
    private func copyToClipboard(text: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
}
