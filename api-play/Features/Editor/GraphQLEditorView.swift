import SwiftUI

struct GraphQLEditorView: View {
    @Binding var query: String
    @Binding var variables: String
    
    @State private var selectedTab: Tab = .query
    
    enum Tab: String, CaseIterable {
        case query = "Query"
        case variables = "Variables"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 🔹 1. FLAT HEADER NAVIGATION BAR (Exact Match to REST View)
            HStack(spacing: 20) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 4) {
                            Spacer()
                            Text(tab.rawValue)
                                .font(.body)
                                .fontWeight(selectedTab == tab ? .medium : .regular)
                                .foregroundStyle(selectedTab == tab ? Color.blue : .primary.opacity(0.7))
                            
                            // Fine indicator line at the bottom of the active tab layer
                            Rectangle()
                                .fill(selectedTab == tab ? Color.blue : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // 🔹 2. SECONDARY CONTEXT ROW (Matches heights of Content-Type/Auth toolbars)
            HStack {
                Text(selectedTab == .query ? "GraphQL Schema Operations" : "JSON Variable Workspace")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Unified Actions Container
                HStack(spacing: 12) {
                    Button(action: { query = ""; variables = "" }) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Clear Editor Pane")
                    
                    Button(action: prettifyCurrentTab) {
                        HStack(spacing: 4) {
                            Image(systemName: "wand.and.stars")
                            Text("Prettify")
                        }
                    }
                    .buttonStyle(.link)
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 34) // Identical row tracking constraint
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()

            // 🔹 3. CLEAN CANVAS TEXTAREA WORKSPACE
            ZStack {
                if selectedTab == .query {
                    editorWorkspace(
                        placeholder: "# Write your GraphQL query operation parameters here...",
                        text: $query,
                        icon: "square.stack.3d.up"
                    )
                } else {
                    editorWorkspace(
                        placeholder: "{\n  \"variable\": \"value\"\n}",
                        text: $variables,
                        icon: "curlybraces"
                    )
                }
            }
            .background(Color(nsColor: .textBackgroundColor)) // Symmetrical view windowing target
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Prettify Engine Core Orchestrators
    private func prettifyCurrentTab() {
        if selectedTab == .query {
            query = prettifyQuery(query)
        } else {
            variables = prettifyVariables(variables)
        }
    }

    private func prettifyQuery(_ raw: String) -> String {
        let lines = raw.components(separatedBy: .newlines)
        var result = ""
        var indent = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("}") || trimmed.hasPrefix("]") {
                indent = max(indent - 1, 0)
            }
            result += String(repeating: "  ", count: indent) + trimmed + "\n"
            if trimmed.hasSuffix("{") || trimmed.hasSuffix("[") || trimmed.hasSuffix("(") {
                indent += 1
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func prettifyVariables(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else { return raw }
        return str
    }

    // MARK: - Flat Structured Editor Layer (Unified Padding Specs)
    @ViewBuilder
    private func editorWorkspace(placeholder: String, text: Binding<String>, icon: String) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.4))
                        .padding(.top, 12) // Perfect baseline down offset matching BodyEditorView
                        .padding(.horizontal, 20)
                }
                
                TextEditor(text: text)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    .writingToolsBehavior(.complete)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Integrated Bottom Analytics Panel Footer
            HStack {
                Label(selectedTab.rawValue, systemImage: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(text.wrappedValue.count) characters")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
}
