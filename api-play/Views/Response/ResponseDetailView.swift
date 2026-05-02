import SwiftUI
import SwiftData

struct ResponseDetailView: View {
    let requestId: UUID
    @State private var searchText = ""
    @State private var aiCoordinator = AICoordinator()
    @State private var isShowingAI = false
    
    // Query filtered by the specific request ID
    @Query private var requests: [APIRequest]
    
    private var request: APIRequest? {
        requests.first { $0.id == requestId }
    }

    init(requestId: UUID) {
        self.requestId = requestId
        
        // Use the UUID directly in the predicate for performance and stability
        let filter = #Predicate<APIRequest> { request in
            request.id == requestId
        }
        _requests = Query(filter: filter)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let request = request {
                searchHeader
                
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading) {
                        // Display the request body with search highlighting
                        Text(formatAndHighlight(request.requestBody))
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
                
                // Sidebar Inspector for Apple Intelligence
                .inspector(isPresented: $isShowingAI) {
                    AIInspectorView(ai: aiCoordinator, bodyText: request.requestBody)
                        .inspectorColumnWidth(min: 250, ideal: 300, max: 450)
                        .toolbar {
                            Button {
                                isShowingAI.toggle()
                            } label: {
                                Label("Close AI", systemImage: "xmark.circle")
                            }
                        }
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isShowingAI.toggle()
                        } label: {
                            Label("Ask Apple Intelligence", systemImage: "sparkles")
                        }
                        .help("Explain this response using AI")
                    }
                }
            } else {
                ContentUnavailableView("Request Not Found", systemImage: "exclamationmark.magnifyingglass")
            }
        }
    }

    // MARK: - Search Header
    
    private var searchHeader: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search response body...", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding()
    }

    // MARK: - Search Highlighting Logic
    
    /// Formats the input text and highlights occurrences of the search text
    private func formatAndHighlight(_ input: String) -> AttributedString {
        var attr = AttributedString(input)
        
        guard !searchText.isEmpty else { return attr }
        
        let lowerInput = input.lowercased()
        let lowerSearch = searchText.lowercased()
        var searchStart = lowerInput.startIndex
        
        while let range = lowerInput.range(of: lowerSearch, range: searchStart..<lowerInput.endIndex) {
            // Map String.Index range to AttributedString.Index range
            if let start = AttributedString.Index(range.lowerBound, within: attr),
               let end = AttributedString.Index(range.upperBound, within: attr) {
                
                // Applying highlight styles
                attr[start..<end].backgroundColor = .yellow.opacity(0.3)
                attr[start..<end].foregroundColor = .primary // Keeps text readable in Dark/Light mode
                attr[start..<end].inlinePresentationIntent = .emphasized
                
                searchStart = range.upperBound
            } else {
                break
            }
        }
        
        return attr
    }
}
