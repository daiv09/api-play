import Foundation
import AppKit
import Observation
import FoundationModels // Ensure this is available in your Xcode project settings

// MARK: - Agent Models

/// Represents a single executable step in an AI-generated plan.
struct AgentStep: Identifiable, Codable {
    var id: UUID = UUID()
    let requestName: String
    let reason: String
    var extractionKey: String? // The key to find in JSON and save to environment
    var status: StepStatus = .pending
    
    enum StepStatus: String, Codable {
        case pending, executing, completed, failed
    }
    
    enum CodingKeys: String, CodingKey {
        case requestName, reason, extractionKey
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.requestName = try container.decode(String.self, forKey: .requestName)
        self.reason = try container.decode(String.self, forKey: .reason)
        self.extractionKey = try container.decodeIfPresent(String.self, forKey: .extractionKey)
        self.id = UUID()
        self.status = .pending
    }
}

@Observable
class AICoordinator {
    // MARK: - State Properties
    var isAnalyzing = false
    var analysisResult = ""
    
    // MARK: - Intent -> API Agent (Feature 1)
    
    /// Generates a sequence of steps based on a natural language goal using ONLY Apple Foundation Models.
    func planAgentTask(goal: String, availableRequests: [APIRequest]) async throws -> [AgentStep] {
        guard SystemLanguageModel.default.isAvailable else {
            throw NSError(domain: "AICoordinator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence is unavailable."])
        }

        // 1. Build context
        let context = availableRequests.map { "- \($0.name) (\($0.httpMethod)): \($0.urlString)" }.joined(separator: "\n")
        
        // 2. Optimized Prompt for on-device Foundation Models
        let prompt = """
        Role: You are a professional API Orchestrator.
        Context: You have access to a list of API requests and a user goal.

        Available Requests:
        \(context)

        User Goal: \(goal)

        Task: Create a multi-step execution plan to achieve the goal. 
        - You must chain requests logically (e.g., Auth first, then Data).
        - If a response contains a value needed for a later step, provide an 'extractionKey' using JSONPath dot-notation (e.g., "data.user.token" or "items[0].id").

        Output Requirements:
        1. Return ONLY a JSON array.
        2. No conversational text, no markdown code blocks, no explanations.
        3. Use this exact schema for each object:
           {
             "requestName": "The exact string from the Available Requests list",
             "reason": "Brief technical justification",
             "extractionKey": "Optional JSON key to save from response"
           }

        Example: [{"requestName": "Login", "reason": "Get token", "extractionKey": "access_token"}]
        """
        
        // 3. Get Response from Apple Foundation Model
        let session = try await LanguageModelSession()
        let response = try await session.respond(to: prompt)
        
        // 4. SANitization: Foundation Models often add "Sure!" or "Here is the plan:".
        // We must find the actual JSON boundaries.
        let rawContent = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let firstBracket = rawContent.firstIndex(of: "["),
              let lastBracket = rawContent.lastIndex(of: "]") else {
            print("🤖 Foundation Model Response: \(rawContent)")
            throw NSError(domain: "AICoordinator", code: 2, userInfo: [NSLocalizedDescriptionKey: "AI did not return a valid JSON array format."])
        }
        
        let cleanJsonString = String(rawContent[firstBracket...lastBracket])
        
        // 5. Parse the sanitized JSON string
        guard let data = cleanJsonString.data(using: .utf8) else { return [] }
        
        do {
            return try JSONDecoder().decode([AgentStep].self, from: data)
        } catch {
            print("❌ Decoding Error: \(error)")
            print("🤖 Attempted to decode: \(cleanJsonString)")
            throw error
        }
    }
    // MARK: - Text/JSON Analysis
    
    /// Analyzes the API response body using on-device Apple Intelligence.
    func explainResponse(_ body: String) async {
        guard SystemLanguageModel.default.isAvailable else {
            await updateAnalysis("Apple Intelligence is still downloading or unavailable on this device.")
            return
        }

        await startAnalysis()
        
        let maxCharacters = 2000
        let isTruncated = body.count > maxCharacters
        let processedBody = isTruncated ? String(body.prefix(maxCharacters)) : body
        
        do {
            let session = try await LanguageModelSession()
            
            let prompt = """
            You are a professional developer assistant. Analyze the following JSON/Data structure. 
            IMPORTANT: The data may be truncated due to size limits. Do not complain about missing braces; 
            simply describe the fields, patterns, and potential purpose of the data you see.
            
            Data:
            \(processedBody)
            """
            
            let response = try await session.respond(to: prompt)
            await finishAnalysis(with: response.content)
        } catch {
            await finishAnalysis(with: "### AI Error\n\(error.localizedDescription)")
        }
    }
    
    // MARK: - Swift/Cocoa Code Generator
    
    /// Maps a JSON response body directly to Decodable Swift structs and a basic Service Class
    func generateSwiftModel(from jsonBody: String) async throws -> String {
        guard SystemLanguageModel.default.isAvailable else {
            return "// Apple Intelligence is unavailable on this device."
        }
        
        let maxCharacters = 3000
        let isTruncated = jsonBody.count > maxCharacters
        let processedBody = isTruncated ? String(jsonBody.prefix(maxCharacters)) + "..." : jsonBody
        
        let session = try await LanguageModelSession()
        
        let prompt = """
        Role: You are an expert iOS Developer.
        Task: Convert the following JSON response into conformant Swift `Codable` structs.
        Also, generate a basic Swift service class (e.g., `APIService`) with an async function to fetch and decode this data.
        
        Requirements:
        1. Output ONLY Swift code.
        2. No markdown blocks, no explanations, no conversational text.
        3. Use appropriate data types (String, Int, Bool, Date, Optional, etc.).
        
        JSON Data:
        \(processedBody)
        """
        
        let response = try await session.respond(to: prompt)
        
        // Strip markdown blocks if the model still includes them
        var code = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if code.hasPrefix("```swift") { code.removeFirst(8) }
        if code.hasPrefix("```") { code.removeFirst(3) }
        if code.hasSuffix("```") { code.removeLast(3) }
        
        return code.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Computer Vision Analysis
    
    /// Analyzes text and visual context extracted via Computer Vision.
    func analyzeVisualContext(text: String, sourceURL: String, image: NSImage) {
        Task {
            guard !text.isEmpty else {
                await updateAnalysis("The visual scan completed, but no readable text was identified.")
                return
            }
            
            await startAnalysis()
            
            do {
                let session = try await LanguageModelSession()
                
                // We include the URL in the prompt so the AI can better understand
                // the context of the page it's looking at.
                let prompt = """
                Context: The user is viewing an API response preview from the URL: \(sourceURL).
                
                The following text was extracted from the UI screenshot using Computer Vision OCR:
                "\(text)"
                
                Based on the URL and the extracted text, describe:
                1. What this interface/resource likely is.
                2. The primary interactive elements or data points detected.
                3. Any potential issues or observations regarding the layout.
                """
                
                let response = try await session.respond(to: prompt)
                await finishAnalysis(with: "**Visual Interpretation:**\n\n\(response.content)")
                
            } catch {
                // Fallback: If the AI fails, show the raw OCR data
                await finishAnalysis(with: "**Raw Visual Data (OCR):**\n\n\(text)\n\n*Source: \(sourceURL)*")
            }
        }
    }
    
    /// Parses OCR text from a screenshot into an APIRequest using Apple Intelligence
    func parseImageToRequest(text: String) async throws -> APIRequest {
        guard SystemLanguageModel.default.isAvailable else {
            throw NSError(domain: "AICoordinator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence is unavailable."])
        }
        
        let session = try await LanguageModelSession()
        
        let prompt = """
        Role: You are an expert API parser.
        Task: The user has provided text extracted via OCR from a screenshot of a terminal (cURL) or API documentation.
        Parse the text into a structured JSON representation of an API request.
        
        OCR Text:
        \(text)
        
        Requirements:
        1. Output ONLY JSON. No markdown formatting.
        2. Schema:
        {
          "name": "A descriptive name for the request",
          "urlString": "The full URL",
          "httpMethod": "GET" | "POST" | "PUT" | "DELETE" | "PATCH",
          "headers": [{"key": "Header-Name", "value": "Header-Value"}],
          "requestBody": "The body string (or empty)",
          "authType": "bearer" | "basic" | "apiKey" | "none",
          "authToken": "Extracted token if any"
        }
        """
        
        let response = try await session.respond(to: prompt)
        var rawContent = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Strip markdown if present
        if rawContent.hasPrefix("```json") { rawContent.removeFirst(7) }
        else if rawContent.hasPrefix("```") { rawContent.removeFirst(3) }
        if rawContent.hasSuffix("```") { rawContent.removeLast(3) }
        
        rawContent = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = rawContent.data(using: .utf8) else {
            throw NSError(domain: "AICoordinator", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to encode AI response to data."])
        }
        
        struct ParsedReq: Decodable {
            let name: String
            let urlString: String
            let httpMethod: String
            let headers: [[String: String]]
            let requestBody: String
            let authType: String
            let authToken: String
        }
        
        let parsed = try JSONDecoder().decode(ParsedReq.self, from: data)
        
        let newReq = APIRequest(name: parsed.name)
        newReq.urlString = parsed.urlString
        newReq.httpMethod = HTTPMethod(rawValue: parsed.httpMethod.uppercased()) ?? .GET
        newReq.requestBody = parsed.requestBody
        
        for h in parsed.headers {
            if let k = h["key"], let v = h["value"] {
                newReq.headers.append(KVPair(key: k, value: v, isEnabled: true))
            }
        }
        
        switch parsed.authType.lowercased() {
        case "bearer": newReq.auth = .bearer
        case "basic": newReq.auth = .basic
        case "apikey": newReq.auth = .apiKey
        default: newReq.auth = .none
        }
        newReq.authToken = parsed.authToken
        
        return newReq
    }
    
    // MARK: - Private Helpers (MainActor)
    
    @MainActor
    private func startAnalysis() {
        self.isAnalyzing = true
        self.analysisResult = "Analyzing..."
    }
    
    @MainActor
    private func updateAnalysis(_ text: String) {
        self.analysisResult = text
        self.isAnalyzing = false
    }
    
    @MainActor
    private func finishAnalysis(with result: String) {
        self.analysisResult = result
        self.isAnalyzing = false
    }
}
