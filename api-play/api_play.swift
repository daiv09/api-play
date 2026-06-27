import SwiftUI
import SwiftData

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
#endif

@main
struct api_playApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - App State
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding = true
    @State private var coordinator = AppLifecycleCoordinator()
    
    // Services
    @State private var aiCoordinator = AICoordinator()
    @State private var webhookService = WebhookService()
    
    var sharedModelContainer: ModelContainer {
        SharedContainer.shared
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main View - Only render its functional layers when splash drops
                if coordinator.showMainContent {
                    MainView()
                        .modelContainer(sharedModelContainer)
                        .environment(aiCoordinator)
                        .environment(webhookService)
                        .sheet(isPresented: $shouldShowOnboarding) {
                            OnboardingView(isShowing: $shouldShowOnboarding)
                        }
                        .transition(.opacity) // Smooth fade in as splash moves away
                } else {
                    // Temporary neutral background so nothing leaks through the splash
                    Color.white
                        .ignoresSafeArea()
                }
                
                // Splash Screen sliding upward like a theatre curtain
                if !coordinator.showMainContent {
                    SplashView(coordinator: coordinator)
                        .transition(.move(edge: .top))
                        .zIndex(1)
                }
            }
            .ignoresSafeArea(.all, edges: .bottom)
            // Apply the animation globally to the ZStack transitions
            .animation(.easeInOut(duration: 1.0), value: coordinator.showMainContent)
            .frame(minWidth: 1000, idealWidth: 1400, maxWidth: .infinity, minHeight: 600, idealHeight: 900, maxHeight: .infinity)
            .task {
                if coordinator.isAppLoading {
                    await coordinator.startup(aiCoordinator: aiCoordinator, webhookService: webhookService)
                }
            }
            #if os(macOS)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                coordinator.shutdown()
            }
            #endif
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .windowResizability(.automatic)
        .defaultSize(width: 1400, height: 900)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                coordinator.shutdown()
            }
        }
        .commands {
            SidebarCommands()
            
            CommandGroup(after: .windowArrangement) {
                Button("Show Main Window") {
                    NSApplication.shared.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut("0", modifiers: .command)
            }
            
            CommandGroup(replacing: .newItem) {
                Button("AI Command Bar...") {
                    NotificationCenter.default.post(name: NSNotification.Name("TriggerCommandPalette"), object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
            CommandGroup(after: .help) {
                Divider()
                Button("Check AI Engine Status") {
                    print("AI Availability: \(aiCoordinator.isAnalyzing)")
                }
            }
        }
        
        MenuBarExtra("Quick Request", systemImage: "bolt.fill") {
            QuickRequestView()
                .modelContainer(sharedModelContainer)
        }
        .menuBarExtraStyle(.window)
    }
}
