import SwiftUI
import QuickLook
import UniformTypeIdentifiers
import WebKit
import Vision

struct ResponseView: View {
    @Bindable var request: APIRequest
    
    @State private var viewMode: ViewMode = .json
    @State private var isShowingHistory = false
    @Environment(AICoordinator.self) private var ai
    @State private var isShowingAI = false
    @State private var isAnalyzingVision = false
    @State private var visualExplainCache: [CGFloat: String] = [:]
    @State private var lastScrollY: CGFloat = 0
    @State private var slideDirection: Edge = .trailing

    enum ViewMode: String, CaseIterable {
        case json = "JSON", raw = "Raw", headers = "Headers", preview = "Preview"
    }

    var body: some View {
        VStack(spacing: 0) {
            if let response = request.lastResponse {
                enhancedToolbar(for: response)
                Divider()
                
                ZStack {
                    if isShowingHistory {
                        CommitHistoryView(request: request) {
                            isShowingHistory = false
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    } else {
                        ZStack {
                            Color(nsColor: .textBackgroundColor)
                            
                            switch viewMode {
                            case .json:
                                jsonContentView(content: response.body)
                                    .id(viewMode)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: slideDirection).combined(with: .opacity),
                                        removal: .move(edge: slideDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
                                    ))
                            case .raw:
                                rawContentView(content: response.body)
                                    .id(viewMode)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: slideDirection).combined(with: .opacity),
                                        removal: .move(edge: slideDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
                                    ))
                            case .headers:
                                headersContentView(headers: response.headers)
                                    .id(viewMode)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: slideDirection).combined(with: .opacity),
                                        removal: .move(edge: slideDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
                                    ))
                            case .preview:
                                enhancedPreviewContent(for: response)
                                    .id(viewMode)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: slideDirection).combined(with: .opacity),
                                        removal: .move(edge: slideDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
                                    ))
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.snappy(duration: 0.22, extraBounce: 0), value: viewMode)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isShowingHistory)
                .inspector(isPresented: $isShowingAI) {
                    AIInspectorView(ai: ai, bodyText: response.body)
                        .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
                }
                
                Divider()
                footerStatusBar(for: response)
            } else if isShowingHistory {
                // If no last response, but we want history, still show the history view
                VStack(spacing: 0) {
                    historyToolbar
                    Divider()
                    CommitHistoryView(request: request) {
                        isShowingHistory = false
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                emptyStateView
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: viewMode) { oldValue, newValue in
            isShowingHistory = false
            let oldIndex = ViewMode.allCases.firstIndex(of: oldValue) ?? 0
            let newIndex = ViewMode.allCases.firstIndex(of: newValue) ?? 0
            slideDirection = newIndex > oldIndex ? .trailing : .leading
        }
        .onChange(of: request.lastResponse) { _, newResponse in
            visualExplainCache.removeAll()
            if let response = newResponse {
                let modes = availableModes(for: response)
                if !modes.contains(viewMode), let firstMode = modes.first {
                    viewMode = firstMode
                }
            }
        }
        .onChange(of: request.id) { _, _ in
            visualExplainCache.removeAll()
            isShowingAI = false
        }
        .onAppear {
            if let response = request.lastResponse {
                let modes = availableModes(for: response)
                if !modes.contains(viewMode), let firstMode = modes.first {
                    viewMode = firstMode
                }
            }
        }
    }
    
    private var historyToolbar: some View {
        HStack {
            Label("Commit History", systemImage: "clock.arrow.circlepath")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                isShowingHistory = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    @ViewBuilder
    private func enhancedPreviewContent(for response: APIResponse) -> some View {
        VStack(spacing: 0) {
            // 1. The main content
            WebView(
                htmlString: response.body,
                baseURL: URL(string: response.url),
                data: response.bodyData,
                mimeType: response.headers.first(where: { $0.key.lowercased() == "content-type" })?.value,
                requestId: request.id
            )
            .id(request.id)
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Force it to take all space

            Divider() // Add a clear separation

            // 2. The Bottom Toolbar
            HStack {
                Label("Internal Preview", systemImage: "safari")
                    .font(.caption2)
                
                Spacer()
                
                Button {
                    toggleVisualExplain()
                } label: {
                    HStack {
                        if isAnalyzingVision {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: isShowingAI ? "eye.slash.circle.fill" : "eye.circle.fill")
                        }
                        Text(isShowingAI ? "Hide Explain" : "Visual Explain")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(isShowingAI ? .orange : .blue)
                .disabled(isAnalyzingVision)
                
                if let url = URL(string: response.url) {
                    Button("Open Link") {
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial) // This provides the "bar" look at the bottom
        }
    }

    // MARK: - Computer Vision Toggle Logic
    
    private func toggleVisualExplain() {
        if isShowingAI {
            isShowingAI = false
            return
        }

        isAnalyzingVision = true

        Task { @MainActor in
            let currentScrollY = await getWebViewScrollY()
            // Check cache
            if let cachedEntry = visualExplainCache.first(where: { abs($0.key - currentScrollY) < 5 }) {
                let currentURL = request.lastResponse?.url ?? "Unknown URL"
                Task { @MainActor in
                    ai.analyzeVisualContext(
                        text: cachedEntry.value,
                        sourceURL: currentURL,
                        image: NSImage()
                    )
                    isAnalyzingVision = false
                    isShowingAI = true
                }
                return
            }

            // 1. Capture context asynchronously
            capturePreviewSnapshot { screenshot in
                let currentURL = request.lastResponse?.url ?? "Unknown URL"
                
                // 2. Run Vision OCR
                performVisionAnalysis(on: screenshot) { detectedText in
                    Task { @MainActor in
                        // 3. Update AI State
                        ai.analyzeVisualContext(
                            text: detectedText,
                            sourceURL: currentURL,
                            image: screenshot
                        )
                        
                        isAnalyzingVision = false
                        isShowingAI = true
                        visualExplainCache[currentScrollY] = detectedText
                    }
                }
            }
        }
    }
    
    @MainActor
    private func getWebViewScrollY() async -> CGFloat {
        guard let window = NSApplication.shared.windows.first,
              let contentView = window.contentView,
              let webView = findWebView(in: contentView) else {
            return 0
        }

        do {
            let result = try await webView.evaluateJavaScript("window.pageYOffset")
            return CGFloat((result as? NSNumber)?.floatValue ?? 0)
        } catch {
            return 0
        }
    }

    private func performVisionAnalysis(on image: NSImage, completion: @escaping (String) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion("")
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let textRequest = VNRecognizeTextRequest { request, _ in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion("")
                return
            }
            let detectedText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
            completion(detectedText)
        }
        
        textRequest.recognitionLevel = .accurate
        DispatchQueue.global(qos: .userInitiated).async {
            try? requestHandler.perform([textRequest])
        }
    }
    
    private func capturePreviewSnapshot(completion: @escaping (NSImage) -> Void) {
        if let window = NSApplication.shared.windows.first,
           let contentView = window.contentView,
           let webView = findWebView(in: contentView) {
            
            webView.takeSnapshot(with: nil) { image, error in
                if let image = image {
                    completion(image)
                } else {
                    completion(captureFallbackSnapshot())
                }
            }
        } else {
            completion(captureFallbackSnapshot())
        }
    }
    
    private func captureFallbackSnapshot() -> NSImage {
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
    
    private func findWebView(in view: NSView) -> WKWebView? {
        if let webView = view as? WKWebView {
            return webView
        }
        for subview in view.subviews {
            if let found = findWebView(in: subview) {
                return found
            }
        }
        return nil
    }

    // MARK: - Supporting Views (Kept for compatibility)
    
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
            let modes = availableModes(for: response)
            Picker("", selection: $viewMode) {
                ForEach(modes, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: CGFloat(modes.count * 60))
            .controlSize(.small)
            Button { copyToClipboard(text: response.body) } label: { Image(systemName: "doc.on.doc") }
            .buttonStyle(.plain)
            
            Divider().frame(height: 12)
            
            Button {
                isShowingHistory.toggle()
            } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(isShowingHistory ? .blue : .secondary)
            }
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

    private func formattedJSON(_ content: String) -> String {
        guard let data = content.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              // .prettyPrinted ensures structured indentation for JSON
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return content
        }
        return prettyString
    }

    private func formattedRaw(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If the content is HTML or XML, apply a clean structural indentation parser
        if trimmed.hasPrefix("<") && trimmed.hasSuffix(">") {
            return formatHTML(trimmed)
        }
        return content
    }

    // Helper to manually parse and indent XML/HTML content neatly line-by-line
    private func formatHTML(_ html: String) -> String {
        // Standardize spacing between closing and opening tags
        let cleanHTML = html.replacingOccurrences(of: ">\\s*<", with: "><", options: .regularExpression)
        
        var formatted = ""
        var indentLevel = 0
        let indentString = "    " // 4 spaces per indentation level
        
        var i = cleanHTML.startIndex
        while i < cleanHTML.endIndex {
            if cleanHTML[i] == "<" {
                // Find the full tag component block
                guard let closingBracketIndex = cleanHTML[i...].firstIndex(of: ">") else {
                    formatted.append(String(cleanHTML[i...]))
                    break
                }
                
                let tag = String(cleanHTML[i...closingBracketIndex])
                
                if tag.hasPrefix("</") {
                    // It's a closing tag: step backward first, then add the line
                    indentLevel = max(0, indentLevel - 1)
                    formatted.append("\n" + String(repeating: indentString, count: indentLevel) + tag)
                } else if tag.hasSuffix("/>") || tag.hasPrefix("<!") || tag.hasPrefix("<?") {
                    // Self-closing tags, comments, or doctypes don't change indentation depth
                    formatted.append("\n" + String(repeating: indentString, count: indentLevel) + tag)
                } else {
                    // Opening tag: indent and step forward for subsequent tags
                    formatted.append("\n" + String(repeating: indentString, count: indentLevel) + tag)
                    indentLevel += 1
                }
                
                i = cleanHTML.index(after: closingBracketIndex)
            } else {
                // Read inner text until the next tag starts
                let nextBracketIndex = cleanHTML[i...].firstIndex(of: "<") ?? cleanHTML.endIndex
                let text = cleanHTML[i..<nextBracketIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !text.isEmpty {
                    formatted.append("\n" + String(repeating: indentString, count: indentLevel) + text)
                }
                i = nextBracketIndex
            }
        }
        
        return formatted.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func jsonContentView(content: String) -> some View {
        ScrollView {
            // Pass the string through your formattedJSON helper function
            Text(formattedJSON(content))
                .font(.system(size: 12, design: .monospaced))
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private func rawContentView(content: String) -> some View {
        // Pass the string through your formattedRaw helper function
        TextEditor(text: .constant(formattedRaw(content)))
            .font(.system(size: 12, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(8)
    }

    private func headersContentView(headers: [String: String]) -> some View {
        List {
            ForEach(headers.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                HStack(alignment: .top) {
                    Text(key).font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary).frame(width: 140, alignment: .leading)
                    Text(value).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                }
            }
        }.listStyle(.inset)
    }

    private func footerStatusBar(for response: APIResponse) -> some View {
        HStack {
            Image(systemName: "info.circle")
            Text(response.headers["Content-Type"] ?? "text/html")
            Spacer()
            Text("ID: \(request.id.uuidString.prefix(8))")
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(.secondary).padding(.horizontal, 12).padding(.vertical, 6)
    }

    private var emptyStateView: some View {
        VStack {
            ContentUnavailableView { Label("No Response", systemImage: "bolt.fill") }
            Button("View History") {
                isShowingHistory = true
            }
            .buttonStyle(.link)
        }
    }

    private func availableModes(for response: APIResponse) -> [ViewMode] {
        var modes: [ViewMode] = []
        if response.isJSON {
            modes.append(.json)
        }
        if response.hasBody {
            modes.append(.raw)
        }
        if response.hasHeaders {
            modes.append(.headers)
        }
        if response.hasPreview {
            modes.append(.preview)
        }
        return modes
    }

    private func formatSize(_ bytes: Int) -> String { ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file) }
    private func copyToClipboard(text: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
}
