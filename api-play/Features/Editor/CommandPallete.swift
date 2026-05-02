import SwiftUI
import SwiftData

struct CommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \APIRequest.updatedAt, order: .reverse) private var requests: [APIRequest]
    
    @State private var searchText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    static let selectRequestNotification = Notification.Name("SelectRequestInMainView")
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                TextField("Search requests...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isTextFieldFocused)
                    .onSubmit { executeFirstResult() }
                
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            
            Divider()
            
            List {
                if searchText.isEmpty {
                    Section("Suggested Commands") {
                        CommandRow(title: "New REST Request", icon: "plus.circle", shortcut: "⌘N") {
                            createNewRequest(type: .rest)
                        }
                        CommandRow(title: "New GraphQL Request", icon: "atom", shortcut: "⌥⌘N") {
                            createNewRequest(type: .graphql)
                        }
                    }
                }
                
                if !filteredRequests.isEmpty {
                    Section(searchText.isEmpty ? "Recent Requests" : "Search Results") {
                        ForEach(filteredRequests) { request in
                            Button { selectRequest(request) } label: {
                                HStack(spacing: 10) {
                                    MethodTag(method: request.httpMethod.rawValue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(request.name.isEmpty ? "Untitled" : request.name).fontWeight(.medium)
                                        Text(request.urlString).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(CommandListButtonStyle())
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            
            HStack {
                ShortcutHint(text: "↑↓ Navigate")
                ShortcutHint(text: "↵ Select")
                Spacer()
            }
            .padding(12)
            .background(.ultraThinMaterial)
        }
        .frame(width: 550, height: 400)
        .onAppear { isTextFieldFocused = true }
    }
    
    private var filteredRequests: [APIRequest] {
        searchText.isEmpty ? Array(requests.prefix(6)) : requests.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.urlString.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func createNewRequest(type: RequestType) {
            // MATCHES YOUR MODEL: init(name: String)
            let newName = "New \(type == .rest ? "REST" : "GraphQL")"
            let newReq = APIRequest(name: newName)
            
            // Set additional properties after init
            newReq.requestType = type
            newReq.urlString = ""
            
            modelContext.insert(newReq)
            selectRequest(newReq)
        }
    
    private func selectRequest(_ request: APIRequest) {
        NotificationCenter.default.post(name: Self.selectRequestNotification, object: request)
        dismiss()
    }
    
    private func executeFirstResult() {
        if let first = filteredRequests.first { selectRequest(first) }
    }
}

// MARK: - Supporting Views & Styles

struct ShortcutHint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.1), lineWidth: 0.5))
    }
}

struct CommandListButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(configuration.isPressed ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
    }
}

struct CommandRow: View {
    let title: String
    let icon: String
    let shortcut: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text(shortcut)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct MethodTag: View {
    let method: String
    var body: some View {
        Text(method)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .frame(width: 45)
            .padding(.vertical, 2)
            .background(methodColor.opacity(0.15))
            .foregroundStyle(methodColor)
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(methodColor.opacity(0.3), lineWidth: 1))
    }
    
    private var methodColor: Color {
        switch method.uppercased() {
        case "GET": return .blue
        case "POST": return .green
        case "PUT": return .orange
        case "DELETE": return .red
        default: return .secondary
        }
    }
}
