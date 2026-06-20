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
    var failureReason: String? = nil
    
    // Support dynamic request creation
    var urlToCreate: String? = nil
    var methodToCreate: String? = nil
    
    enum StepStatus: String, Codable {
        case pending, running, success, failed
    }
    
    enum CodingKeys: String, CodingKey {
        case requestName, reason, extractionKey, urlToCreate, methodToCreate, status, failureReason
    }
    
    init(requestName: String, reason: String, extractionKey: String? = nil, urlToCreate: String? = nil, methodToCreate: String? = nil) {
        self.requestName = requestName
        self.reason = reason
        self.extractionKey = extractionKey
        self.urlToCreate = urlToCreate
        self.methodToCreate = methodToCreate
        self.id = UUID()
        self.status = .pending
        self.failureReason = nil
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.requestName = try container.decode(String.self, forKey: .requestName)
        self.reason = try container.decode(String.self, forKey: .reason)
        self.extractionKey = try container.decodeIfPresent(String.self, forKey: .extractionKey)
        self.urlToCreate = try container.decodeIfPresent(String.self, forKey: .urlToCreate)
        self.methodToCreate = try container.decodeIfPresent(String.self, forKey: .methodToCreate)
        self.status = try container.decodeIfPresent(StepStatus.self, forKey: .status) ?? .pending
        self.failureReason = try container.decodeIfPresent(String.self, forKey: .failureReason)
        self.id = UUID()
    }
}

@Observable
class AICoordinator {
    // MARK: - State Properties
    var isAnalyzing = false
    var analysisResult = ""
    
    // MARK: - Intent -> API Agent (Feature 1)
    
    /// Generates a sequence of steps based on a natural language goal.
    /// If the goal contains a direct URL, the heuristic planner is always used
    /// (guarantees a single focused step). The AI path is reserved for
    /// named-request chaining goals like "run Login then fetch User".
    func planAgentTask(goal: String, availableRequests: [APIRequest], activeRequest: APIRequest? = nil) async throws -> [AgentStep] {
        // 1. Resolve contextual keywords before routing
        var resolvedGoal = goal
        if let activeRequest = activeRequest {
            let keywords = ["this link", "current link", "the link", "active link"]
            for kw in keywords {
                resolvedGoal = resolvedGoal.replacingOccurrences(of: kw, with: activeRequest.urlString, options: .caseInsensitive)
            }
        }
        
        // 2. If the goal references a direct URL, always use the focused heuristic planner.
        //    This prevents the AI from picking up unrelated database requests and chaining them.
        let goalContainsURL = goalHasURL(resolvedGoal)
        if goalContainsURL {
            print("ℹ️ Goal contains a direct URL — using focused single-step heuristic planner.")
            return try planAgentTaskHeuristically(goal: goal, availableRequests: availableRequests, activeRequest: activeRequest)
        }
        
        // 3. For named-request goals (no URL), try the AI planner first.
        if SystemLanguageModel.default.isAvailable {
            do {
                return try await planAgentTaskWithAI(goal: goal, availableRequests: availableRequests, activeRequest: activeRequest)
            } catch {
                print("⚠️ On-device LLM failed to plan. Falling back to heuristic planner. Error: \(error)")
                return try planAgentTaskHeuristically(goal: goal, availableRequests: availableRequests, activeRequest: activeRequest)
            }
        } else {
            print("ℹ️ Apple Intelligence is unavailable on this device. Using heuristic planner.")
            return try planAgentTaskHeuristically(goal: goal, availableRequests: availableRequests, activeRequest: activeRequest)
        }
    }

    /// Streaming variant of `planAgentTask`.
    /// Yields each `AgentStep` individually through an `AsyncThrowingStream`
    /// so the consumer can execute each step the moment it is produced,
    /// without waiting for the full plan to be resolved.
    func stepStream(
        goal: String,
        availableRequests: [APIRequest],
        activeRequest: APIRequest? = nil
    ) -> AsyncThrowingStream<AgentStep, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let plannedSteps = try await self.planAgentTask(
                        goal: goal,
                        availableRequests: availableRequests,
                        activeRequest: activeRequest
                    )
                    for step in plannedSteps {
                        continuation.yield(step)   // one step at a time into the stream
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    
    /// Returns true if the text contains any http/https URL.
    private func goalHasURL(_ text: String) -> Bool {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if detector?.firstMatch(in: text, options: [], range: range) != nil {
            return true
        }
        return text.split(separator: " ").contains(where: {
            $0.hasPrefix("http://") || $0.hasPrefix("https://")
        })
    }

    
    private func planAgentTaskWithAI(goal: String, availableRequests: [APIRequest], activeRequest: APIRequest? = nil) async throws -> [AgentStep] {
        // 1. Build context
        let context = availableRequests.map { "- \($0.name) (\($0.httpMethod)): \($0.urlString)" }.joined(separator: "\n")
        
        var promptGoal = goal
        if let activeRequest = activeRequest {
            let urlPlaceholderKeywords = ["this link", "current link", "the link", "active link"]
            for keyword in urlPlaceholderKeywords {
                if promptGoal.lowercased().contains(keyword) {
                    promptGoal = promptGoal.replacingOccurrences(of: keyword, with: activeRequest.urlString, options: .caseInsensitive)
                }
            }
        }
        
        // 2. Optimized Prompt for on-device Foundation Models
        let prompt = """
        Role: You are a professional API Orchestrator.
        Context: You have access to a list of API requests and a user goal.

        Available Requests:
        \(context)

        User Goal: \(promptGoal)

        Task: Create a multi-step execution plan to achieve the goal. 
        - DO NOT chain or include unrelated requests from the Available Requests list. Only include requests that are explicitly mentioned by name in the User Goal, or are strictly required (e.g. login/auth dependencies) to achieve the goal.
        - If a response contains a value needed for a later step, provide an 'extractionKey' using JSONPath dot-notation (e.g., "data.user.token" or "items[0].id").
        - If the user goal asks to create a request for a URL/link that is NOT present in the Available Requests list (e.g. "post request for https://httpbin.org/post"), specify its properties in the output object using 'urlToCreate' and 'methodToCreate' keys.

        Output Requirements:
        1. Return ONLY a JSON array.
        2. No conversational text, no markdown code blocks, no explanations.
        3. Use this exact schema for each object:
           {
             "requestName": "The exact string from the Available Requests list, or a descriptive name if creating a new one",
             "reason": "Brief technical justification",
             "extractionKey": "Optional JSON key to save from response",
             "urlToCreate": "Optional URL string if the request needs to be dynamically created",
             "methodToCreate": "Optional HTTP method (GET, POST, PUT, DELETE, PATCH) if creating a request"
           }

        Example: [{"requestName": "httpbin.org/post", "reason": "Send payload to endpoint", "urlToCreate": "https://httpbin.org/post", "methodToCreate": "POST"}]
        """
        
        // 3. Get Response from Apple Foundation Model
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        
        // 4. Sanitization: Foundation Models often add conversational text.
        let rawContent = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let firstBracket = rawContent.firstIndex(of: "["),
              let lastBracket = rawContent.lastIndex(of: "]") else {
            print("🤖 Foundation Model Response: \(rawContent)")
            throw NSError(domain: "AICoordinator", code: 2, userInfo: [NSLocalizedDescriptionKey: "AI did not return a valid JSON array format."])
        }
        
        let cleanJsonString = String(rawContent[firstBracket...lastBracket])
        
        // 5. Parse the sanitized JSON string
        guard let data = cleanJsonString.data(using: .utf8) else { return [] }
        return try JSONDecoder().decode([AgentStep].self, from: data)
    }
    
    private func planAgentTaskHeuristically(goal: String, availableRequests: [APIRequest], activeRequest: APIRequest? = nil) throws -> [AgentStep] {
        var steps: [AgentStep] = []
        var resolvedGoal = goal
        let lowerGoal = goal.lowercased()
        
        // Resolve "this link", "current link", "the link", "active link"
        if let activeRequest = activeRequest {
            let urlPlaceholderKeywords = ["this link", "current link", "the link", "active link"]
            for keyword in urlPlaceholderKeywords {
                if lowerGoal.contains(keyword) {
                    resolvedGoal = resolvedGoal.replacingOccurrences(of: keyword, with: activeRequest.urlString, options: .caseInsensitive)
                }
            }
        }
        
        let finalGoalLower = resolvedGoal.lowercased()
        
        // 1. Check if the user is asking to create and run a request for a URL link
        if let url = extractURL(from: resolvedGoal) {
            // Determine HTTP method
            var method = "POST" // Default to POST as specified in user request
            if finalGoalLower.contains("get ") || finalGoalLower.contains("get request") {
                method = "GET"
            } else if finalGoalLower.contains("put ") || finalGoalLower.contains("put request") {
                method = "PUT"
            } else if finalGoalLower.contains("delete ") || finalGoalLower.contains("delete request") {
                method = "DELETE"
            } else if finalGoalLower.contains("patch ") || finalGoalLower.contains("patch request") {
                method = "PATCH"
            }
            
            // Create descriptive request name
            let host = URL(string: url)?.host ?? "api"
            let path = URL(string: url)?.path ?? ""
            let cleanPath = path.isEmpty || path == "/" ? "" : path
            let requestName = "\(host)\(cleanPath)"
            
            steps.append(AgentStep(
                requestName: requestName,
                reason: "Dynamically create and run new \(method) request for \(url)",
                extractionKey: nil,
                urlToCreate: url,
                methodToCreate: method
            ))
            
            return steps
        }
        
        // 2. Fallback to existing requests matching
        var detected: [(request: APIRequest, index: String.Index)] = []
        for req in availableRequests {
            let lowerName = req.name.lowercased()
            if let range = finalGoalLower.range(of: lowerName) {
                detected.append((req, range.lowerBound))
            }
        }
        
        // Sort by order of appearance in the goal text
        detected.sort { $0.index < $1.index }
        
        guard !detected.isEmpty else {
            throw NSError(
                domain: "AICoordinator",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Heuristic planner could not identify any matching API request names or link URLs in your goal. Please specify request names (e.g. '\(availableRequests.first?.name ?? "RequestName")') or a URL link in your prompt."]
            )
        }
        
        for i in 0..<detected.count {
            let req = detected[i].request
            var extractionKey: String? = nil
            let lowerReqName = req.name.lowercased()
            
            if i < detected.count - 1 {
                let startIdx = detected[i].index
                let endIdx = detected[i+1].index
                let segment = finalGoalLower[startIdx..<endIdx]
                
                if segment.contains("token") || segment.contains("save") || segment.contains("extract") || segment.contains("id") {
                    if segment.contains("id") {
                        extractionKey = "id"
                    } else if segment.contains("access_token") {
                        extractionKey = "access_token"
                    } else {
                        extractionKey = "token"
                    }
                } else if lowerReqName.contains("auth") || lowerReqName.contains("login") || lowerReqName.contains("token") {
                    extractionKey = "token"
                }
            } else {
                let startIdx = detected[i].index
                let segment = finalGoalLower[startIdx...]
                if segment.contains("save") || segment.contains("extract") {
                    if segment.contains("id") {
                        extractionKey = "id"
                    } else if segment.contains("access_token") {
                        extractionKey = "access_token"
                    } else {
                        extractionKey = "token"
                    }
                }
            }
            
            // Default token extraction for auth-related requests
            if extractionKey == nil && (lowerReqName.contains("login") || lowerReqName.contains("auth") || lowerReqName.contains("token")) {
                extractionKey = "token"
            }
            
            steps.append(AgentStep(
                requestName: req.name,
                reason: "Identify request '\(req.name)' inside goal statement",
                extractionKey: extractionKey
            ))
        }
        
        return steps
    }
    
    private func extractURL(from text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = detector?.firstMatch(in: text, options: [], range: range),
           let url = match.url {
            return url.absoluteString
        }
        
        // Fallback word check for prefixing
        let words = text.split(separator: " ")
        for word in words {
            let w = String(word).trimmingCharacters(in: CharacterSet(charactersIn: "\"'`,;()[]{}"))
            if w.hasPrefix("http://") || w.hasPrefix("https://") {
                return w
            }
        }
        return nil
    }
    // MARK: - Text/JSON Analysis
    
    /// Analyzes the API response body using on-device Apple Intelligence.
    func explainResponse(_ body: String) async {
        guard SystemLanguageModel.default.isAvailable else {
            updateAnalysis("Apple Intelligence is still downloading or unavailable on this device.")
            return
        }

        startAnalysis()
        
        let maxCharacters = 2000
        let isTruncated = body.count > maxCharacters
        let processedBody = isTruncated ? String(body.prefix(maxCharacters)) : body
        
        do {
            let session = LanguageModelSession()
            
            let prompt = """
            You are a professional developer assistant. Analyze the following JSON/Data structure. 
            IMPORTANT: The data may be truncated due to size limits. Do not complain about missing braces; 
            simply describe the fields, patterns, and potential purpose of the data you see.
            
            Data:
            \(processedBody)
            """
            
            let response = try await session.respond(to: prompt)
            finishAnalysis(with: response.content)
        } catch {
            finishAnalysis(with: "### AI Error\n\(error.localizedDescription)")
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
        
        let session = LanguageModelSession()
        
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
                updateAnalysis("The visual scan completed, but no readable text was identified.")
                return
            }
            
            startAnalysis()
            
            do {
                let session = LanguageModelSession()
                
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
                finishAnalysis(with: "**Visual Interpretation:**\n\n\(response.content)")
                
            } catch {
                // Fallback: If the AI fails, show the raw OCR data
                finishAnalysis(with: "**Raw Visual Data (OCR):**\n\n\(text)\n\n*Source: \(sourceURL)*")
            }
        }
    }
    
    @MainActor
    func parseImageToRequest(text: String) async throws -> APIRequest {
        guard SystemLanguageModel.default.isAvailable else {
            throw NSError(domain: "AICoordinator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence is unavailable."])
        }
        
        let session = LanguageModelSession()
        
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
