import SwiftUI

struct WebhookView: View {
    @Environment(WebhookService.self) private var webhookService
    @State private var selectedPayloadId: UUID? = nil
    @AppStorage("showWebhookHelpBanner") private var showHelpBanner = true
    
    var body: some View {
        @Bindable var service = webhookService
        
        GeometryReader { geo in
            let isWide = geo.size.width >= 550
            
            if isWide {
                // Wide Layout: Split Master-Detail Panel
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        WebhookControlPanel(service: service, showHelpBanner: $showHelpBanner)
                        
                        if showHelpBanner {
                            WebhookIntroductionBanner(port: service.port, showHelpBanner: $showHelpBanner)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        Divider()
                        
                        WebhookMasterList(service: service, selectedPayloadId: $selectedPayloadId, useNavigation: false)
                    }
                    .frame(width: 250)
                    
                    Divider()
                    
                    if let selectedId = selectedPayloadId,
                       let payload = service.payloads.first(where: { $0.id == selectedId }) {
                        WebhookPayloadDetailView(payload: payload, port: service.port)
                            .id(selectedId)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        WebhookPlaceholderView()
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            } else {
                // Narrow Layout: Navigation-based Push View
                NavigationStack {
                    VStack(spacing: 0) {
                        WebhookControlPanel(service: service, showHelpBanner: $showHelpBanner)
                        
                        if showHelpBanner {
                            WebhookIntroductionBanner(port: service.port, showHelpBanner: $showHelpBanner)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        Divider()
                        
                        WebhookMasterList(service: service, selectedPayloadId: $selectedPayloadId, useNavigation: true)
                    }
                    .navigationTitle("Receiver")
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .frame(minWidth: 220, maxWidth: .infinity, minHeight: 350, maxHeight: .infinity)
        .onChange(of: service.payloads.count) { _, newCount in
            // Auto-select first item if selection is nil in split view
            if selectedPayloadId == nil, let first = service.payloads.first {
                selectedPayloadId = first.id
            }
        }
        .onChange(of: service.payloads.isEmpty) { _, isEmpty in
            if isEmpty {
                selectedPayloadId = nil
            }
        }
    }
}

// MARK: - Webhook Introduction Banner
struct WebhookIntroductionBanner: View {
    let port: UInt16
    @Binding var showHelpBanner: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("What is this feature?")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showHelpBanner = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text("Allows you to intercept, inspect, and replay HTTP webhook payloads (e.g. Stripe or GitHub callbacks) locally at http://127.0.0.1:\(port) without setting up tunnels like ngrok.")
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blue.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.blue.opacity(0.16), lineWidth: 1)
        )
        .padding([.horizontal, .top], 8)
    }
}

// MARK: - Webhook Control Panel
struct WebhookControlPanel: View {
    @Bindable var service: WebhookService
    @Binding var showHelpBanner: Bool
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var copyBannerText: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title and Start/Stop Button
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Webhook Receiver")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    
                    HStack(spacing: 5) {
                        // Pulsing status indicator
                        ZStack {
                            if service.isListening {
                                Circle()
                                    .fill(Color.green.opacity(0.35))
                                    .frame(width: 12, height: 12)
                                    .scaleEffect(pulseScale)
                                    .onAppear {
                                        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                                            pulseScale = 1.6
                                        }
                                    }
                                    .onDisappear {
                                        pulseScale = 1.0
                                    }
                            }
                            Circle()
                                .fill(service.isListening ? Color.green : Color.red)
                                .frame(width: 7, height: 7)
                        }
                        
                        Text(service.isListening ? "Listening" : "Offline")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(service.isListening ? Color.green : Color.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    if !showHelpBanner {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showHelpBanner = true
                            }
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Show helper description")
                    }
                    
                    Button(service.isListening ? "Stop" : "Start") {
                        if service.isListening {
                            service.stopListening()
                        } else {
                            service.startListening()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(service.isListening ? .red : .blue) // Restored .blue for the offline state
                    .controlSize(.small)
                }
            }
            
            // Port, Endpoint URL & Clear Action
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 3) {
                        Text("Port:")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        
                        TextField("", value: $service.port, format: .number.grouping(.never))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 10))
                            .disabled(service.isListening)
                    }
                    
                    Spacer()
                    
                    Button("Clear") {
                        service.clearPayloads()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(service.payloads.isEmpty ? Color.secondary : Color.blue)
                    .disabled(service.payloads.isEmpty)
                }
                
                // Copyable active endpoint URL
                HStack(spacing: 4) {
                    Text("Local URL:")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    
                    Text("http://127.0.0.1:\(service.port)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(service.isListening ? Color.blue : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Button {
                        copyToClipboard("http://127.0.0.1:\(service.port)")
                        withAnimation {
                            copyBannerText = "Copied!"
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Copy webhook receiver URL")
                    
                    if let banner = copyBannerText {
                        Text(banner)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.green)
                            .transition(.opacity)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    withAnimation {
                                        copyBannerText = nil
                                    }
                                }
                            }
                    }
                }
            }
            
            if let error = service.errorMessage {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.red)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.red.opacity(0.18), lineWidth: 0.5))
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Webhook Master List
struct WebhookMasterList: View {
    let service: WebhookService
    @Binding var selectedPayloadId: UUID?
    let useNavigation: Bool
    
    var body: some View {
        if service.payloads.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "network")
                    .font(.system(size: 24))
                    .foregroundStyle(.tertiary)
                Text("No Webhooks")
                    .font(.system(size: 12, weight: .bold))
                Text("Send HTTP requests to:\nhttp://127.0.0.1:\(service.port)")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(service.payloads) { payload in
                    if useNavigation {
                        NavigationLink {
                            WebhookPayloadDetailView(payload: payload, port: service.port)
                        } label: {
                            WebhookPayloadRow(payload: payload, isSelected: false)
                        }
                    } else {
                        Button {
                            selectedPayloadId = payload.id
                        } label: {
                            WebhookPayloadRow(payload: payload, isSelected: selectedPayloadId == payload.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}

// MARK: - Webhook Payload Row (Cell View)
struct WebhookPayloadRow: View {
    let payload: WebhookPayload
    let isSelected: Bool
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                // Method Badge
                Text(payload.method)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(methodColor(payload.method))
                    )
                
                // Path
                Text(payload.path)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Date/Time
                Text(payload.timestamp, style: .time)
                    .font(.system(size: 8.5))
                    .foregroundStyle(.secondary)
            }
            
            // Body Summary
            if !payload.body.isEmpty {
                Text(payload.body.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.blue.opacity(0.12) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.blue.opacity(0.28) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private func methodColor(_ method: String) -> Color {
        switch method {
        case "GET": return .green
        case "POST": return .orange
        case "PUT", "PATCH": return .blue
        case "DELETE": return .red
        default: return .secondary
        }
    }
}

// MARK: - Webhook Payload Detail View
struct WebhookPayloadDetailView: View {
    let payload: WebhookPayload
    let port: UInt16
    
    @State private var detailTab: DetailTab = .body
    @State private var isPrettyJson = true
    @State private var copyBannerText: String? = nil
    
    enum DetailTab: String, CaseIterable {
        case body = "Body"
        case headers = "Headers"
        case replay = "Curl Replay"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Info Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(payload.method)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(methodColor(payload.method))
                        )
                    
                    Text(payload.path)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .textSelection(.enabled)
                }
                
                Text("Received: \(payload.timestamp.formatted(date: .abbreviated, time: .standard))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
            
            Divider()
            
            // Tab Picker
            Picker("", selection: $detailTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(10)
            
            Divider()
            
            // Content Pane
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch detailTab {
                    case .body:
                        bodyView
                    case .headers:
                        headersView
                    case .replay:
                        replayView
                    }
                }
                .padding(12)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            
            // Temporary overlay visual feedback for clipboard copies
            if let banner = copyBannerText {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(banner)
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))
                .cornerRadius(18)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.gray.opacity(0.25), lineWidth: 1))
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            copyBannerText = nil
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Tab: Body
    private var bodyView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Payload Content")
                    .font(.system(size: 12, weight: .bold))
                
                Spacer()
                
                if isJSON(payload.body) {
                    Toggle("Prettify", isOn: $isPrettyJson)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 11))
                }
                
                Button {
                    let text = isPrettyJson && isJSON(payload.body) ? prettyPrintJSON(payload.body) : payload.body
                    copyToClipboard(text)
                    withAnimation {
                        copyBannerText = "Payload copied!"
                    }
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .disabled(payload.body.isEmpty)
            }
            
            if payload.body.isEmpty {
                Text("No Body Content")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .italic()
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.2))
                    .cornerRadius(6)
            } else {
                let prettyText = isPrettyJson && isJSON(payload.body) ? prettyPrintJSON(payload.body) : payload.body
                
                if isPrettyJson && isJSON(payload.body) {
                    Text(highlightJSON(prettyText))
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.15), lineWidth: 0.5))
                } else {
                    Text(prettyText)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.15), lineWidth: 0.5))
                }
            }
        }
    }
    
    // MARK: - Tab: Headers
    private var headersView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("HTTP Headers (\(payload.headers.count))")
                    .font(.system(size: 12, weight: .bold))
                
                Spacer()
                
                Button {
                    copyToClipboard(formatHeaders(payload.headers))
                    withAnimation {
                        copyBannerText = "Headers copied!"
                    }
                } label: {
                    Label("Copy All", systemImage: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .disabled(payload.headers.isEmpty)
            }
            
            if payload.headers.isEmpty {
                Text("No Headers")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .italic()
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.2))
                    .cornerRadius(6)
            } else {
                VStack(spacing: 0) {
                    let sortedKeys = payload.headers.keys.sorted()
                    ForEach(sortedKeys, id: \.self) { key in
                        if let value = payload.headers[key] {
                            HStack(alignment: .top) {
                                Text(key)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 130, alignment: .leading)
                                    .lineLimit(1)
                                
                                Text(value)
                                    .font(.system(size: 10, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            
                            if key != sortedKeys.last {
                                Divider()
                            }
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.25))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.18), lineWidth: 0.5))
            }
        }
    }
    
    // MARK: - Tab: Curl Replay
    private var replayView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Replay Webhook Trigger")
                    .font(.system(size: 12, weight: .bold))
                
                Spacer()
                
                Button {
                    let curl = generateCurl(payload: payload, port: port)
                    copyToClipboard(curl)
                    withAnimation {
                        copyBannerText = "Curl script copied!"
                    }
                } label: {
                    Label("Copy Curl", systemImage: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
            }
            
            Text("Run this curl script in your terminal to replay the exact webhook request to your local server:")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            
            Text(generateCurl(payload: payload, port: port))
                .font(.system(size: 10.5, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.18), lineWidth: 0.5))
        }
    }
    
    // MARK: - Helpers
    private func methodColor(_ method: String) -> Color {
        switch method {
        case "GET": return .green
        case "POST": return .orange
        case "PUT", "PATCH": return .blue
        case "DELETE": return .red
        default: return .secondary
        }
    }
    
    private func formatHeaders(_ headers: [String: String]) -> String {
        headers.map { "\($0.key): \($0.value)" }.sorted().joined(separator: "\n")
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    private func isJSON(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data, options: [])) != nil
    }
    
    private func prettyPrintJSON(_ jsonString: String) -> String {
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return jsonString
        }
        return prettyString
    }
    
    private func highlightJSON(_ pretty: String) -> AttributedString {
        var result = AttributedString()
        let scanner = Scanner(string: pretty)
        scanner.charactersToBeSkipped = nil
        
        while !scanner.isAtEnd {
            if let punctuation = scanner.scanCharacters(from: CharacterSet(charactersIn: "{}[],:")) {
                var r = AttributedString(punctuation)
                r.foregroundColor = .secondary
                result.append(r)
            } else if let whitespace = scanner.scanCharacters(from: .whitespacesAndNewlines) {
                result.append(AttributedString(whitespace))
            } else if scanner.scanString("\"") != nil {
                var rawString = "\""
                var escaped = false
                while !scanner.isAtEnd {
                    if let char = scanner.scanCharacter() {
                        rawString.append(char)
                        if char == "\\" {
                            escaped.toggle()
                        } else if char == "\"" && !escaped {
                            break
                        } else {
                            escaped = false
                        }
                    }
                }
                
                var strAttr = AttributedString(rawString)
                let currentPos = scanner.currentIndex
                let remaining = scanner.string[currentPos...]
                let isKey = remaining.first(where: { !$0.isWhitespace }) == ":"
                
                if isKey {
                    strAttr.foregroundColor = Color.purple
                    strAttr.inlinePresentationIntent = .stronglyEmphasized
                } else {
                    strAttr.foregroundColor = Color.green
                }
                result.append(strAttr)
            } else if let numberOrBool = scanner.scanCharacters(from: CharacterSet(charactersIn: "-0123456789.eEtruefalsenul")) {
                var numAttr = AttributedString(numberOrBool)
                if numberOrBool == "true" || numberOrBool == "false" {
                    numAttr.foregroundColor = Color.blue
                    numAttr.inlinePresentationIntent = .stronglyEmphasized
                } else if numberOrBool == "null" {
                    numAttr.foregroundColor = Color.red
                    numAttr.inlinePresentationIntent = .emphasized
                } else {
                    numAttr.foregroundColor = Color.orange
                }
                result.append(numAttr)
            } else {
                if let char = scanner.scanCharacter() {
                    result.append(AttributedString(String(char)))
                }
            }
        }
        
        return result
    }
    
    private func generateCurl(payload: WebhookPayload, port: UInt16) -> String {
        var parts = ["curl -X \(payload.method)"]
        for (key, value) in payload.headers.sorted(by: { $0.key < $1.key }) {
            let escapedValue = value.replacingOccurrences(of: "\"", with: "\\\"")
            parts.append("-H \"\(key): \(escapedValue)\"")
        }
        if !payload.body.isEmpty {
            let escapedBody = payload.body.replacingOccurrences(of: "'", with: "'\\''")
            parts.append("-d '\(escapedBody)'")
        }
        parts.append("\"http://127.0.0.1:\(port)\(payload.path)\"")
        return parts.joined(separator: " \\\n  ")
    }
}

// MARK: - Placeholder Detail View
struct WebhookPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 44))
                .foregroundStyle(.blue.opacity(0.6))
                .symbolEffect(.bounce, options: .repeating)
            
            VStack(spacing: 5) {
                Text("No Payload Selected")
                    .font(.system(.headline, design: .rounded))
                Text("Select an incoming webhook request from the list to view its header details and formatted request body.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 240)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
