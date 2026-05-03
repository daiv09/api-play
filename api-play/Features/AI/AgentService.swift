import Foundation
import SwiftData
import Observation

@Observable
class AgentService {
    var isRunning = false
    var steps: [AgentStep] = []
    var logs: [String] = []
    
    private let ai: AICoordinator
    private let network: NetworkManager
    
    init(ai: AICoordinator, network: NetworkManager) {
        self.ai = ai
        self.network = network
    }
    
    @MainActor
    func run(goal: String, requests: [APIRequest], environment: APIEnvironment?) async {
        isRunning = true
        logs.removeAll()
        logs.append("🤖 Planning task: \(goal)")
        
        do {
            // 1. Get the plan from AI
            self.steps = try await ai.planAgentTask(goal: goal, availableRequests: requests)
            logs.append("✅ Plan generated: \(steps.count) steps.")
            
            // 2. Execute steps sequentially
            for i in 0..<steps.count {
                let step = steps[i]
                logs.append("🚀 Executing: \(step.requestName)...")
                
                // Find the actual request object by name
                guard let request = requests.first(where: { $0.name == step.requestName }) else {
                    logs.append("❌ Error: Could not find request named '\(step.requestName)'")
                    continue
                }
                
                // Execute the request
                if let response = await network.execute(request, env: environment) {
                    if response.isSuccess {
                        logs.append("✅ Step \(i+1) completed (HTTP \(response.statusCode))")
                        
                        // 3. Handle Variable Extraction (Chain data to environment)
                        if let key = step.extractionKey,
                           let extractedValue = network.extractValue(from: response, keyPath: key) {
                            
                            logs.append("🔗 Extracted '\(key)': \(extractedValue)")
                            
                            if let env = environment {
                                updateOrAppendVariable(in: env, key: key, value: extractedValue)
                            }
                        }
                    } else {
                        logs.append("⚠️ Step \(i+1) failed (Status \(response.statusCode)). Stopping.")
                        break
                    }
                }
            }
        } catch {
            logs.append("❌ Agent Error: \(error.localizedDescription)")
        }
        
        isRunning = false
        logs.append("🏁 Agent task finished.")
    }
    
    /// Logic to update existing EnvVar or create a new one within the SwiftData Environment
    @MainActor
    private func updateOrAppendVariable(in env: APIEnvironment, key: String, value: String) {
        if let existingVar = env.variables.first(where: { $0.key == key }) {
            // Update existing value
            existingVar.value = value
        } else {
            // Create a new EnvVar model instance
            let newVar = EnvVar(key: key, value: value)
            newVar.environment = env
            env.variables.append(newVar)
        }
    }
}
