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

    // MARK: - Streaming Execution Engine

    /// Streams planned steps one at a time and executes each immediately
    /// as soon as it lands in the queue, instead of planning everything
    /// upfront and then running in a separate pass.
    @MainActor
    func run(
        goal: String,
        requests: [APIRequest],
        environment: APIEnvironment?,
        activeRequest: APIRequest? = nil,
        modelContext: ModelContext
    ) async {
        isRunning = true
        steps.removeAll()
        logs.removeAll()
        logs.append("🤖 Starting agent for goal: \"\(goal)\"")

        do {
            // Stream steps from the planner one at a time.
            // Each step is appended to the UI immediately as .pending,
            // then executed in-place before the next step is fetched.
            for try await plannedStep in ai.stepStream(
                goal: goal,
                availableRequests: requests,
                activeRequest: activeRequest
            ) {
                // 1. Append step immediately so the UI renders it as Queued
                steps.append(plannedStep)
                let index = steps.count - 1

                logs.append("⚙️ Step \(index + 1) queued: \(plannedStep.requestName)")

                // 2. Execute this step right away — don't wait for more steps
                let shouldContinue = await executeStep(
                    at: index,
                    requests: requests,
                    environment: environment,
                    modelContext: modelContext
                )

                if !shouldContinue { break }
            }
        } catch {
            logs.append("❌ Agent pipeline error: \(error.localizedDescription)")
        }

        isRunning = false
        logs.append("🏁 Agent task finished.")
    }

    // MARK: - Step Execution

    /// Resolves, creates (if needed), and executes the step at the given index.
    /// Returns false if the pipeline should stop (on unrecoverable failure).
    @MainActor
    @discardableResult
    private func executeStep(
        at index: Int,
        requests: [APIRequest],
        environment: APIEnvironment?,
        modelContext: ModelContext
    ) async -> Bool {
        steps[index].status = .running
        let step = steps[index]

        logs.append("🚀 Executing: \(step.requestName)...")

        // -- Step 1: Resolve the APIRequest object --
        var resolvedRequest = requests.first(where: {
            $0.name == step.requestName || $0.urlString == step.requestName
        })

        var urlToUse = step.urlToCreate
        var methodToUse = step.methodToCreate

        // Fallback: try extracting a URL directly from the step name
        if resolvedRequest == nil && urlToUse == nil {
            let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let range = NSRange(step.requestName.startIndex..<step.requestName.endIndex, in: step.requestName)
            if let match = detector?.firstMatch(in: step.requestName, options: [], range: range),
               let url = match.url {
                urlToUse = url.absoluteString
                let upper = step.requestName.uppercased()
                if upper.contains("GET")    { methodToUse = "GET" }
                else if upper.contains("PUT")    { methodToUse = "PUT" }
                else if upper.contains("DELETE") { methodToUse = "DELETE" }
                else if upper.contains("PATCH")  { methodToUse = "PATCH" }
                else                             { methodToUse = "POST" }
            }
        }

        // -- Step 2: Dynamically create the request if it doesn't exist --
        if resolvedRequest == nil, let url = urlToUse {
            let methodStr = methodToUse ?? "POST"
            logs.append("📝 Creating '\(step.requestName)' [\(methodStr) \(url)]")
            let newReq = APIRequest(name: step.requestName)
            newReq.urlString = url
            newReq.httpMethod = HTTPMethod(rawValue: methodStr.uppercased()) ?? .POST
            modelContext.insert(newReq)
            try? modelContext.save()
            resolvedRequest = newReq
        }

        // -- Step 3: Guard — mark failed if still unresolved --
        guard let request = resolvedRequest else {
            steps[index].status = .failed
            steps[index].failureReason = "SwiftData lookup failed — no matching route for '\(step.requestName)'. Verify the request name or provide a full URL."
            logs.append("❌ \(steps[index].failureReason!)")
            return true // non-fatal: continue to next step
        }

        // -- Step 4: Execute the network request --
        if let response = await network.execute(request, env: environment) {
            // Always persist the response so ResponseView shows it immediately
            request.lastResponse = response
            request.updatedAt = Date()
            try? modelContext.save()

            if response.isSuccess {
                steps[index].status = .success
                logs.append("✅ Step \(index + 1) completed — HTTP \(response.statusCode)")

                // Chain extracted value into the active environment variable store
                if let key = step.extractionKey,
                   let value = network.extractValue(from: response, keyPath: key) {
                    logs.append("🔗 Extracted '\(key)': \(value)")
                    if let env = environment {
                        updateOrAppendVariable(in: env, key: key, value: value)
                    }
                }
                return true

            } else {
                steps[index].status = .failed
                steps[index].failureReason = "HTTP \(response.statusCode) — server rejected the request for '\(request.name)'. Check ResponseView for the error body."
                logs.append("⚠️ \(steps[index].failureReason!)")
                return false // fatal: stop the pipeline
            }
        } else {
            steps[index].status = .failed
            steps[index].failureReason = "No response received for '\(request.name)'. Check network connectivity or server availability."
            logs.append("⚠️ \(steps[index].failureReason!)")
            return false // fatal: stop the pipeline
        }
    }

    // MARK: - Environment Variable Helpers

    @MainActor
    private func updateOrAppendVariable(in env: APIEnvironment, key: String, value: String) {
        if let existing = env.variables.first(where: { $0.key == key }) {
            existing.value = value
        } else {
            let newVar = EnvVar(key: key, value: value)
            newVar.environment = env
            env.variables.append(newVar)
        }
    }
}
