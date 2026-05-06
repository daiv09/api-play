import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct EditorView: View {
    @Bindable var request: APIRequest
    var environment: APIEnvironment?
    
    @State private var showAgentConsole = false // Controls the sheet

    @StateObject private var network = NetworkManager()
    var onResponseReceived: ((APIResponse) -> Void)?
    @State private var selectedTab: EditorTab = .params
    @State private var isShowingCommitSheet = false
    @State private var commitMessage = ""
    @State private var commitDescription = ""

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
                    
                    HStack(spacing: 4) {
                        Image(systemName: "tag.fill").font(.caption2).foregroundStyle(.secondary)
                        TextField("v1", text: Binding(
                            get: { request.version ?? "" },
                            set: { request.version = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .frame(width: 50)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
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
                        aiCoordinator: AICoordinator(), // Pass your instance here
                        networkManager: network         // Use the @StateObject 'network' defined in EditorView
                    )
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $isShowingCommitSheet) {
            commitSheet
        }
    }
    
    private var commitSheet: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("Commit Changes")
                            .font(.headline)
                        Text("Provide a summary of the changes to this request.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 8)

                // Input Fields
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Message").font(.caption).bold()
                        TextField("Update endpoint URL...", text: $commitMessage)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description").font(.caption).bold()
                        TextEditor(text: $commitDescription)
                            .font(.system(.body))
                            .frame(height: 80)
                            .padding(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.2)))
                    }
                }
            }
            .padding(20)

            Divider()

            // macOS Standard Button Placement
            HStack {
                Button("Cancel") { isShowingCommitSheet = false }
                    .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Button("Commit") {
                    saveCommit()
                    isShowingCommitSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(commitMessage.isEmpty)
                .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 450) // Fixed width, flexible height is more native
    }
    private func saveCommit() {
        let commit = RequestCommit(message: commitMessage, description: commitDescription, request: request)
        // SwiftData will handle the insertion if relationship is set, but better to be explicit
        request.modelContext?.insert(commit)
        commitMessage = ""
        commitDescription = ""
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
                    .foregroundStyle(.purple)
            }
            .buttonStyle(.bordered)
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
            
            Button {
                isShowingCommitSheet = true
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Commit Changes")
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
            List {
                // Remove the Section header to save vertical space if needed
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
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)) // 🔹 Force edge alignment
                }
                
                Button {
                    pairs.append(KVPair(key: "", value: ""))
                } label: {
                    Label("Add Parameter", systemImage: "plus")
                        .font(.caption)
                        .padding(.leading, 4)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.bordered) // 🔹 Better for edge-to-edge content on macOS
            .scrollContentBackground(.hidden)
        }
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
                                Button("Format JSON") { /* logic */ }
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
