import Foundation
import SwiftData

@Model
class APIHistory: Identifiable {
    var id: UUID = UUID()
    var url: String
    var method: String
    var requestBody: String
    var responseBody: String
    var statusCode: Int
    var timestamp: Date
    var duration: Double
    
    init(url: String, method: String, requestBody: String, responseBody: String, statusCode: Int, duration: Double) {
        self.url = url
        self.method = method
        self.requestBody = requestBody
        self.responseBody = responseBody
        self.statusCode = statusCode
        self.duration = duration
        self.timestamp = Date()
    }
}
