import SwiftUI
import SwiftData

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
#endif // os(macOS)

@main
struct api_playApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    // MARK: - App State
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding = true
    @State private var isAppLoading = true
    
    // MARK: - Splash Animation States
    @State private var iconScale: CGFloat = 0.65
    @State private var iconBlur: CGFloat = 10.0
    @State private var iconOpacity: Double = 0.0
    @State private var iconShadowOpacity: Double = 0.0
    @State private var progressOpacity: Double = 0.0
    
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
            ZStack {
                if isAppLoading {
                    ZStack {
                        // 1. Apple-standard pure white background canvas
                        Color.white
                            .edgesIgnoringSafeArea(.all)
                        
                        // 2. Cinematic ambient radial background drop shadow glow
                        RadialGradient(
                            colors: [Color.black.opacity(0.03), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 300
                        )
                        .edgesIgnoringSafeArea(.all)

                        VStack(spacing: 16) {
                            // 3. Main Animating App Icon Asset
                            Image(nsImage: NSApplication.shared.applicationIconImage) // Make sure this exists in your Assets folder!
                                .resizable()
                                .scaledToFit()
                                .frame(width: 128, height: 128)
                                // Cinematic Entry Layer Effects
                                .scaleEffect(iconScale)
                                .blur(radius: iconBlur)
                                .opacity(iconOpacity)
                                .shadow(color: Color.black.opacity(iconShadowOpacity), radius: 15, x: 0, y: 10)
                            
                            // 4. Elegant Minimalist Loading Indicator matching Apple OS styling
                            ProgressView()
                                .controlSize(.small)
                                .opacity(progressOpacity)
                        }
                    }
                    .onAppear {
                        // Pop the icon in with an ultra-smooth fluid spring animation
                        withAnimation(.interpolatingSpring(mass: 1.0, stiffness: 90, damping: 12, initialVelocity: 2)) {
                            iconScale = 1.0
                            iconBlur = 0.0
                            iconOpacity = 1.0
                            iconShadowOpacity = 0.15
                        }
                        
                        // Fade in the loading progress micro-indicator gently shortly after
                        withAnimation(.easeIn(duration: 0.4).delay(0.4)) {
                            progressOpacity = 0.6
                        }
                        
                        // PHASE 2: Wait for SwiftData to prime, then trigger the cinematic outward exit sweep
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            // Smoothly hide the progress indicator first
                            withAnimation(.linear(duration: 0.18)) {
                                progressOpacity = 0.0
                            }
                            
                            // Dramatic outward scale snap-fade (Netflix/Apple style exit)
                            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.45)) {
                                iconScale = 1.35
                                iconBlur = 8.0
                                iconOpacity = 0.0
                                iconShadowOpacity = 0.0
                            }
                            
                            // Lift the complete curtain to reveal MainView
                            withAnimation(.easeInOut(duration: 0.4).delay(0.15)) {
                                isAppLoading = false
                            }
                        }
                    }
                } else {
                    MainView()
                        .modelContainer(sharedModelContainer)
                        .environment(aiCoordinator)
                        .environment(webhookService)
                        .sheet(isPresented: $shouldShowOnboarding) {
                            OnboardingView(isShowing: $shouldShowOnboarding)
                        }
                }
            }
            .frame(
                minWidth: 1000,
                idealWidth: 1400,
                maxWidth: .infinity,
                minHeight: 600,
                idealHeight: 900,
                maxHeight: .infinity
            )
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .windowResizability(.automatic)
        .defaultSize(width: 1400, height: 900)
        
        // MARK: - Global macOS Menu Bar Commands
        .commands {
            SidebarCommands()
            
            CommandGroup(replacing: .newItem) {
                Button("AI Command Bar...") {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TriggerCommandPalette"),
                        object: nil
                    )
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
        #endif // os(macOS)
        
        #if os(macOS)
        // MARK: - Quick Request Menu Bar
        MenuBarExtra("Quick Request", systemImage: "bolt.fill") {
            QuickRequestView()
                .modelContainer(sharedModelContainer)
        }
        .menuBarExtraStyle(.window)
        #endif // os(macOS)
    }
}
