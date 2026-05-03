import SwiftData
import Foundation

class SharedContainer {
    @MainActor
    static let shared: ModelContainer = {
        let schema = Schema([
            RequestFolder.self,
            APIRequest.self,
            APIEnvironment.self
        ])
        
        // Optional AppGroup fallback for preview/testing without capabilities
        let appGroupIdentifier = "group.com.api-play.shared"
        var url: URL
        
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            url = containerURL.appendingPathComponent("api-play.sqlite")
        } else {
            // Fallback to Application Support if App Group is not configured
            let fallbackDir = URL.applicationSupportDirectory
            if !FileManager.default.fileExists(atPath: fallbackDir.path) {
                try? FileManager.default.createDirectory(at: fallbackDir, withIntermediateDirectories: true)
            }
            url = fallbackDir.appendingPathComponent("api-play.sqlite")
        }
        
        let modelConfiguration = ModelConfiguration(url: url)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error.localizedDescription)")
        }
    }()
}
