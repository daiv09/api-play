import SwiftUI
import SwiftData

struct MainView: View {
    // MARK: - Dependencies
    @Environment(AICoordinator.self) private var aiCoordinator
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \APIEnvironment.name) private var environments: [APIEnvironment]
    
    // MARK: - State
    @State private var selectedRequest: APIRequest?
    @State private var selectedEnvironment: APIEnvironment?
    
    // UI States
    @State private var showAIInsights = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showCommandPalette = false
    @State private var showWebhook = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // SIDEBAR
            SidebarView(
                selectedRequest: $selectedRequest,
                selectedEnvironment: $selectedEnvironment
            )
            .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 350)
            
        } detail: {
            // MAIN CONTENT AREA
            if let request = selectedRequest {
                HStack(spacing: 0) {
                    // LEFT SIDE: Editor and Response
                    VSplitView {
                        EditorView(request: request, environment: selectedEnvironment) { response in
                            request.lastResponse = response
                            request.updatedAt = Date()
                            try? modelContext.save()
                        }
                        .frame(minHeight: 200, maxHeight: .infinity)

                        ZStack(alignment: .trailing) {
                            ResponseView(request: request)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            
                            if showAIInsights {
                                AIInspectorView(
                                    ai: aiCoordinator,
                                    bodyText: request.lastResponse?.body ?? "No response available."
                                )
                                .frame(width: 320)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(.white.opacity(0.1), lineWidth: 0.5)
                                )
                                .shadow(color: .black.opacity(0.15), radius: 15, x: -5, y: 5)
                                .padding(.trailing, 10)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing)
                                        .combined(with: .opacity)
                                        .animation(.spring(response: 0.38, dampingFraction: 0.78)),
                                    removal: .move(edge: .trailing)
                                        .combined(with: .opacity)
                                        .animation(.easeInOut(duration: 0.22))
                                ))
                            }
                        }
                        .frame(minHeight: 250, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity)

                    CodeGenView(request: request)
                        .frame(width: 350)
                        .background(Color(nsColor: .windowBackgroundColor))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else {
                ContentUnavailableView(
                    "Select a Request",
                    systemImage: "tray.fill",
                    description: Text("Choose a request from the sidebar to start debugging.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            // LEFT: Sidebar toggle + Create menu + AI Insights
            ToolbarItemGroup(placement: .navigation) {
                Menu {
                    Button {
                        let newRequest = APIRequest(name: "New Request")
                        modelContext.insert(newRequest)
                        selectedRequest = newRequest
                    } label: {
                        Label("New Request", systemImage: "plus.circle")
                    }

                    Button {
                        let newFolder = RequestFolder(name: "New Collection", order: 0)
                        modelContext.insert(newFolder)
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }

                    Divider()

                    Button {
                        let newEnv = APIEnvironment(name: "New Environment")
                        modelContext.insert(newEnv)
                        selectedEnvironment = newEnv
                    } label: {
                        Label("New Environment", systemImage: "leaf.fill")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .help("Create New...")

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showAIInsights.toggle()
                    }
                } label: {
                    Image(systemName: "sparkles")
                        .symbolEffect(.bounce, value: showAIInsights)
                }
                .keyboardShortcut("i", modifiers: .command)
                .help("Toggle AI Insights")
            }

            // CENTER: Environment Picker
            ToolbarItem(placement: .principal) {
                Picker("Environment", selection: $selectedEnvironment) {
                    Text("No Environment").tag(Optional<APIEnvironment>.none)
                    Divider()
                    ForEach(environments) { env in
                        Text(env.name).tag(Optional(env))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)
            }

            // RIGHT: Webhook + Flow Builder
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
                        showWebhook.toggle()
                    }
                } label: {
                    Image(systemName: "network.badge.shield.half.filled")
                        .symbolEffect(.pulse, isActive: showWebhook)
                }
                .help("Local Webhook Receiver")

                Button {
                    openWindow(id: "visual-flow-builder")
                } label: {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                }
                .help("Visual Flow Builder")
            }
        }
        .background {
            Button("") { showCommandPalette.toggle() }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
        }
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView().frame(width: 500, height: 400)
        }
        .inspector(isPresented: $showWebhook) {
            WebhookView()
        }
        .onChange(of: selectedEnvironment) { _, newValue in
            for env in environments {
                env.isActive = (env.id == newValue?.id)
            }
            try? modelContext.save()
        }
        .onAppear {
            if selectedEnvironment == nil {
                selectedEnvironment = environments.first(where: { $0.isActive })
            }
        }
    }
}
