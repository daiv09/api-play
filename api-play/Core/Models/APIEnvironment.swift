import Foundation
import SwiftData

@Model
final class APIEnvironment {
    var id: UUID
    var name: String
    var createdAt: Date
    var isActive: Bool // This property is required by your MainView/Sidebar logic

    @Relationship(deleteRule: .cascade, inverse: \EnvVar.environment)
    var variables: [EnvVar] = []
    
    init(name: String = "New Environment") {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.isActive = false
        self.variables = []
    }
}

@Model
final class EnvVar { // Ensure this matches the name in your error message
    var id: UUID
    var key: String
    var value: String
    var isEnabled: Bool
    var isSensitive: Bool // Matches your previous Models.swift requirements
    
    var environment: APIEnvironment?
    
    init(key: String = "", value: String = "", isEnabled: Bool = true, isSensitive: Bool = false) {
        self.id = UUID()
        self.key = key
        self.value = value
        self.isEnabled = isEnabled
        self.isSensitive = isSensitive
    }
}
