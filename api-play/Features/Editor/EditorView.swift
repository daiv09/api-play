import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct EditorView: View {
    @Environment(AICoordinator.self) private var aiCoordinator
    @Environment(\.modelContext) private var modelContext
    @Bindable var request: APIRequest
    var environment: APIEnvironment?
    
    @State private var showAgentConsole = false
    @State private var showCodeGenSheet = false

    @StateObject private var network = NetworkManager()
    var onResponseReceived: ((APIResponse) -> Void)?
    @State private var selectedTab: EditorTab = .params
    @State private var slideDirection: Edge = .trailing

    enum EditorTab: String, CaseIterable {
        case params = "Params"
        case headers = "Headers"
        case auth = "Auth"
        case body = "Body"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 🔹 1. METHOD & URL BAR (Always Visible)
            HStack(spacing: 12) {
                Picker("", selection: $request.requestType) {
                    Text("REST").tag(RequestType.rest)
                    Text("GraphQL").tag(RequestType.graphql)
                }
                .pickerStyle(.segmented)
                .frame(width: 130)
                
                urlBar
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(.ultraThinMaterial)
            
            Divider()

            // 🔹 2. CONDITIONAL LAYOUT ROUTING
            if request.requestType == .graphql {
                // GraphQL Selected: Jump directly into the GraphQL Editor workspace without rendering the REST header bars
                GraphQLEditorView(
                    query: $request.graphqlQuery,
                    variables: $request.graphqlVariables
                )
                .transition(.opacity)
            } else {
                // REST Selected: Render the tab sub-navigation row along with its matching workspaces
                VStack(spacing: 0) {
                    HStack(spacing: 20) {
                        ForEach(EditorTab.allCases, id: \.self) { tab in
                            Button {
                                selectedTab = tab
                            } label: {
                                VStack(spacing: 4) {
                                    Spacer()
                                    Text(tab.rawValue)
                                        .font(.body)
                                        .fontWeight(selectedTab == tab ? .medium : .regular)
                                        .foregroundStyle(selectedTab == tab ? Color.blue : .primary.opacity(0.7))
                                    
                                    // Fine indicator line at the bottom of the active tab
                                    Rectangle()
                                        .fill(selectedTab == tab ? Color.blue : Color.clear)
                                        .frame(height: 2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(Color(nsColor: .windowBackgroundColor))
                    
                    Divider()
                    
                    // Tab Content Workspace Canvas
                    restContent
                        .id(selectedTab)
                        .transition(.asymmetric(
                            insertion: .move(edge: slideDirection).combined(with: .opacity),
                            removal: .move(edge: slideDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
                        ))
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .animation(.snappy(duration: 0.22, extraBounce: 0), value: selectedTab)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: request.requestType)
        .sheet(isPresented: $showAgentConsole) {
            AgentConsoleView(
                aiCoordinator: aiCoordinator,
                networkManager: network,
                environment: environment,
                activeRequest: request
            )
        }
        .sheet(isPresented: $showCodeGenSheet) {
            VStack(spacing: 0) {
                HStack {
                    Text("Code Snippets & Models")
                        .font(.headline)
                    Spacer()
                    Button("Close") {
                        showCodeGenSheet = false
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding()
                
                Divider()
                
                CodeGenView(request: request)
            }
            .frame(minWidth: 600, minHeight: 500)
        }
        .alert("Request Failed", isPresented: Binding(
            get: { network.isLoading == false && network.error != nil },
            set: { if !$0 { network.error = nil } }
        )) {
            Button("OK", role: .cancel) { network.error = nil }
        } message: {
            Text(network.error?.localizedDescription ?? "An unknown error occurred.")
        }
        // 🛠️ Updated to the non-deprecated platform closures syntax
        .onChange(of: selectedTab) { oldValue, newValue in
            let oldIndex = EditorTab.allCases.firstIndex(of: oldValue) ?? 0
            let newIndex = EditorTab.allCases.firstIndex(of: newValue) ?? 0
            slideDirection = newIndex > oldIndex ? .trailing : .leading
        }
        .onChange(of: request.urlString) { _, _ in autoSave() }
        .onChange(of: request.httpMethod) { _, _ in autoSave() }
        .onChange(of: request.requestType) { _, _ in autoSave() }
        .onChange(of: request.requestBody) { _, _ in autoSave() }
        .onChange(of: request.params) { _, _ in autoSave() }
        .onChange(of: request.headers) { _, _ in autoSave() }
        .onChange(of: request.auth) { _, _ in autoSave() }
        .onChange(of: request.authToken) { _, _ in autoSave() }
        .onChange(of: request.graphqlQuery) { _, _ in autoSave() }
        .onChange(of: request.graphqlVariables) { _, _ in autoSave() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RunActiveRequest"))) { notification in
            guard let req = notification.object as? APIRequest, req.id == request.id else { return }
            Task { await runRequest() }
        }
    }
    
    private func autoSave() {
        request.updatedAt = Date()
        try? modelContext.save()
    }
    
    // MARK: - URL Bar View
    private var urlBar: some View {
        HStack(spacing: 10) {
            Picker("", selection: $request.httpMethod) {
                ForEach(HTTPMethod.allCases, id: \.self) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            .frame(width: 90)
            .controlSize(.large)

            TextField("https://api.example.com/v1/resource", text: $request.urlString)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .controlSize(.large)
                .frame(minWidth: 0)
                .layoutPriority(1)

            Button {
                showAgentConsole.toggle()
            } label: {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)
            }
            .controlSize(.large)
            .help("Open AI Agent (Intent)")

            Button {
                Task { await runRequest() }
            } label: {
                HStack(spacing: 6) {
                    if network.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    Text(network.isLoading ? "Sending..." : "Send")
                }
                .frame(width: network.isLoading ? 95 : 70)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(network.isLoading)
            .animation(.snappy(duration: 0.2), value: network.isLoading)
            
            CommitButtonView(request: request)
                .buttonStyle(.bordered)
                .controlSize(.large)
            
            Button {
                showCodeGenSheet = true
            } label: {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Show Code Snippets")
        }
    }

    // MARK: - Tab Router
    @ViewBuilder
    private var restContent: some View {
        switch selectedTab {
        case .params:
            KVPairEditor(pairs: $request.params, title: "Query Parameters")
        case .headers:
            KVPairEditor(pairs: $request.headers, title: "HTTP Headers")
        case .auth:
            AuthEditorView(request: request)
        case .body:
            BodyEditorView(request: request)
        }
    }

    private func runRequest() async {
        if let response = await network.execute(request, env: environment) {
            await MainActor.run {
                onResponseReceived?(response)
            }
        }
    }
}

// MARK: - Optimized KVPairEditor Header Spacing
struct KVPairEditor: View {
    @Binding var pairs: [KVPair]
    let title: String
    
    @State private var showPastePopover = false
    @State private var bulkText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                
                if !pairs.isEmpty {
                    Button("Clear All", role: .destructive) {
                        withAnimation { pairs.removeAll() }
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.trailing, 8)
                }
                
                Button("Paste Raw") { showPastePopover.toggle() }
                    .buttonStyle(.link)
                    .font(.caption)
                    .popover(isPresented: $showPastePopover, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Paste Raw \(title)").font(.headline)
                            Text("Paste text formatted as 'Key: Value' on each line.").font(.caption).foregroundStyle(.secondary)
                            TextEditor(text: $bulkText)
                                .font(.system(.caption, design: .monospaced))
                                .frame(width: 300, height: 150)
                                .padding(4)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                            HStack {
                                Spacer()
                                Button("Cancel") { showPastePopover = false }.keyboardShortcut(.escape, modifiers: [])
                                Button("Import") {
                                    parseBulkText()
                                    showPastePopover = false
                                }.buttonStyle(.borderedProminent)
                            }
                        }
                        .padding()
                    }
            }
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()

            if pairs.isEmpty {
                ContentUnavailableView {
                    Label("No \(title)", systemImage: title.contains("Header") ? "list.bullet.rectangle" : "text.badge.plus")
                } description: {
                    Text("Add key-value pairs or paste raw text to customize your \(requestName).")
                } actions: {
                    Button("Add Row") {
                        withAnimation { pairs.append(KVPair(key: "", value: "")) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach($pairs) { $pair in
                        HStack(spacing: 12) {
                            Toggle("", isOn: $pair.isEnabled)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                            
                            TextField("Key", text: $pair.key)
                                .textFieldStyle(.plain)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity)
                            
                            Divider().frame(height: 16)
                            
                            TextField("Value", text: $pair.value)
                                .textFieldStyle(.plain)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity)
                            
                            Button {
                                withAnimation { pairs.removeAll { $0.id == pair.id } }
                            } label: {
                                Image(systemName: "trash").foregroundColor(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        .cornerRadius(6)
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                        .listRowSeparator(.hidden)
                    }
                    
                    Button {
                        withAnimation { pairs.append(KVPair(key: "", value: "")) }
                    } label: {
                        Label("Add Row", systemImage: "plus")
                            .font(.caption.bold())
                            .padding(.leading, 4)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
    }
    
    private var requestName: String {
        title.lowercased().contains("header") ? "headers" : "parameters"
    }
    
    private func parseBulkText() {
        let lines = bulkText.components(separatedBy: .newlines)
        var newPairs: [KVPair] = []
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !key.isEmpty { newPairs.append(KVPair(key: key, value: value)) }
            } else if parts.count == 1 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !key.isEmpty { newPairs.append(KVPair(key: key, value: "")) }
            }
        }
        if !newPairs.isEmpty {
            withAnimation { pairs.append(contentsOf: newPairs) }
        }
        bulkText = ""
    }
}

// MARK: - BodyEditorView Workspace Panel
struct BodyEditorView: View {
    @Bindable var request: APIRequest
    let contentTypes = ["application/json", "application/xml", "application/x-www-form-urlencoded", "text/plain"]
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Content-Type:")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                
                Menu {
                    ForEach(contentTypes, id: \.self) { type in
                        Button(type) { setContentType(type) }
                    }
                } label: {
                    Text(currentContentType() ?? "Not Set")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                
                Spacer()
                
                Button(isCopied ? "Copied!" : "Copy") { copyToClipboard() }
                    .buttonStyle(.plain)
                    .font(.caption.bold())
                    .foregroundStyle(isCopied ? .green : .blue)
                
                Button("Clear", role: .destructive) {
                    withAnimation { request.requestBody = "" }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.leading, 12)
            }
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()

            VStack(spacing: 0) {
                TextEditor(text: $request.requestBody)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Divider()
                    .padding(.horizontal, 16)
                
                HStack {
                    Text("Supports JSON, XML, or Plain Text. Drag files directly into editor.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Format JSON") {
                        guard let data = request.requestBody.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data),
                              let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .withoutEscapingSlashes]),
                              let formatted = String(data: pretty, encoding: .utf8) else { return }
                        withAnimation {
                            request.requestBody = formatted
                        }
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 10))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                if let provider = providers.first {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url, let content = try? String(contentsOf: url, encoding: .utf8) {
                            DispatchQueue.main.async {
                                self.request.requestBody = content
                            }
                        }
                    }
                    return true
                }
                return false
            }
        }
    }
    
    private func currentContentType() -> String? {
        request.headers.first(where: { $0.key.lowercased() == "content-type" && $0.isEnabled })?.value
    }
    
    private func setContentType(_ type: String) {
        if let idx = request.headers.firstIndex(where: { $0.key.lowercased() == "content-type" }) {
            request.headers[idx].value = type
            request.headers[idx].isEnabled = true
        } else {
            request.headers.append(KVPair(key: "Content-Type", value: type))
        }
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(request.requestBody, forType: .string)
        withAnimation(.snappy(duration: 0.15)) { isCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { isCopied = false }
        }
    }
}

// MARK: - AuthEditorView Layout Configuration
struct AuthEditorView: View {
    @Bindable var request: APIRequest
    @State private var isSecure = true
    @State private var isCopied = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Authentication Strategy")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Picker("", selection: $request.auth) {
                    Text("No Auth").tag(AuthType.none)
                    Text("Bearer Token").tag(AuthType.bearer)
                    Text("Basic Auth").tag(AuthType.basic)
                    Text("API Key").tag(AuthType.apiKey)
                }
                .pickerStyle(.menu)
                .frame(width: 140)
                .labelsHidden()
            }
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()

            VStack(alignment: .leading, spacing: 0) {
                switch request.auth {
                case .none:
                    ContentUnavailableView {
                        Label("No Authentication", systemImage: "lock.open")
                    } description: {
                        Text("This request will be sent without any authorization headers.")
                    }
                    .frame(maxHeight: .infinity)
                    
                case .bearer, .basic, .apiKey:
                    List {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(authTitle)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Button(isCopied ? "Copied!" : "Copy Token") {
                                    copyToClipboard()
                                }
                                .buttonStyle(.plain)
                                .font(.caption.bold())
                                .foregroundStyle(isCopied ? .green : .blue)
                                .disabled(request.authToken.isEmpty)
                            }
                            .padding(.top, 8)
                            
                            HStack(spacing: 12) {
                                Image(systemName: "key.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 16)
                                
                                if isSecure {
                                    SecureField(authPlaceholder, text: $request.authToken)
                                        .textFieldStyle(.plain)
                                        .font(.system(.body, design: .monospaced))
                                } else {
                                    TextField(authPlaceholder, text: $request.authToken)
                                        .textFieldStyle(.plain)
                                        .font(.system(.body, design: .monospaced))
                                }
                                
                                Button {
                                    isSecure.toggle()
                                } label: {
                                    Image(systemName: isSecure ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                            .cornerRadius(6)
                            
                            Text(authDescription)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 2)
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Contextual Helpers
    private var authTitle: String {
        switch request.auth {
        case .bearer: return "Bearer Token"
        case .basic: return "Credentials (username:password)"
        case .apiKey: return "API Key Value"
        default: return ""
        }
    }
    
    private var authPlaceholder: String {
        switch request.auth {
        case .bearer: return "e.g. eyJhbGciOiJIUzI1NiIs..."
        case .basic: return "username:password"
        case .apiKey: return "e.g. x-api-key-value"
        default: return ""
        }
    }
    
    private var authDescription: String {
        switch request.auth {
        case .bearer:
            return "Automatically appended as a header: `Authorization: Bearer <Token>`"
        case .basic:
            return "Automatically Base64-encoded and appended as: `Authorization: Basic <Base64>`"
        case .apiKey:
            return "Appended directly as configured by your API authentication requirements."
        default:
            return ""
        }
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(request.authToken, forType: .string)
        withAnimation(.snappy(duration: 0.15)) { isCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { isCopied = false }
        }
    }
}
