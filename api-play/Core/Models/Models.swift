import Foundation
import SwiftData

// MARK: - Enums

enum HTTPMethod: String, CaseIterable, Codable {
    case GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS
}

enum AuthType: String, CaseIterable, Codable {
    case none = "No Auth"
    case bearer = "Bearer Token"
    case basic = "Basic Auth"
    case apiKey = "API Key"
}

enum RequestType: String, Codable, CaseIterable {
    case rest = "REST"
    case graphql = "GraphQL"
}

// MARK: - Supporting Structures

struct KVPair: Codable, Identifiable, Hashable {
    var id = UUID()
    var key: String = ""
    var value: String = ""
    var isEnabled: Bool = true
}

/// Updated to support binary data for Quick Look (Images, PDFs)
struct APIResponse: Codable, Hashable {
    var id = UUID()
    var statusCode: Int
    
    /// 📎 CRITICAL: Store the raw bytes here to prevent image corruption
    var bodyData: Data?
    
    var headers: [String: String]
    var body: String
    var elapsedSeconds: Double
    var byteCount: Int
    var url: String
    
    var statusLabel: String {
        HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized
    }

    var isSuccess: Bool {
        (200..<300).contains(statusCode)
    }
}

// MARK: - SwiftData Models

@Model
final class RequestFolder {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var order: Int

    @Relationship(deleteRule: .cascade, inverse: \APIRequest.folder)
    var requests: [APIRequest]?

    @Relationship(deleteRule: .cascade, inverse: \RequestFolder.parent)
    var children: [RequestFolder]?

    var parent: RequestFolder?

    init(name: String, order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.order = order
        self.requests = []
        self.children = []
    }
}

// MARK: - APIRequest

@Model
final class APIRequest {

    // MARK: - Core
    @Attribute(.unique) var id: UUID
    var name: String
    var urlString: String
    var httpMethod: HTTPMethod

    var params: [KVPair]
    var headers: [KVPair]
    var requestBody: String

    var auth: AuthType
    var authToken: String

    var updatedAt: Date

    // MARK: - Favorites & Tags
    var isFavorite: Bool
    var tags: [String]

    // MARK: - GraphQL Support
    var requestType: RequestType
    var graphqlQuery: String
    var graphqlVariables: String

    // MARK: - Response
    var lastResponse: APIResponse?

    // MARK: - Relationships
    var folder: RequestFolder?

    // MARK: - Init
    init(name: String = "New Request") {
        self.id = UUID()
        self.name = name
        self.urlString = ""
        self.httpMethod = .GET

        self.params = []
        self.headers = []
        self.requestBody = ""

        self.auth = .none
        self.authToken = ""

        self.updatedAt = Date()

        self.isFavorite = false
        self.tags = []

        self.requestType = .rest
        self.graphqlQuery = ""
        self.graphqlVariables = ""
    }
}
