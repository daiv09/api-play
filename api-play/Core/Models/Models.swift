import Foundation
import SwiftData

// MARK: - Enums

/// Standard HTTP methods supported by the client.
enum HTTPMethod: String, CaseIterable, Codable {
    case GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS
}

/// Authentication strategies for requests.
enum AuthType: String, CaseIterable, Codable {
    case none = "No Auth"
    case bearer = "Bearer Token"
    case basic = "Basic Auth"
    case apiKey = "API Key"
}

/// Distinguishes between standard REST and GraphQL operations.
enum RequestType: String, Codable, CaseIterable {
    case rest = "REST"
    case graphql = "GraphQL"
}

// MARK: - Supporting Structures

/// A generic Key-Value pair used for Headers, Query Parameters, and Environment Variables.
struct KVPair: Codable, Identifiable, Hashable {
    var id = UUID()
    var key: String = ""
    var value: String = ""
    var isEnabled: Bool = true
}

/// A snapshot of an HTTP response.
/// Optimized to support binary data for Quick Look (Images, PDFs, Videos).
struct APIResponse: Codable, Hashable {
    var id = UUID()
    var statusCode: Int
    
    /// 📎 CRITICAL: Stores raw bytes to prevent corruption of non-textual responses.
    var bodyData: Data?
    
    var headers: [String: String]
    var body: String
    var elapsedSeconds: Double
    var byteCount: Int
    var url: String
    
    /// Returns a human-readable status string (e.g., "200 OK").
    var statusLabel: String {
        HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized
    }

    /// Helper to determine if the request fell within the 2xx range.
    var isSuccess: Bool {
        (200..<300).contains(statusCode)
    }
}

// MARK: - SwiftData Models

/// Represents a collection of requests, supporting hierarchical nesting.
@Model
final class RequestFolder {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var order: Int

    /// Relationship: Cascade deletes all requests within this folder.
    @Relationship(deleteRule: .cascade, inverse: \APIRequest.folder)
    var requests: [APIRequest]?

    /// Relationship: Supports nested folder structures.
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

/// The primary model for an API request in api-play.
@Model
final class APIRequest {

    // MARK: - Core Request Data
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

    // MARK: - Metadata
    var isFavorite: Bool
    var tags: [String]

    // MARK: - GraphQL Specifics
    var requestType: RequestType
    var graphqlQuery: String
    var graphqlVariables: String

    // MARK: - Response Cache
    /// Stores the result of the most recent execution.
    var lastResponse: APIResponse?
    
    // MARK: - Schema Drift Monitor
    var baselineSchema: String?
    var hasDrifted: Bool

    // MARK: - Relationships
    var folder: RequestFolder?

    // MARK: - Initialization
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
        
        self.hasDrifted = false
    }
}
