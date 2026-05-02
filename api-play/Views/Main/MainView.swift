import SwiftUI
import SwiftData

struct MainView: View {
    // MARK: - Dependencies
    @Environment(AICoordinator.self) private var aiCoordinator
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext
    
    // Fetch environments for the toolbar picker
    @Query(sort: \APIEnvironment.name) private var environments: [APIEnvironment]
    
    // MARK: - State
    @State private var selectedRequest: APIRequest?
    @State private var selectedEnvironment: APIEnvironment?
    
    // UI States
    @State private var showAIInsights = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showCommandPalette = false

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
                    
                    // LEFT SIDE: Editor and Response (Flexible Column)
                    VSplitView {
                        // 1. Request Editor
                        EditorView(request: request, environment: selectedEnvironment) { response in
                            request.lastResponse = response
                            request.updatedAt = Date()
                            try? modelContext.save()
                        }
                        .frame(minHeight: 200, maxHeight: .infinity)

                        // 2. Response Area with AI Overlay
                        ZStack(alignment: .trailing) {
                            ResponseView(
                                response: request.lastResponse,
                                requestId: request.id
                            )
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
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                            }
                        }
                        .frame(minHeight: 250, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity)

                    // RIGHT SIDE: Code Generation (Fixed Sidebar Column)
                    CodeGenView(request: request)
                        .frame(width: 350)
                        .background(Color(nsColor: .windowBackgroundColor))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else {
                // Placeholder State
                ContentUnavailableView(
                    "Select a Request",
                    systemImage: "tray.fill",
                    description: Text("Choose a request from the sidebar to start debugging.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // MARK: - Toolbars
        .toolbar {
            // 1. AI Insights Toggle
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showAIInsights.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .symbolEffect(.bounce, value: showAIInsights)
                    }
                }
                .keyboardShortcut("i", modifiers: .command)
                .help("Toggle AI Insights")
            }

            // 2. New Window Button
            ToolbarItem(placement: .status) {
                Button {
                    if let req = selectedRequest {
                        openWindow(id: "request-detail", value: req.id)
                    }
                } label: {
                    Image(systemName: "macwindow.badge.plus")
                }
                .disabled(selectedRequest == nil)
                .help("Open in New Window")
            }

            // 3. Environment Picker
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
        }
        // MARK: - Commands & Shortcuts
        .background {
            Button("") { showCommandPalette.toggle() }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
        }
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView()
                .frame(width: 500, height: 400)
        }
    }
}
