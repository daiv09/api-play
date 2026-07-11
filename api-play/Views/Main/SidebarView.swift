import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import Vision

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AICoordinator.self) private var aiCoordinator
    @Environment(WebhookService.self) private var webhookService
    
    @Query(sort: \RequestFolder.order) private var folders: [RequestFolder]
    @Query(sort: \APIEnvironment.name) private var environments: [APIEnvironment]
    @Query(filter: #Predicate<APIRequest> { $0.folder == nil }, sort: \APIRequest.updatedAt, order: .reverse)
    private var rootRequests: [APIRequest]

    @Binding var selectedRequest: APIRequest?
    @Binding var selectedEnvironment: APIEnvironment?

    @State private var isAddingFolder = false
    @State private var isAddingEnv = false
    @State private var isEditingEnv = false
    @State private var newNameBuffer = ""
    @State private var searchText = ""
    @State private var renamingRequestID: UUID?
    @State private var isProcessingImage = false
    @State private var imageDropError: String?

    var body: some View {
        VStack(spacing: 0) {
            environmentHeader
            Divider()

            List(selection: $selectedRequest) {
                Spacer()
                Section("Collections") {
                    if topLevelFolders.isEmpty {
                        Text("No Collections").font(.caption).foregroundStyle(.tertiary)
                    } else {
                        ForEach(topLevelFolders) { folder in
                            FolderDisclosure(folder: folder, selectedRequest: $selectedRequest, renamingRequestID: $renamingRequestID)
                        }
                    }
                }

                Section("Requests") {
                    ForEach(filteredRootRequests) { request in
                        RequestRow(request: request, isSelected: selectedRequest?.id == request.id,
                                   isRenaming: renamingRequestID == request.id,
                                   onRenameComplete: { renamingRequestID = nil })
                            .tag(request)
                            .modifier(RequestContextMenu(request: request, renamingRequestID: $renamingRequestID, selectedRequest: $selectedRequest))
                            .draggable(request.id.uuidString)
                    }
                    .onDelete(perform: deleteRootRequests)
                }
                
                Section("Local Webhook Receiver") {
                    WebhookSidebarModule()
                }
            }
            .alert("Import Failed", isPresented: Binding(
                get: { imageDropError != nil },
                set: { if !$0 { imageDropError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(imageDropError ?? "")
            }
            .listStyle(.sidebar)
            .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in
                if handleImageDrop(providers: providers) { return true }
                if handleFileDrop(providers: providers) { return true }
                return false
            }
            .overlay {
                if isProcessingImage {
                    VStack {
                        ProgressView("Analyzing Image...")
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .searchable(text: $searchText, placement: .sidebar)
        .alert("New Folder", isPresented: $isAddingFolder) {
            TextField("Name", text: $newNameBuffer)
            Button("Create") { createFolder() }
            Button("Cancel", role: .cancel) { newNameBuffer = "" }
        }
        .alert("New Environment", isPresented: $isAddingEnv) {
            TextField("Name", text: $newNameBuffer)
            Button("Create") { createEnvironment() }
            Button("Cancel", role: .cancel) { newNameBuffer = "" }
        }
        .sheet(isPresented: $isEditingEnv) {
            if let env = selectedEnvironment {
                NavigationStack {
                    EnvironmentEditor(environment: env)
                        .toolbar { Button("Done") { isEditingEnv = false } }
                }.frame(minWidth: 500, minHeight: 400)
            }
        }
    }
    
    private var environmentHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Environment", systemImage: "server.rack")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if selectedEnvironment != nil {
                    Button {
                        isEditingEnv = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit Environment Properties")
                }
            }
            .frame(maxWidth: .infinity)
            
            Picker("", selection: $selectedEnvironment) {
                Text("Global").tag(Optional<APIEnvironment>.none)
                Divider()
                ForEach(environments) { Text($0.name).tag(Optional($0)) }
            }
            .labelsHidden()
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var topLevelFolders: [RequestFolder] { folders.filter { $0.parent == nil }.sorted { $0.order < $1.order } }
    private var filteredRootRequests: [APIRequest] { searchText.isEmpty ? rootRequests : rootRequests.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }

    private func addRequest(to folder: RequestFolder?) {
        let req = APIRequest(name: "New Request"); req.folder = folder
        modelContext.insert(req); selectedRequest = req
    }

    private func createFolder() {
        let folder = RequestFolder(name: newNameBuffer, order: folders.count)
        modelContext.insert(folder); newNameBuffer = ""
    }

    private func createEnvironment() {
        let env = APIEnvironment(name: newNameBuffer)
        modelContext.insert(env)
        selectedEnvironment = env
        for other in environments {
            other.isActive = (other.id == env.id)
        }
        newNameBuffer = ""
    }

    private func deleteRootRequests(at offsets: IndexSet) {
        offsets.map { rootRequests[$0] }.forEach { req in
            modelContext.delete(req)
        }
    }

    private func handleImageDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) else { return false }
        isProcessingImage = true
        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
            guard let data = data, let image = NSImage(data: data), let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                DispatchQueue.main.async { isProcessingImage = false }
                return
            }
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    DispatchQueue.main.async { isProcessingImage = false }
                    return
                }
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                Task {
                    defer { DispatchQueue.main.async { isProcessingImage = false } }
                    do {
                        let newReq = try await aiCoordinator.parseImageToRequest(text: text)
                        await MainActor.run {
                            modelContext.insert(newReq)
                            selectedRequest = newReq
                        }
                    } catch {
                        await MainActor.run {
                            imageDropError = "Couldn't import this image: \(error.localizedDescription)"
                        }
                    }
                }
            }
            try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        }
        return true
    }

    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            if url.pathExtension.lowercased() == "har" {
                DispatchQueue.main.async {
                    do {
                        let requests = try HARParser.parse(url: url)
                        let folderName = url.deletingPathExtension().lastPathComponent
                        let folder = RequestFolder(name: folderName, order: folders.count)
                        modelContext.insert(folder)
                        for req in requests {
                            req.folder = folder
                            modelContext.insert(req)
                        }
                    } catch {
                    }
                }
            }
        }
        return true
    }
}

// MARK: - Webhook Sidebar Module
struct WebhookSidebarModule: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WebhookService.self) private var webhookService
    @State private var isExpanded: Bool = true
    @State private var selectedPayloadForInspector: WebhookPayload?

    private var sortedPayloads: [WebhookPayload] {
        webhookService.payloads
            .sorted(by: { $0.timestamp > $1.timestamp })
            .prefix(15)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(webhookService.isListening ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(webhookService.isListening ? "Port \(webhookService.port)" : "Offline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(webhookService.isListening ? "Stop" : "Start") {
                    if webhookService.isListening {
                        webhookService.stopListening()
                    } else {
                        webhookService.startListening()
                    }
                }
                .buttonStyle(.plain)
                .font(.caption.bold())
                .foregroundStyle(webhookService.isListening ? .red : .blue)
            }
            .padding(.vertical, 4)
            .padding(.bottom, 2)

            if !webhookService.payloads.isEmpty {
                DisclosureGroup("Recent Incoming Hits (\(webhookService.payloads.count))", isExpanded: $isExpanded) {
                    VStack(spacing: 2) {
                        ForEach(sortedPayloads, id: \.id) { payload in
                            WebhookSidebarRow(payload: payload) {
                                selectedPayloadForInspector = payload
                            } onSaveAsRequest: {
                                convertWebhookToRequest(payload)
                            }
                        }
                        
                        Divider().padding(.vertical, 4)
                        
                        Button(action: { webhookService.clearPayloads() }) {
                            Label("Clear Live Payloads Log", systemImage: "trash")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .font(.caption)
            } else if webhookService.isListening {
                Text("Waiting for network requests...")
                    .font(.caption.italic())
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)
            }
        }
        .sheet(item: $selectedPayloadForInspector) { payload in
            WebhookPayloadInspectorView(payload: payload)
        }
    }

    private func convertWebhookToRequest(_ payload: WebhookPayload) {
        let mappedMethod = HTTPMethod(rawValue: payload.method.uppercased()) ?? .GET
        let newRequest = APIRequest(name: "Webhook: \(payload.path.isEmpty ? "/" : payload.path)")
        newRequest.urlString = payload.path
        newRequest.httpMethod = mappedMethod
        
        modelContext.insert(newRequest)
        try? modelContext.save()
    }
}

// MARK: - Webhook Sidebar Row
struct WebhookSidebarRow: View {
    let payload: WebhookPayload
    var onSelect: () -> Void
    var onSaveAsRequest: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 6) {
            Button(action: onSelect) {
                HStack(spacing: 6) {
                    Text(payload.method)
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(methodColor(payload.method))
                        .frame(width: 36, alignment: .leading)
                    
                    Text(payload.path.isEmpty ? "/" : payload.path)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            if isHovering {
                Button(action: onSaveAsRequest) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .help("Save to Requests List")
            } else {
                Text(payload.timestamp, style: .time)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            withAnimation(.easeIn(duration: 0.1)) {
                self.isHovering = hovering
            }
        }
    }
    
    private func methodColor(_ method: String) -> Color {
        switch method.uppercased() {
        case "GET": return .green
        case "POST": return .orange
        case "PUT": return .blue
        case "DELETE": return .red
        default: return .secondary
        }
    }
}

struct WebhookPayloadInspectorView: View {
    let payload: WebhookPayload
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Request Information") {
                    LabeledContent("HTTP Method", value: payload.method)
                    LabeledContent("Target Endpoint URL Path", value: payload.path)
                    LabeledContent("Received Timestamp", value: payload.timestamp.description)
                }
                
                if !payload.headers.isEmpty {
                    Section("HTTP Headers (\(payload.headers.count))") {
                        List {
                            ForEach(Array(payload.headers.keys.sorted()), id: \.self) { key in
                                HStack(alignment: .top) {
                                    Text(key)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Spacer(minLength: 20)
                                    Text(payload.headers[key] ?? "")
                                        .font(.system(size: 11, design: .monospaced))
                                        .multilineTextAlignment(.trailing)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .frame(minHeight: 120, maxHeight: 180)
                    }
                }
                
                Section("Payload Data Message Body Context") {
                    if !payload.body.isEmpty {
                        ScrollView(.vertical) {
                            Text(payload.body)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                        .frame(minHeight: 180, maxHeight: 300)
                    } else {
                        Text("No Body Content Payload Found (Empty Stream Request)")
                            .font(.caption.italic())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Webhook Inspector Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Dismiss Log View") { dismiss() }
                }
            }
            .frame(width: 480, height: 520)
        }
    }
}

// MARK: - Helper Views & Modifiers
struct RequestContextMenu: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    let request: APIRequest
    @Binding var renamingRequestID: UUID?
    @Binding var selectedRequest: APIRequest?

    private var isSelected: Bool {
        selectedRequest?.id == request.id
    }

    func body(content: Content) -> some View {
        content.contextMenu {
            Button {
                request.isFavorite.toggle()
                try? modelContext.save()
            } label: {
                Label {
                    Text(request.isFavorite ? "Unpin" : "Pin")
                } icon: {
                    Image(systemName: request.isFavorite ? "star.slash" : "star")
                }
            }
            
            Divider()
            
            Button { renamingRequestID = request.id } label: {
                Label("Rename", systemImage: "pencil")
            }
            
            Button { duplicateRequest() } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            
            Button { duplicateAsNewVersion() } label: {
                Label("Duplicate as New Version", systemImage: "plus.square.on.square")
            }
            
            Divider()
            
            Button(role: .destructive) {
                if isSelected { selectedRequest = nil }
                modelContext.delete(request)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func duplicateRequest() {
        let dup = APIRequest(name: "\(request.name) Copy")
        dup.urlString = request.urlString
        dup.httpMethod = request.httpMethod
        dup.folder = request.folder
        modelContext.insert(dup)
        selectedRequest = dup
    }
    
    private func duplicateAsNewVersion() {
        let dup = request.duplicateAsNewVersion()
        modelContext.insert(dup)
        selectedRequest = dup
    }
}

struct FolderDisclosure: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var folder: RequestFolder
    @Binding var selectedRequest: APIRequest?
    @Binding var renamingRequestID: UUID?

    var body: some View {
        DisclosureGroup {
            if let children = folder.children?.sorted(by: { $0.order < $1.order }) {
                ForEach(children) { child in
                    FolderDisclosure(folder: child, selectedRequest: $selectedRequest, renamingRequestID: $renamingRequestID)
                }
            }
            if let requests = folder.requests?.sorted(by: { $0.name < $1.name }) {
                ForEach(requests) { request in
                    RequestRow(request: request, isSelected: selectedRequest?.id == request.id,
                               isRenaming: renamingRequestID == request.id,
                               onRenameComplete: { renamingRequestID = nil })
                        .tag(request)
                        .modifier(RequestContextMenu(request: request, renamingRequestID: $renamingRequestID, selectedRequest: $selectedRequest))
                        .draggable(request.id.uuidString)
                }
            }
        } label: {
            Label(folder.name, systemImage: "folder")
                .dropDestination(for: String.self) { items, _ in handleDrop(items: items) }
        }
    }

    @discardableResult
    private func handleDrop(items: [String]) -> Bool {
        guard let idString = items.first, let uuid = UUID(uuidString: idString) else { return false }
        let descriptor = FetchDescriptor<APIRequest>(predicate: #Predicate { $0.id == uuid })
        if let request = try? modelContext.fetch(descriptor).first {
            withAnimation { request.folder = folder }; return true
        }
        return false
    }
}

// MARK: - REQUEST ROW
struct RequestRow: View {
    @Bindable var request: APIRequest
    var isSelected: Bool
    var isRenaming: Bool
    var onRenameComplete: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(request.httpMethod.rawValue)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .colorMultiply(isSelected ? .white : methodColor)
                .frame(width: 38, alignment: .leading)

            if isRenaming {
                TextField("", text: $request.name)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit { onRenameComplete() }
            } else {
                Text(request.name.isEmpty ? "Untitled Request" : request.name)
                    .lineLimit(1)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? .white : .primary)
                
                if let version = request.version, !version.isEmpty {
                    Text(version)
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isSelected ? .white.opacity(0.2) : .blue.opacity(0.1))
                        .foregroundStyle(isSelected ? .white : .blue)
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            if request.hasDrifted {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
            }
            
            if request.isFavorite {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .rotationEffect(.degrees(35))
                    .foregroundStyle(isSelected ? .white : .secondary.opacity(0.8))
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeOut(duration: 0.15), value: request.isFavorite)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onChange(of: isRenaming) { if $1 { isFocused = true } }
    }

    private var methodColor: Color {
        switch request.httpMethod {
        case .GET: return .green
        case .POST: return .orange
        case .PUT: return .blue
        case .DELETE: return .red
        default: return .secondary
        }
    }
}
