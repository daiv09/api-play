import SwiftUI
import SwiftData

struct AgentConsoleView: View {
    // MARK: - Properties
    @Environment(\.dismiss) private var dismiss // Handles closing the popup
    @Environment(\.modelContext) private var modelContext
    
    @Query private var allRequests: [APIRequest]
    // Fetch the active environment to pass to the agent
    @Query(filter: #Predicate<APIEnvironment> { $0.isActive == true }) private var activeEnvs: [APIEnvironment]
    
    @State private var agentService: AgentService
    @State private var userIntent: String = ""
    
    init(aiCoordinator: AICoordinator, networkManager: NetworkManager) {
        _agentService = State(initialValue: AgentService(ai: aiCoordinator, network: networkManager))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack {
                Label("API Intelligence Agent", systemImage: "brain.head.profile")
                    .font(.headline)
                
                Spacer()
                
                if agentService.isRunning {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 8)
                }
                
                // Close Button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close Console")
            }
            .padding()
            .background(.ultraThinMaterial)
            
            Divider()
            
            // MARK: - Terminal Logs
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if agentService.logs.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(agentService.logs, id: \.self) { log in
                                Text(log)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(logColor(for: log))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding()
                }
                .background(Color(nsColor: .windowBackgroundColor))
                .onChange(of: agentService.logs) {
                    withAnimation { proxy.scrollTo("bottom") }
                }
            }
            
            Divider()
            
            // MARK: - Input Area
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "terminal")
                        .foregroundStyle(.secondary)
                    
                    TextField("What should the agent do?", text: $userIntent)
                        .textFieldStyle(.plain)
                        .onSubmit(startAgent)
                        .disabled(agentService.isRunning)
                    
                    Button(action: startAgent) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            // Use Color(Color.blue) or cast to AnyShapeStyle to match .secondary
                            .foregroundStyle(userIntent.isEmpty || agentService.isRunning ? AnyShapeStyle(.secondary) : AnyShapeStyle(.blue))
                    }                    .buttonStyle(.plain)
                    .disabled(userIntent.isEmpty || agentService.isRunning)
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2))
                )
                
                HStack {
                    if let active = activeEnvs.first {
                        HStack(spacing: 4) {
                            Circle().fill(.green).frame(width: 8, height: 8)
                            Text("Active Env: **\(active.name)**")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                        Text("⚠️ No active environment selected")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    Spacer()
                    
                    Text("\(allRequests.count) requests available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .frame(minWidth: 550, minHeight: 450)
    }
    
    // MARK: - Helpers
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Ready for your instructions")
                .font(.headline)
            Text("Try: 'Run GetToken, save the token, then run SecureFetch.'")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private func logColor(for log: String) -> Color {
        if log.contains("❌") || log.contains("⚠️") { return .red }
        if log.contains("✅") { return .green }
        if log.contains("🚀") || log.contains("🔗") { return .blue }
        if log.contains("🤖") || log.contains("Planning") { return .purple }
        return .primary
    }
    
    private func startAgent() {
        guard !userIntent.isEmpty else { return }
        let intent = userIntent
        userIntent = ""
        
        Task {
            await agentService.run(
                goal: intent,
                requests: allRequests,
                environment: activeEnvs.first
            )
        }
    }
}
