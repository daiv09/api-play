import Foundation
import SwiftData

@MainActor
class PersistenceController {
    /// The shared singleton instance for the app
    static let shared = PersistenceController()
    
    /// The ModelContainer provides the schema and storage configuration
    let container: ModelContainer
    
    private init() {
        // 1. Define the Schema
        // This must include all models tagged with @Model
        let schema = Schema([
            APIRequest.self,
            APIEnvironment.self
            // Add any future models here (e.g., APIFolder.swift)
        ])
        
        // 2. Configure Storage
        // We set allowsSave: true and determine if we want to store in memory (for testing)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            // 3. Initialize the Container
            // We use a do-catch block because model migration can sometimes fail
            // if the schema changes drastically between app updates.
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not initialize SwiftData Container: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Saves any pending changes in the main context
    func save() {
        if container.mainContext.hasChanges {
            do {
                try container.mainContext.save()
            } catch {
            }
        }
    }
    
    /// Clears all local data (Useful for "Reset App" features)
    func clearAllData() {
        do {
            try container.mainContext.delete(model: APIRequest.self)
            try container.mainContext.delete(model: APIEnvironment.self)
            try container.mainContext.save()
        } catch {
        }
    }
}
