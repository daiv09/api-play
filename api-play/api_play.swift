import SwiftUI
import SwiftData

@main
struct api_playApp: App {
    
    // MARK: - App State
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding = true
    
    // Apple Intelligence coordinator tied to the App Scene lifecycle
    @State private var aiCoordinator = AICoordinator()
    
    // Webhook Service
    @State private var webhookService = WebhookService()
    
    // MARK: - Model Container Setup
    /// Central SwiftData container managing the lifecycle of requests and environments
    var sharedModelContainer: ModelContainer {
        SharedContainer.shared
    }

    var body: some Scene {
        
        // MARK: - Primary Application Window
        WindowGroup {
            MainView()
                .frame(
                    minWidth: 1000,
                    idealWidth: 1400,
                    maxWidth: .infinity,
                    minHeight: 600,
                    idealHeight: 900,
                    maxHeight: .infinity
                )
                // Injecting SwiftData context and AI Coordinator into the environment
                .modelContainer(sharedModelContainer)
                .environment(aiCoordinator)
                .environment(webhookService)
                .sheet(isPresented: $shouldShowOnboarding) {
                    OnboardingView(isShowing: $shouldShowOnboarding)
                }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .windowResizability(.automatic)
        .defaultSize(width: 1400, height: 900)
        
        // MARK: - Global macOS Menu Bar Commands
        .commands {
            // Standard macOS Menu Items (Hide/Show Sidebar, Toggle Fullscreen)
            SidebarCommands()
            
            // Custom Command Group for AI and Navigation
            CommandGroup(replacing: .newItem) {
                Button("AI Command Bar...") {
                    // Posts a notification that the CommandPalette component listens for
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TriggerCommandPalette"),
                        object: nil
                    )
                }
                .keyboardShortcut("k", modifiers: .command)
            }
            
            // Add a Help/Status check group
            CommandGroup(after: .help) {
                Divider()
                Button("Check AI Engine Status") {
                    // Logic to check if FoundationModels are loaded
                    print("AI Availability: \(aiCoordinator.isAnalyzing)")
                }
            }
        }
        #endif

        WindowGroup("Request Detail", id: "request-detail", for: APIRequest.ID.self) { $requestId in
            if let id = requestId {
                ResponseDetailView(requestId: id)
                    .modelContainer(sharedModelContainer)
                    .environment(aiCoordinator)
            } else {
                ContentUnavailableView("No Request Selected", systemImage: "tray")
            }
        }
        
        // MARK: - Visual Flow Builder
        WindowGroup("Visual Flow Builder", id: "visual-flow-builder") {
            CanvasView()
                .modelContainer(sharedModelContainer)
                .environment(aiCoordinator)
        }
        .defaultSize(width: 800, height: 600)
        
        #if os(macOS)
        // MARK: - Quick Request Menu Bar
        MenuBarExtra("Quick Request", systemImage: "bolt.fill") {
            QuickRequestView()
                .modelContainer(sharedModelContainer)
        }
        .menuBarExtraStyle(.window) // Uses a popover instead of a strict menu list
        #endif
    }
}
