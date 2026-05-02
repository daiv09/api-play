import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedRequest: APIRequest?
    @State private var selectedEnvironment: APIEnvironment?
    @State private var lastResponse: APIResponse?
    
    // Toggle for the Code Panel to prevent the permanent "gap"
    @State private var showCodeSnippet = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedRequest: $selectedRequest,
                        selectedEnvironment: $selectedEnvironment)
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            if let request = selectedRequest {
                // Use an HStack with spacing 0 to keep it tight
                HStack(spacing: 0) {
                    
                    // LEFT/MIDDLE: The Editor & Response (The Priority View)
                    VSplitView {
                        EditorView(request: request, environment: selectedEnvironment) { resp in
                            self.lastResponse = resp
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        ResponseView(response: lastResponse, requestId: request.id)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 200, maxHeight: .infinity)
                    }
                    // Forces the vertical stack to fill the entire width
                    .frame(maxWidth: .infinity)
                    
                    // THE DIVIDER
                    Divider()
                    
                    // RIGHT: The Code Snippet Side-Panel
                    CodeGenView(request: request)
                        // Use a fixed width to prevent the "stretching gap"
                        .frame(width: 320)
                        .id("codegen-\(request.id)")
                }
            } else {
                ContentUnavailableView("Select a Request", systemImage: "sidebar.left")
            }
        }   }
}
// MARK: - Preview
#Preview {
    ContentView()
        .modelContainer(for: [
            APIRequest.self,
            RequestFolder.self,
            APIEnvironment.self,
            EnvVar.self
        ], inMemory: true)
}
