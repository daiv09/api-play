import Foundation
import Observation
import FoundationModels // Ensure this is available in your Xcode project settings

@Observable
class AICoordinator {
    // MARK: - State Properties
    var isAnalyzing = false
    var analysisResult = ""
    
    // MARK: - Text/JSON Analysis
    
    /// Analyzes the API response body using on-device Apple Intelligence
    func explainResponse(_ body: String) async {
        // 1. Availability Check
        guard SystemLanguageModel.default.isAvailable else {
            await updateAnalysis("Apple Intelligence is still downloading or unavailable on this device.")
            return
        }

        await startAnalysis()
        
        // 2. Truncation Logic for Token Limits
        let maxCharacters = 2000
        let isTruncated = body.count > maxCharacters
        let processedBody = isTruncated ? String(body.prefix(maxCharacters)) : body
        
        do {
            let session = try await LanguageModelSession()
            
            // 3. Prompt Engineering
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
    
    // MARK: - Computer Vision Analysis
    
    /// NEW: Analyzes text extracted via Computer Vision (Vision Framework) from the Preview/UI
    func analyzeVisualContext(text: String) {
        // Since we want to use the Language Model to interpret the Vision results,
        // we wrap this in a Task to handle the async LanguageModelSession.
        Task {
            guard !text.isEmpty else {
                await updateAnalysis("The visual scan completed, but no readable text was identified.")
                return
            }
            
            await startAnalysis()
            
            do {
                let session = try await LanguageModelSession()
                
                let prompt = """
                The following text was extracted from a UI screenshot using Computer Vision OCR.
                Describe what this interface likely is (e.g., a login page, a dashboard, a search result) 
                and list the primary interactive elements you detect.
                
                Extracted Text:
                \(text)
                """
                
                let response = try await session.respond(to: prompt)
                await finishAnalysis(with: "**Visual Interpretation:**\n\n\(response.content)")
                
            } catch {
                // Fallback if the Language Model fails, just show the OCR raw text
                await finishAnalysis(with: "**Raw Visual Data (OCR):**\n\n\(text)")
            }
        }
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
