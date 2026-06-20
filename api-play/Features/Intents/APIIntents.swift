import AppIntents
import SwiftData
import CoreSpotlight
import UniformTypeIdentifiers

// MARK: - App Entities

struct APIRequestEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "API Request"
    static var defaultQuery = APIRequestQuery()
    
    var id: UUID
    var name: String
    var urlString: String
    var method: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(method) \(urlString)")
    }
}

struct APIRequestQuery: EntityQuery {
    func entities(for identifiers: [APIRequestEntity.ID]) async throws -> [APIRequestEntity] {
        let modelContainer = await SharedContainer.shared
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<APIRequest>(predicate: #Predicate { identifiers.contains($0.id) })
        let requests = try context.fetch(descriptor)
        return requests.map { APIRequestEntity(id: $0.id, name: $0.name, urlString: $0.urlString, method: $0.httpMethod.rawValue) }
    }
    
    func suggestedEntities() async throws -> [APIRequestEntity] {
        let modelContainer = await SharedContainer.shared
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<APIRequest>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        let requests = try context.fetch(descriptor)
        return requests.prefix(10).map { APIRequestEntity(id: $0.id, name: $0.name, urlString: $0.urlString, method: $0.httpMethod.rawValue) }
    }
}

// MARK: - App Intents

struct ExecuteRequestIntent: AppIntent {
    static var title: LocalizedStringResource = "Execute API Request"
    static var description = IntentDescription("Runs a saved API Request from api-play.")

    @Parameter(title: "Request")
    var request: APIRequestEntity

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let modelContainer = SharedContainer.shared
        let context = ModelContext(modelContainer)
        let reqID = request.id
        let descriptor = FetchDescriptor<APIRequest>(predicate: #Predicate { $0.id == reqID })
        
        guard let apiRequest = try context.fetch(descriptor).first else {
            return .result(value: "Request not found.")
        }
        
        let networkManager = NetworkManager()
        if let response = await networkManager.execute(apiRequest, env: nil) {
            apiRequest.updatedAt = Date()
            try? context.save()
            return .result(value: "Successfully executed \(apiRequest.name) with status \(response.statusCode)")
        } else {
            return .result(value: "Failed to execute request.")
        }
    }
}

struct APIPlayShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ExecuteRequestIntent(),
            phrases: [
                "Run \(.applicationName) request \(\.$request)",
                "Execute \(.applicationName) \(\.$request)"
            ],
            shortTitle: "Execute Request",
            systemImageName: "play.fill"
        )
    }
}

// MARK: - Core Spotlight Integration

class SpotlightManager {
    static func index(request: APIRequest) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .item)
        attributeSet.title = request.name
        attributeSet.contentDescription = "\(request.httpMethod.rawValue) \(request.urlString)"
        
        let item = CSSearchableItem(uniqueIdentifier: request.id.uuidString, domainIdentifier: "com.api-play.requests", attributeSet: attributeSet)
        
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                print("Spotlight indexing error: \(error.localizedDescription)")
            }
        }
    }
    
    static func deindex(requestID: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [requestID.uuidString]) { error in
            if let error = error {
                print("Spotlight deindexing error: \(error.localizedDescription)")
            }
        }
    }
}
