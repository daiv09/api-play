import SwiftData
import Foundation

class SharedContainer {
    @MainActor
    static let shared: ModelContainer = {
        // Full schema — every @Model type in the app must be listed here.
        // Missing a model causes SwiftData to silently drop relationships.
        let schema = Schema([
            APIRequest.self,
            RequestFolder.self,
            APIEnvironment.self,
            EnvVar.self,
            RequestCommit.self
        ])

        // Store in ~/Library/Application Support/<BundleID>/
        // This is the standard sandboxed location — no entitlements required.
        // DO NOT use FileManager.containerURL(forSecurityApplicationGroupIdentifier:)
        // unless you have a separate app extension that needs shared access.
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error.localizedDescription)")
        }
    }()
}
