import SwiftUI
import SwiftData

struct CommitHistoryView: View {
    let request: APIRequest
    @Environment(\.modelContext) private var modelContext
    var onClose: () -> Void // Left here to prevent parent compilation errors
    
    @State private var selectedCommit: RequestCommit?
    @State private var isShowingDiff = false
    
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
                
                // Close button has been removed from here
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
                List(request.safeCommits) { commit in
                    CommitRow(commit: commit)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCommit = commit
                        }
                        .contextMenu {
                            Button {
                                selectedCommit = commit
                                isShowingDiff = true
                            } label: {
                                Label("Compare with Current Draft", systemImage: "arrow.left.and.right.circle")
                            }
                            
                            Button {
                                restore(commit)
                            } label: {
                                Label("Restore this version", systemImage: "arrow.uturn.backward")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(commit)
                            } label: {
                                Label("Delete Snapshot", systemImage: "trash")
                            }
                        }
                }
                .listStyle(.inset)
            }
        }
        // MARK: - Detail Sheet
        .sheet(item: $selectedCommit) { commit in
            NavigationStack {
                CommitDetailView(commit: commit, currentRequest: request)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Restore") {
                                restore(commit)
                                selectedCommit = nil
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
            }
            .frame(minWidth: 500, minHeight: 600)
        }
        // MARK: - Diff Sheet
        .sheet(isPresented: $isShowingDiff) {
            if let commit = selectedCommit {
                DiffWindow(commit: commit, request: request)
            }
        }
    }
    
    private func restore(_ commit: RequestCommit) {
        request.urlString = commit.url
        request.httpMethod = commit.method
        request.headers = commit.headers
        request.params = commit.params
        request.requestBody = commit.body
        try? modelContext.save()
    }
}

// MARK: - Components

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
        .padding(.vertical, 4)
    }
}

struct CommitDetailView: View {
    let commit: RequestCommit
    let currentRequest: APIRequest
    
    @State private var responseViewMode: ResponseViewMode = .json
    
    enum ResponseViewMode: String, CaseIterable {
        case json = "JSON"
        case raw = "Raw"
        case headers = "Headers"
        case preview = "Preview"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        StatusBadge(method: commit.method)
                        Text(commit.commitMessage)
                            .font(.title2).bold()
                    }
                    Text("Committed on \(commit.timestamp.formatted(date: .long, time: .shortened))")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Technical Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Endpoint").font(.headline)
                    Text(commit.url)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                        .textSelection(.enabled)
                }
                
                metadataSection(title: "Headers", pairs: commit.headers)
                metadataSection(title: "Query Parameters", pairs: commit.params)
                
                // Payload Preview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Body Content").font(.headline)
                    if commit.body.isEmpty {
                        Text("No Body Content")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .italic()
                    } else {
                        Text(commit.body)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .textSelection(.enabled)
                    }
                }
                
                Divider()
                
                // Response Snapshot Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Response Snapshot").font(.headline)
                    
                    if let response = commit.response {
                        // Response details: status code, elapsed time, and size (Responsive layout)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                responseStatusLabel(code: response.statusCode)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10))
                                    Text("\(Int(response.elapsedSeconds * 1000))ms")
                                    Text("•")
                                    Text(formatSize(response.body.count))
                                }
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                            }
                            
                            let modes = availableResponseViewModes(for: response)
                            Picker("", selection: $responseViewMode) {
                                ForEach(modes, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.bottom, 4)
                        
                        // Content card
                        VStack(spacing: 0) {
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
                                    .padding(6)
                            case .headers:
                                ScrollView {
                                    responseHeadersView(headers: response.headers)
                                        .padding(8)
                                }
                            case .preview:
                                responsePreviewView(response: response)
                            }
                        }
                        .frame(height: 300)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                        )
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.secondary)
                            Text("No Response snapshot recorded.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                        .cornerRadius(6)
                    }
                }
            }
            .padding(24)
        }
        .onAppear {
            if let response = commit.response {
                let modes = availableResponseViewModes(for: response)
                if !modes.contains(responseViewMode), let firstMode = modes.first {
                    responseViewMode = firstMode
                }
            }
        }
    }
    
    @ViewBuilder
    private func metadataSection(title: String, pairs: [KVPair]) -> some View {
        let activePairs = pairs.filter { $0.isEnabled && !$0.key.isEmpty }
        if !activePairs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                VStack(spacing: 0) {
                    ForEach(activePairs.sorted(by: { $0.key < $1.key })) { pair in
                        HStack(alignment: .top) {
                            Text(pair.key)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 140, alignment: .leading)
                            
                            Text(pair.value)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        
                        if pair.id != activePairs.sorted(by: { $0.key < $1.key }).last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 0.5))
            }
        }
    }
    
    @ViewBuilder
    private func responseStatusLabel(code: Int) -> some View {
        let (color, label) = (code < 400 ? Color.green : Color.red, code < 400 ? "OK" : "Error")
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(code) \(label)").font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(color).padding(.horizontal, 8).padding(.vertical, 3)
        .background(color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private func formatSize(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
    
    private func responseHeadersView(headers: [String: String]) -> some View {
        VStack(spacing: 0) {
            let sortedKeys = headers.keys.sorted()
            ForEach(sortedKeys, id: \.self) { key in
                if let value = headers[key] {
                    HStack(alignment: .top) {
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
                    .padding(.horizontal, 8)
                    
                    if key != sortedKeys.last {
                        Divider()
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 0.5))
    }
    
    private func responsePreviewView(response: APIResponse) -> some View {
        WebView(
            htmlString: response.body,
            baseURL: URL(string: response.url),
            data: response.bodyData,
            mimeType: response.headers.first(where: { $0.key.lowercased() == "content-type" })?.value,
            requestId: currentRequest.id
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func availableResponseViewModes(for response: APIResponse) -> [ResponseViewMode] {
        var modes: [ResponseViewMode] = []
        if response.isJSON {
            modes.append(.json)
        }
        if response.hasBody {
            modes.append(.raw)
        }
        if response.hasHeaders {
            modes.append(.headers)
        }
        if response.hasPreview {
            modes.append(.preview)
        }
        return modes
    }
}

struct DiffWindow: View {
    let commit: RequestCommit
    let request: APIRequest
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            RequestDiffView(
                oldTitle: "Version: \(commit.commitMessage)",
                newTitle: "Current Draft",
                oldContent: commit.body,
                newContent: request.requestBody
            )
            .navigationTitle("Compare Changes")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .frame(width: 900, height: 600)
        }
    }
}
