import SwiftUI
import SwiftData

struct AgentConsoleView: View {
    // MARK: - Properties
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var allRequests: [APIRequest]
    var activeEnvironment: APIEnvironment?
    var activeRequest: APIRequest?
    
    @State private var agentService: AgentService
    @State private var userIntent: String = ""
    
    init(aiCoordinator: AICoordinator, networkManager: NetworkManager, environment: APIEnvironment?, activeRequest: APIRequest? = nil) {
        _agentService = State(initialValue: AgentService(ai: aiCoordinator, network: networkManager))
        self.activeEnvironment = environment
        self.activeRequest = activeRequest
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header Window Bar
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("API Agent")
                        .font(.system(size: 13, weight: .bold))
                }
                
                Spacer()
                
                if agentService.isRunning {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                        .padding(.trailing, 4)
                }
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close Console")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            
            Divider()
            
            // MARK: - Horizontal Execution Summary Pipeline
            if !agentService.steps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("AGENT EXECUTION PLAN")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(agentService.steps.enumerated()), id: \.element.id) { index, step in
                                HStack(spacing: 6) {
                                    miniStatusIcon(for: step.status)
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(step.requestName)
                                            .font(.system(size: 11, weight: .semibold))
                                        
                                        if let key = step.extractionKey {
                                            Text("🔗 save \(key)")
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(statusColor(for: step.status).opacity(0.3), lineWidth: 1)
                                )
                                
                                if index < agentService.steps.count - 1 {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.secondary.opacity(0.4))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.15))
                
                Divider()
            }
            
            // MARK: - Structured Execution Timeline List
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if agentService.steps.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(agentService.steps) { step in
                                TimelineStepRow(step: step)
                                    .id(step.id)
                            }
                        }
                        Color.clear.frame(height: 1).id("bottomAnchor")
                    }
                    .padding(16)
                }
                .background(Color(nsColor: .windowBackgroundColor))
                .onChange(of: agentService.steps.count) { _, _ in
                    if let lastStep = agentService.steps.last {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(lastStep.id, anchor: .bottom)
                        }
                    }
                }
                // Also trigger scroll when the status of the final step modifies elements
                .onChange(of: agentService.steps.last?.status) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottomAnchor", anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            // MARK: - Input Command Control Section
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    
                    TextField("What should the agent do?", text: $userIntent)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .onSubmit(startAgent)
                        .disabled(agentService.isRunning)
                    
                    Spacer()
                    
                    Button(action: startAgent) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(userIntent.isEmpty || agentService.isRunning ? Color.secondary.opacity(0.3) : Color.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(userIntent.isEmpty || agentService.isRunning)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
                
                // Footer System Metadata Indicators
                HStack {
                    if let active = activeEnvironment {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(.green)
                                .frame(width: 7, height: 7)
                            Text("Active Env:")
                                .foregroundStyle(.secondary)
                            Text(active.name)
                                .fontWeight(.bold)
                        }
                        .font(.system(size: 11))
                    } else {
                        HStack(spacing: 5) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text("No active environment selected")
                                .foregroundStyle(.red)
                        }
                        .font(.system(size: 11))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "tray.full.fill")
                        Text("\(allRequests.count) routes synchronized")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 2)
            }
            .padding(14)
            .background(.ultraThinMaterial)
        }
        .frame(minWidth: 580, minHeight: 480)
    }
    
    // MARK: - Actions
    private func startAgent() {
        guard !userIntent.isEmpty else { return }
        let intent = userIntent
        userIntent = ""
        
        Task {
            await agentService.run(
                goal: intent,
                requests: allRequests,
                environment: activeEnvironment,
                activeRequest: activeRequest,
                modelContext: modelContext
            )
        }
    }
    
    // MARK: - Context Color & Icon Mapping Helpers
    private func statusColor(for status: AgentStep.StepStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .running: return .orange
        case .success: return .green
        case .failed: return .red
        }
    }
    
    @ViewBuilder
    private func miniStatusIcon(for status: AgentStep.StepStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        case .running:
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.55)
                .frame(width: 10, height: 10)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.blue)
                .padding(.bottom, 4)
            Text("Autonomous Agent Workspace")
                .font(.system(size: 14, weight: .semibold))
            Text("Instruct the agent to execute routines, query environments, or auto-mutate sequential request pipelines.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}

// MARK: - Native Timeline Row Component
struct TimelineStepRow: View {
    let step: AgentStep
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon Badge Indicator
            ZStack {
                Circle()
                    .fill(rowColor.opacity(0.09))
                    .frame(width: 28, height: 28)
                
                Image(systemName: statusSymbolName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(rowColor)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center) {
                    Text(step.requestName)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(statusLabelString.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(rowColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(rowColor.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                // Secondary details line
                HStack(spacing: 4) {
                    Image(systemName: step.extractionKey != nil ? "link.circle.fill" : "gearshape.fill")
                        .font(.system(size: 11))
                    
                    if let key = step.extractionKey {
                        Text("Auto-extracting response payload parameter into key: `\(key)`")
                    } else {
                        Text("Executing dynamic route mutation phase within sandbox container.")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                
                // Contextual Inline Warning/Error Details
                if step.status == .failed, let failureDetails = step.failureReason {
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .font(.system(size: 11))
                            .padding(.top, 1)
                        Text(failureDetails)
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.05))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.red.opacity(0.15), lineWidth: 0.5)
                    )
                    .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
    
    // MARK: - Row Helpers
    private var rowColor: Color {
        switch step.status {
        case .pending: return .secondary
        case .running: return .orange
        case .success: return .green
        case .failed: return .red
        }
    }
    
    private var statusSymbolName: String {
        switch step.status {
        case .pending: return "ellipsis"
        case .running: return "arrow.triangle.2.circlepath"
        case .success: return "checkmark"
        case .failed: return "xmark"
        }
    }
    
    private var statusLabelString: String {
        switch step.status {
        case .pending: return "Queued"
        case .running: return "Running"
        case .success: return "Completed"
        case .failed: return "Failed"
        }
    }
}
