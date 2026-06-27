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
    @SceneStorage("lastSelectedRequestId") private var lastSelectedRequestId: String = ""
    
    // UI States
    @State private var showAIInsights = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showCommandPalette = false
    @State private var showCodeGen = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
                    // SIDEBAR
                    VStack(spacing: 0) {
                        SidebarView(
                            selectedRequest: $selectedRequest,
                            selectedEnvironment: $selectedEnvironment
                        )
                        
                        // This acts as a rigid, uncrushable buffer block outside the List content context
                        Color.clear
                            .frame(height: 16)
                            .layoutPriority(10) // Prevents the window constraint engine from compressing this out of existence
                    }
                    .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 320)
                    
                } detail: {
            // MAIN CONTENT AREA
            Group {
                if let request = selectedRequest {
                    HStack(spacing: 0) {
                        // LEFT SIDE: Editor and Response
                        VSplitView {
                            EditorView(request: request, environment: selectedEnvironment) { response in
                                request.lastResponse = response
                                request.updatedAt = Date()
                                try? modelContext.save()
                            }
                            .frame(minHeight: 320, maxHeight: .infinity)

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
                        .frame(minWidth: 600, idealWidth: 800, maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity
                    ))
                } else {
                    ContentUnavailableView(
                        "Select a Request",
                        systemImage: "tray.fill",
                        description: Text("Choose a request from the sidebar to start debugging.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedRequest)
            .frame(minWidth: 600, idealWidth: 800, maxWidth: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .inspector(isPresented: $showCodeGen) {
            if let request = selectedRequest {
                CodeGenView(request: request)
                    .inspectorColumnWidth(min: 250, ideal: 350, max: 500)
            } else {
                Text("Select a Request")
                    .foregroundStyle(.secondary)
            }
        }
        .safeAreaPadding(.top)
        .background {
            Button("") { showCommandPalette.toggle() }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
        }
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView().frame(width: 500, height: 400)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("SelectRequestInMainView")
            )
        ) { notification in
            if let request = notification.object as? APIRequest {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    selectedRequest = request
                }
            }
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
            if selectedRequest == nil, let uuid = UUID(uuidString: lastSelectedRequestId) {
                let descriptor = FetchDescriptor<APIRequest>()
                if let request = try? modelContext.fetch(descriptor).first(where: { $0.id == uuid }) {
                    selectedRequest = request
                }
            }
        }
        .onChange(of: selectedRequest) { _, newValue in
            if let id = newValue?.id.uuidString {
                lastSelectedRequestId = id
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TriggerCommandPalette"))) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                showCommandPalette = true
            }
        }
        .toolbar {
            if !showCommandPalette {
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
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ToggleCodeGenSidebar"))) { _ in
            withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
                self.showCodeGen.toggle()
            }
        }
    }
}
