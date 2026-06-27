import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct EditorView: View {
    @Environment(AICoordinator.self) private var aiCoordinator
    @Bindable var request: APIRequest
    var environment: APIEnvironment?
    
    @State private var showAgentConsole = false // Controls the sheet
    @State private var showCodeGenSheet = false // Controls the CodeGen sheet

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
            // 🔹 URL & METHOD BAR
            HStack(spacing: 12) {
                // Type Switcher (REST vs GraphQL)
                Picker("", selection: $request.requestType) {
                    Text("REST").tag(RequestType.rest)
                    Text("GraphQL").tag(RequestType.graphql)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                
                urlBar
            }
            .padding(.horizontal, 16)
            .frame(height: 38, alignment: .center)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            
            Divider()

            // 🔹 TAB NAVIGATION
            HStack {
                Picker("", selection: $selectedTab) {
                    ForEach(EditorTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            // 🔹 TAB CONTENT
            ZStack {
                if request.requestType == .graphql {
                    GraphQLEditorView(
                        query: $request.graphqlQuery,
                        variables: $request.graphqlVariables
                    )
                    .transition(.opacity)
                } else {
                    restContent
                        .id(selectedTab)
                        .transition(.asymmetric(
                            insertion: .move(edge: slideDirection).combined(with: .opacity),
                            removal: .move(edge: slideDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.snappy(duration: 0.22, extraBounce: 0), value: selectedTab)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: request.requestType)
            // ADD THIS MODIFIER HERE:
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Network error alert
        .alert("Request Failed", isPresented: Binding(
            get: { network.isLoading == false && network.error != nil },
            set: { if !$0 { network.error = nil } }
        )) {
            Button("OK", role: .cancel) { network.error = nil }
        } message: {
            Text(network.error?.localizedDescription ?? "An unknown error occurred.")
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            let oldIndex = EditorTab.allCases.firstIndex(of: oldValue) ?? 0
            let newIndex = EditorTab.allCases.firstIndex(of: newValue) ?? 0
            slideDirection = newIndex > oldIndex ? .trailing : .leading
        }

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

            // 🤖 NEW: AI Agent Trigger Button
            Button {
                showAgentConsole.toggle()
            } label: {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue) // Changes the sparkles to native blue
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
            
            Button {
                request.updatedAt = Date()
                SpotlightManager.index(request: request)
            } label: {
                Image(systemName: "tray.and.arrow.down")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Save (⌘S)")
            
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

struct KVPairEditor: View {
    @Binding var pairs: [KVPair]
    let title: String
    
    @State private var showPastePopover = false
    @State private var bulkText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header with bulk actions
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                
                if !pairs.isEmpty {
                    Button("Clear All", role: .destructive) {
                        withAnimation {
                            pairs.removeAll()
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.trailing, 8)
                }
                
                Button("Paste Raw") {
                    showPastePopover.toggle()
                }
                .buttonStyle(.link)
                .font(.caption)
                .popover(isPresented: $showPastePopover, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paste Raw \(title)")
                            .font(.headline)
                        Text("Paste text formatted as 'Key: Value' on each line.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextEditor(text: $bulkText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 300, height: 150)
                            .padding(4)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                        
                        HStack {
                            Spacer()
                            Button("Cancel") { showPastePopover = false }
                                .keyboardShortcut(.escape, modifiers: [])
                            Button("Import") {
                                parseBulkText()
                                showPastePopover = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()

            if pairs.isEmpty {
                ContentUnavailableView {
                    Label("No \(title)", systemImage: title.contains("Header") ? "list.bullet.rectangle" : "text.badge.plus")
                } description: {
                    Text("Add key-value pairs or paste raw text to customize your \(requestName).")
                } actions: {
                    Button("Add Row") {
                        withAnimation {
                            pairs.append(KVPair(key: "", value: ""))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
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
                                withAnimation {
                                    pairs.removeAll { $0.id == pair.id }
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red.opacity(0.7))
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
                        withAnimation {
                            pairs.append(KVPair(key: "", value: ""))
                        }
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
                if !key.isEmpty {
                    newPairs.append(KVPair(key: key, value: value))
                }
            } else if parts.count == 1 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !key.isEmpty {
                    newPairs.append(KVPair(key: key, value: ""))
                }
            }
        }
        if !newPairs.isEmpty {
            withAnimation {
                pairs.append(contentsOf: newPairs)
            }
        }
        bulkText = ""
    }
}

struct BodyEditorView: View {
    @Bindable var request: APIRequest
    
    // Quick helper array
    let contentTypes = ["application/json", "application/xml", "application/x-www-form-urlencoded", "text/plain"]
    @State private var copyBannerText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Action Bar
            HStack {
                Text("Content-Type:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Menu {
                    ForEach(contentTypes, id: \.self) { type in
                        Button(type) { setContentType(type) }
                    }
                } label: {
                    Text(currentContentType() ?? "Not Set")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                
                Spacer()
                
                if let banner = copyBannerText {
                    Text(banner)
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
                
                Button {
                    copyToClipboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Copy Body")
                
                Button {
                    withAnimation { request.requestBody = "" }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Clear Body")
                .padding(.leading, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()

            TextEditor(text: $request.requestBody)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        
            Divider()
            
            // Footer
            HStack {
                Text("Supports JSON, XML, or Plain Text.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Format JSON") {
                    guard let data = request.requestBody.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data),
                          let pretty = try? JSONSerialization.data(withJSONObject: json,
                                                                   options: [.prettyPrinted, .withoutEscapingSlashes]),
                          let formatted = String(data: pretty, encoding: .utf8) else { return }
                    withAnimation {
                        request.requestBody = formatted
                    }
                }
                .buttonStyle(.link)
                .font(.system(size: 10))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor))
            .frame(maxWidth: .infinity)
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
        withAnimation { copyBannerText = "Copied!" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copyBannerText = nil }
        }
    }
}

struct AuthEditorView: View {
    @Bindable var request: APIRequest
    @State private var isSecure = true
    @State private var copyBannerText: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text("Authentication")
                        .font(.headline)
                    Spacer()
                    Picker("", selection: $request.auth) {
                        Text("No Auth").tag(AuthType.none)
                        Text("Bearer Token").tag(AuthType.bearer)
                        Text("Basic Auth").tag(AuthType.basic)
                        Text("API Key").tag(AuthType.apiKey)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }
                .padding(.bottom, 8)
                
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        switch request.auth {
                        case .bearer:
                            authField(title: "Bearer Token", placeholder: "e.g. eyJhbGciOiJIUzI1NiIs...", isSecret: true)
                            Text("The token will be added to the request as: `Authorization: Bearer <Token>`")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        case .basic:
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Credentials")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                                
                                HStack {
                                    if isSecure {
                                        SecureField("username:password", text: $request.authToken)
                                            .textFieldStyle(.roundedBorder)
                                            .controlSize(.large)
                                            .font(.system(.body, design: .monospaced))
                                    } else {
                                        TextField("username:password", text: $request.authToken)
                                            .textFieldStyle(.roundedBorder)
                                            .controlSize(.large)
                                            .font(.system(.body, design: .monospaced))
                                    }
                                    
                                    Button {
                                        isSecure.toggle()
                                    } label: {
                                        Image(systemName: isSecure ? "eye.slash" : "eye")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.leading, 4)
                                }
                                
                                Text("This value is automatically Base64-encoded and sent as `Authorization: Basic <Base64>`")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        case .apiKey:
                            authField(title: "API Key", placeholder: "e.g. x-api-key-value", isSecret: true)
                            Text("Note: If the API Key should be a header or query parameter, consider setting it manually in the Headers or Params tab depending on the API's requirements.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        case .none:
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "lock.open")
                                        .font(.largeTitle)
                                        .foregroundStyle(.tertiary)
                                    Text("No authentication will be used with this request.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 20)
                                Spacer()
                            }
                        }
                    }
                    .padding(8)
                }
                
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    @ViewBuilder
    private func authField(title: String, placeholder: String, isSecret: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if let banner = copyBannerText {
                    Text(banner)
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
                
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(request.authToken, forType: .string)
                    withAnimation { copyBannerText = "Copied!" }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { copyBannerText = nil }
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.blue)
                .disabled(request.authToken.isEmpty)
            }
            
            HStack {
                if isSecure && isSecret {
                    SecureField(placeholder, text: $request.authToken)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                        .font(.system(.body, design: .monospaced))
                } else {
                    TextField(placeholder, text: $request.authToken)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                        .font(.system(.body, design: .monospaced))
                }
                
                if isSecret {
                    Button {
                        isSecure.toggle()
                    } label: {
                        Image(systemName: isSecure ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                }
            }
        }
    }
}
