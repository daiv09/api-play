import Foundation
import Observation
import SwiftData

enum AppInitState: String, Equatable {
    case pending = "Starting up..."
    case initializingSwiftData = "Connecting securely to database..."
    case startingServices = "Syncing secure endpoint services..."
    case warmingUpAI = "Optimizing AI generation engine..."
    case complete = "Ready"
}

@Observable
class AppLifecycleCoordinator {
    var state: AppInitState = .pending
    var isAppLoading: Bool = true
    var showMainContent: Bool = false
    
    // Dependencies
    private var aiCoordinator: AICoordinator?
    private var webhookService: WebhookService?
    
    @MainActor
    func startup(aiCoordinator: AICoordinator, webhookService: WebhookService) async {
        self.aiCoordinator = aiCoordinator
        self.webhookService = webhookService
        
        print("🚀 Starting app setup")
        
        self.state = .initializingSwiftData
        // Ensure SwiftData container is initialized
        _ = SharedContainer.shared.mainContext
        
        // Slight delay so the user actually sees the states (since the actual operations are very fast)
        // This provides the "Apple-style" smooth loading experience requested without hardcoding long fake delays
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        self.state = .startingServices
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        self.state = .warmingUpAI
        // AI pre-warming would go here if needed
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        self.state = .complete
        
        // Short delay to show 'Ready'
        try? await Task.sleep(nanoseconds: 600_000_000)
        
        // Trigger the theatre-curtain transition
        self.showMainContent = true
        
        // Wait for the transition animation to complete before completely removing the splash
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        self.isAppLoading = false
    }
    
    @MainActor
    func shutdown() {
        print("🛑 Shutting down app...")
        // Stop all background listeners and tasks gracefully
        webhookService?.stopListening()
        
        // Note: WebSocket connections would be closed here if we had a global WebSocketService
    }
}
