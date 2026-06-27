import SwiftUI
import SwiftData

struct CommitHistoryView: View {
    let request: APIRequest
    @Environment(\.modelContext) private var modelContext
    var onClose: () -> Void // Kept to prevent parent compilation errors
    
    // Unified navigation destination enum
    enum ActiveSheet: Identifiable {
        case detail(RequestCommit)
        case diff(RequestCommit)
        
        var id: String {
            switch self {
            case .detail(let commit): return "detail-\(commit.id)"
            case .diff(let commit): return "diff-\(commit.id)"
            }
        }
    }
    
    @State private var activeSheet: ActiveSheet?
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Sub-header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Request History")
                        .font(.headline)
                    Text("\(request.safeCommits.count) snapshots saved")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
            
            Divider()
            
            if request.safeCommits.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Snapshots of your requests will appear here after you commit changes.")
                )
            } else {
                // MARK: - Find this block inside your CommitHistoryView List structure
                List(request.safeCommits) { commit in
                    Button {
                        activeSheet = .detail(commit)
                    } label: {
                        CommitRow(commit: commit)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        // Your contextMenu buttons...
                        if !isIdentical(commit: commit, currentRequest: request) {
                            Button {
                                activeSheet = .diff(commit)
                            } label: {
                                Label("Compare with Current Draft", systemImage: "arrow.left.and.right.circle")
                            }
                            
                            Button {
                                restore(commit)
                            } label: {
                                Label("Restore this version", systemImage: "arrow.uturn.backward")
                            }
                            
                            Divider()
                        }
                        
                        Button(role: .destructive) {
                            modelContext.delete(commit)
                        } label: {
                            Label("Delete Snapshot", systemImage: "trash")
                        }
                    }
                    .focusable(false)
                    .focusEffectDisabled()
                    .listRowBackground(Color.clear)
                }
                .listStyle(.inset)
            }
        }
        // MARK: - Unified Sheet Presenter
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .detail(let commit):
                NavigationStack {
                    CommitDetailView(commit: commit, currentRequest: request)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { activeSheet = nil }
                            }
                            ToolbarItem(placement: .primaryAction) {
                                Button("Restore") {
                                    restore(commit)
                                    activeSheet = nil
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                }
                .frame(minWidth: 850, idealWidth: 950, minHeight: 450, idealHeight: 550)
                
            case .diff(let commit):
                DiffWindow(commit: commit, request: request)
            }
        }
    }
    
    // MARK: - Core Rebase Engine
    private func restore(_ commit: RequestCommit) {
        request.urlString = commit.url
        request.httpMethod = commit.method
        request.headers = commit.headers
        request.params = commit.params
        request.requestBody = commit.body
        
        // Truncate history forward from this snapshot point (deleting subsequent chronological snapshots)
        if let allCommits = request.commits {
            let newerCommits = allCommits.filter { $0.timestamp > commit.timestamp }
            for newer in newerCommits {
                modelContext.delete(newer)
            }
        }
        
        try? modelContext.save()
        
        // Execute network call natively immediately following recovery
        NotificationCenter.default.post(name: NSNotification.Name("RunActiveRequest"), object: request)
    }

    private func isIdentical(commit: RequestCommit, currentRequest: APIRequest) -> Bool {
        return commit.url == currentRequest.urlString &&
               commit.method == currentRequest.httpMethod &&
               commit.headers == currentRequest.headers &&
               commit.params == currentRequest.params &&
               commit.body == currentRequest.requestBody
    }
}

// MARK: - Row Component
struct CommitRow: View {
    let commit: RequestCommit
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(commit.commitMessage)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(commit.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 8) {
                    StatusBadge(method: commit.method)
                    
                    Text(commit.timestamp, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                
                if !commit.commitDescription.isEmpty {
                    Text(commit.commitDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        // Makes the entire row space clickable without forcing a system highlight style
        .contentShape(Rectangle())
    }
}

// MARK: - Master Detail Component
struct CommitDetailView: View {
    let commit: RequestCommit
    let currentRequest: APIRequest
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) { // Reduced spacing
                // Unified Header Section
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        StatusBadge(method: commit.method)
                        Text(commit.commitMessage)
                            .font(.headline) // More compact typography matching Diff windows
                            .fontWeight(.semibold)
                    }
                    Text("Committed on \(commit.timestamp.formatted(date: .long, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)
                
                Divider()
                
                // Content payload render engine
                CommitInspectorRenderContents(
                    method: commit.method,
                    url: commit.url,
                    headers: commit.headers,
                    params: commit.params,
                    bodyPayload: commit.body,
                    responseSnapshot: commit.response,
                    currentRequestId: currentRequest.id
                )
            }
            .padding(16) // Optimized padding to eliminate loose layout gaps
        }
        .background(Color(nsColor: .textBackgroundColor))
        // Matched exact frame constraints with the Diff Window logic
        .frame(minWidth: 850, idealWidth: 950, minHeight: 450, idealHeight: 550)
    }
}

// MARK: - Side-By-Side Advanced Diff Panel
struct DiffWindow: View {
    let commit: RequestCommit
    let request: APIRequest
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            HStack(alignment: .top, spacing: 0) {
                
                // Left Side: Previous Historical Baseline Version
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Fixed height header container maintains baseline alignment
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Historical Snapshot")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                            Text(commit.commitMessage)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        }
                        .frame(height: 38, alignment: .leading) // 💡 Unified header height boundary
                        .padding(.bottom, 4)
                        
                        Divider()
                        
                        CommitInspectorRenderContents(
                            method: commit.method,
                            url: commit.url,
                            headers: commit.headers,
                            params: commit.params,
                            bodyPayload: commit.body,
                            responseSnapshot: commit.response,
                            currentRequestId: request.id
                        )
                    }
                    .padding(16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                VerticalDivider()
                
                // Right Side: Current Real-Time Workspace Draft
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Symmetrical header container matching the left side's layout box exactly
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Workspace")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                            Text(request.isDirty ? "Uncommitted Changes" : "No Changes Detected")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(request.isDirty ? .orange : .primary)
                                .lineLimit(1)
                        }
                        .frame(height: 38, alignment: .leading) // 💡 Symmetrical unified header height boundary
                        .padding(.bottom, 4)
                        
                        Divider()
                        
                        CommitInspectorRenderContents(
                            method: request.httpMethod,
                            url: request.urlString,
                            headers: request.headers,
                            params: request.params,
                            bodyPayload: request.requestBody,
                            responseSnapshot: request.lastResponse,
                            currentRequestId: request.id
                        )
                    }
                    .padding(16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .navigationTitle("Compare Changes")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .frame(minWidth: 850, idealWidth: 950, minHeight: 450, idealHeight: 550)
        }
    }
}

// MARK: - Supporting Layout UI Divider Line
struct VerticalDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.4))
            .frame(width: 1)
            .edgesIgnoringSafeArea(.vertical)
    }
}

// MARK: - Unified Specification Render Core
struct CommitInspectorRenderContents: View {
    let method: HTTPMethod
    let url: String
    let headers: [KVPair]
    let params: [KVPair]
    let bodyPayload: String
    let responseSnapshot: APIResponse?
    let currentRequestId: UUID
    
    @State private var responseViewMode: ResponseViewMode = .json
    
    enum ResponseViewMode: String, CaseIterable {
        case json = "JSON"
        case raw = "Raw"
        case headers = "Headers"
        case preview = "Preview"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Endpoint Card
            VStack(alignment: .leading, spacing: 4) {
                Text("ENDPOINT")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    StatusBadge(method: method)
                    Text(url.isEmpty ? "No URL Specified" : url)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .textSelection(.enabled)
            }
            
            // MARK: - Metadata (Headers & Params)
            metadataSection(title: "HEADERS", pairs: headers)
            metadataSection(title: "QUERY PARAMETERS", pairs: params)
            
            // MARK: - Body Payload Section
            VStack(alignment: .leading, spacing: 4) {
                Text("BODY CONTENT")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                if bodyPayload.isEmpty {
                    Text("No Body Content")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .italic()
                        .padding(.vertical, 2)
                } else {
                    Text(bodyPayload)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                }
            }
            
            Divider()
            
            // MARK: - Response Snapshot Card
            VStack(alignment: .leading, spacing: 4) {
                Text("RESPONSE SNAPSHOT")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                if let response = responseSnapshot {
                    VStack(spacing: 0) {
                        // Panel Top Bar
                        HStack(spacing: 4) {
                            responseStatusLabel(code: response.statusCode)
                                .layoutPriority(1)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                Text("\(Int(response.elapsedSeconds * 1000))ms")
                                Text("•")
                                Text(formatSize(response.body.count))
                            }
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .layoutPriority(1)
                            
                            Spacer(minLength: 4)
                            
                            let modes = availableResponseViewModes(for: response)
                            Picker("", selection: $responseViewMode) {
                                ForEach(modes, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .controlSize(.mini)
                            .frame(maxWidth: 180)
                            .layoutPriority(0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(nsColor: .windowBackgroundColor))
                        
                        Divider()
                        
                        // Content Pane
                        Group {
                            switch responseViewMode {
                            case .json:
                                ScrollView {
                                    Text(response.body)
                                        .font(.system(size: 11, design: .monospaced))
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                }
                            case .raw:
                                TextEditor(text: .constant(response.body))
                                    .font(.system(size: 11, design: .monospaced))
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                            case .headers:
                                ScrollView {
                                    responseHeadersView(headers: response.headers)
                                        .padding(12)
                                }
                            case .preview:
                                responsePreviewView(response: response)
                            }
                        }
                        .frame(height: 260)
                        .background(Color(nsColor: .textBackgroundColor))
                    }
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                        Text("No response recorded for this snapshot layer.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                    .cornerRadius(6)
                }
            }
        }
        .onAppear {
            if let response = responseSnapshot {
                let modes = availableResponseViewModes(for: response)
                if !modes.contains(responseViewMode), let firstMode = modes.first {
                    responseViewMode = firstMode
                }
            }
        }
    }
    
    // MARK: - Layout Utilities
    @ViewBuilder
    private func metadataSection(title: String, pairs: [KVPair]) -> some View {
        let activePairs = pairs.filter { $0.isEnabled && !$0.key.isEmpty }
        if !activePairs.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 0) {
                    ForEach(activePairs.sorted(by: { $0.key < $1.key })) { pair in
                        HStack(alignment: .top, spacing: 16) {
                            Text(pair.key)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 130, alignment: .leading)
                            
                            Text(pair.value)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        
                        if pair.id != activePairs.sorted(by: { $0.key < $1.key }).last?.id {
                            Divider().opacity(0.5)
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }
    
    @ViewBuilder
    private func responseStatusLabel(code: Int) -> some View {
        let isSuccess = code < 400
        let color = isSuccess ? Color.green : Color.red
        
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(code) \(isSuccess ? "OK" : "Error")")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    private func formatSize(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
    
    private func responseHeadersView(headers: [String: String]) -> some View {
        VStack(spacing: 0) {
            let sortedKeys = headers.keys.sorted()
            ForEach(sortedKeys, id: \.self) { key in
                if let value = headers[key] {
                    HStack(alignment: .top, spacing: 16) {
                        Text(key)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 140, alignment: .leading)
                        
                        Text(value)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 6)
                    
                    if key != sortedKeys.last {
                        Divider().opacity(0.5)
                    }
                }
            }
        }
    }
    
    private func responsePreviewView(response: APIResponse) -> some View {
        WebView(
            htmlString: response.body,
            baseURL: URL(string: response.url),
            data: response.bodyData,
            mimeType: response.headers.first(where: { $0.key.lowercased() == "content-type" })?.value,
            requestId: currentRequestId
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func availableResponseViewModes(for response: APIResponse) -> [ResponseViewMode] {
        var modes: [ResponseViewMode] = []
        if response.isJSON { modes.append(.json) }
        if response.hasBody { modes.append(.raw) }
        if response.hasHeaders { modes.append(.headers) }
        if response.hasPreview { modes.append(.preview) }
        return modes
    }
}
