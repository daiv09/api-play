import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct EditorView: View {
    @Environment(AICoordinator.self) private var aiCoordinator
    @Bindable var request: APIRequest
    var environment: APIEnvironment?
    
    @State private var showAgentConsole = false // Controls the sheet

    @StateObject private var network = NetworkManager()
    var onResponseReceived: ((APIResponse) -> Void)?
    @State private var selectedTab: EditorTab = .params

    enum EditorTab: String, CaseIterable {
        case params = "Params"
        case headers = "Headers"
        case auth = "Auth"
        case body = "Body"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 🔹 URL & METHOD BAR
            VStack(spacing: 0) {
                // Type Switcher (REST vs GraphQL)
                HStack {
                    Picker("", selection: $request.requestType) {
                        Text("REST").tag(RequestType.rest)
                        Text("GraphQL").tag(RequestType.graphql)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                    
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.horizontal, 16)
                
                urlBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                
                Divider()
            }
            .background(.ultraThinMaterial)

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
                } else {
                    restContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // ADD THIS MODIFIER HERE:
                .sheet(isPresented: $showAgentConsole) {
                    AgentConsoleView(
                        aiCoordinator: aiCoordinator,
                        networkManager: network,
                        environment: environment,
                        activeRequest: request
                    )
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                HStack {
                    if network.isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text("Send")
                }
                .frame(width: 70)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(network.isLoading)
            
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

    var body: some View {
        VStack(spacing: 0) {
            if pairs.isEmpty {
                ContentUnavailableView {
                    Label("No \(title)", systemImage: title.contains("Header") ? "list.bullet.rectangle" : "text.badge.plus")
                } description: {
                    Text("Add key-value pairs to customize your \(requestName).")
                } actions: {
                    Button("Add Row") {
                        pairs.append(KVPair(key: "", value: ""))
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach($pairs) { $pair in
                        HStack {
                            Toggle("", isOn: $pair.isEnabled)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                            
                            TextField("Key", text: $pair.key)
                                .textFieldStyle(.plain)
                            
                            Divider().frame(height: 12)
                            
                            TextField("Value", text: $pair.value)
                                .textFieldStyle(.plain)
                            
                            Button {
                                pairs.removeAll { $0.id == pair.id }
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                    }
                    
                    Button {
                        pairs.append(KVPair(key: "", value: ""))
                    } label: {
                        Label("Add Row", systemImage: "plus")
                            .font(.caption)
                            .padding(.leading, 4)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.bordered)
                .scrollContentBackground(.hidden)
            }
        }
    }
    
    private var requestName: String {
        title.lowercased().contains("header") ? "headers" : "parameters"
    }
}

struct BodyEditorView: View {
    @Bindable var request: APIRequest
    
    var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                TextEditor(text: $request.requestBody)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // 🔹 Take all space
                    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    // 📎 Tier 4 Drop Logic
                    if let provider = providers.first {
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            if let url = url, let content = try? String(contentsOf: url) {
                                DispatchQueue.main.async {
                                    self.request.requestBody = content
                                }
                            }
                        }
                        return true
                    }
                    return false
                }
            
                Divider() // Visual separation for footer
                
                HStack {
                                Text("Supports JSON, XML, or Plain Text.")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Format JSON") {
                                    guard let data = request.requestBody.data(using: .utf8),
                                          let json = try? JSONSerialization.jsonObject(with: data),
                                          let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
                                          let formatted = String(data: prettyData, encoding: .utf8) else {
                                        return
                                    }
                                    request.requestBody = formatted
                                }
                                .buttonStyle(.link)
                                .font(.system(size: 10))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .frame(maxWidth: .infinity) // 🔹 Force footer width
        }
    }
}

struct AuthEditorView: View {
    @Bindable var request: APIRequest
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Authentication Type")
                    .font(.headline)
                    .padding(.bottom, 4)

                Picker("Type", selection: $request.auth) {
                    Text("None").tag(AuthType.none)
                    Text("Bearer Token").tag(AuthType.bearer)
                    Text("Basic Auth").tag(AuthType.basic)
                }
                .pickerStyle(.menu)
                .labelsHidden() // 🔹 Hide label to let picker use full width
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if request.auth == .bearer {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bearer Token").font(.caption).foregroundStyle(.secondary)
                        TextField("Enter token...", text: $request.authToken)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.large)
                    }
                }
                
                Spacer()
            }
            .padding(20) // Consistent inner padding, but fills width
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
