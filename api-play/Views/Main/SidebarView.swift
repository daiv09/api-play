import SwiftUI
import SwiftData
import AppKit

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    
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

    var body: some View {
        VStack(spacing: 0) {
            environmentHeader
            Divider()

            List(selection: $selectedRequest) {
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
            }
            .listStyle(.sidebar)
        }
        .searchable(text: $searchText, placement: .sidebar)
        .toolbar { ToolbarItem { addButtonMenu } }
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

    // MARK: - Subviews & Logic
    private var environmentHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Environment", systemImage: "server.rack").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                Spacer()
                if selectedEnvironment != nil {
                    Button { isEditingEnv = true } label: { Image(systemName: "slider.horizontal.3") }.buttonStyle(.plain)
                }
            }
            Picker("", selection: $selectedEnvironment) {
                Text("Global").tag(Optional<APIEnvironment>.none)
                Divider()
                ForEach(environments) { Text($0.name).tag(Optional($0)) }
            }.labelsHidden().controlSize(.small)
        }.padding(12)
    }

    private var addButtonMenu: some View {
        Menu {
            Button { addRequest(to: nil) } label: { Label("New Request", systemImage: "doc.badge.plus") }
            Button { isAddingFolder = true } label: { Label("New Folder", systemImage: "folder.badge.plus") }
            Divider()
            Button { isAddingEnv = true } label: { Label("New Environment", systemImage: "globe.badge.chevron.backward") }
        } label: { Image(systemName: "plus") }
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
        modelContext.insert(env); newNameBuffer = ""
    }

    private func deleteRootRequests(at offsets: IndexSet) {
        offsets.map { rootRequests[$0] }.forEach { modelContext.delete($0) }
    }
}

// MARK: - Helper Views & Modifiers
struct RequestContextMenu: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    let request: APIRequest
    @Binding var renamingRequestID: UUID?
    @Binding var selectedRequest: APIRequest?

    func body(content: Content) -> some View {
        content.contextMenu {
            Button { request.isFavorite.toggle() } label: {
                Label(request.isFavorite ? "Unpin" : "Pin", systemImage: request.isFavorite ? "star.slash" : "star")
            }
            Divider()
            Button { renamingRequestID = request.id } label: { Label("Rename", systemImage: "pencil") }
            Button { duplicateRequest() } label: { Label("Duplicate", systemImage: "doc.on.doc") }
            Divider()
            Button(role: .destructive) {
                if selectedRequest?.id == request.id { selectedRequest = nil }
                modelContext.delete(request)
            } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func duplicateRequest() {
        let dup = APIRequest(name: "\(request.name) Copy")
        dup.urlString = request.urlString; dup.httpMethod = request.httpMethod; dup.folder = request.folder
        modelContext.insert(dup); selectedRequest = dup
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
            if let requests = folder.requests?.sorted(by: { $0.updatedAt > $1.updatedAt }) {
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

    private func handleDrop(items: [String]) -> Bool {
        guard let idString = items.first, let uuid = UUID(uuidString: idString) else { return false }
        let descriptor = FetchDescriptor<APIRequest>(predicate: #Predicate { $0.id == uuid })
        if let request = try? modelContext.fetch(descriptor).first {
            withAnimation { request.folder = folder }; return true
        }
        return false
    }
}

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
                .foregroundStyle(isSelected ? .white : methodColor)
                .frame(width: 38, alignment: .leading)

            if isRenaming {
                TextField("", text: $request.name).textFieldStyle(.plain).focused($isFocused).onSubmit { onRenameComplete() }
            } else {
                Text(request.name.isEmpty ? "Untitled Request" : request.name)
                    .lineLimit(1).font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            Spacer()
            if request.isFavorite { Image(systemName: "star.fill").font(.system(size: 8)).foregroundStyle(isSelected ? .white : .secondary) }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle()) // Ensures the whole row responds to right-click
        .onChange(of: isRenaming) { if $1 { isFocused = true } }
    }

    private var methodColor: Color {
        switch request.httpMethod {
        case .GET: return .green; case .POST: return .orange; case .PUT: return .blue; case .DELETE: return .red; default: return .secondary
        }
    }
}
