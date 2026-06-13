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
            // MARK: - Header Toolbar
            HStack {
                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                Spacer()
                
                // Native macOS Actions
                HStack(spacing: 12) {
                    Button(action: { query = "" ; variables = "" }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .help("Clear Editor")
                    
                    Button(action: prettifyCurrentTab) {
                        Image(systemName: "wand.and.stars")
                        Text("Prettify")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(selectedTab != .variables && variables.isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial) // Liquid Glass Header
            
            Divider()

            // MARK: - Editor Area
            ZStack {
                if selectedTab == .query {
                    editorView(
                        placeholder: "# Write your GraphQL query here...",
                        text: $query,
                        icon: "square.stack.3d.up"
                    )
                } else {
                    editorView(
                        placeholder: "{\n  \"variable\": \"value\"\n}",
                        text: $variables,
                        icon: "curlybraces"
                    )
                }
            }
            .background(Color(nsColor: .textBackgroundColor)) // Native Editor Background
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Prettify Helpers
    private func prettifyCurrentTab() {
        if selectedTab == .query {
            query = prettifyQuery(query)
        } else {
            variables = prettifyVariables(variables)
        }
    }

    // Very simple GraphQL‑query indenter (brace‑aware)
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

    // JSON‑variables prettifier
    private func prettifyVariables(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: json,
                                                       options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else { return raw }
        return str
    }

    
    // MARK: - Native Styled Editor
    @ViewBuilder
    private func editorView(placeholder: String, text: Binding<String>, icon: String) -> some View {
        VStack(spacing: 0) {
            // Subtle line number / gutter simulation
            HStack(alignment: .top, spacing: 0) {
                
                // Content
                ZStack(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                    
                    TextEditor(text: text)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden) // Required for custom background
                        .padding(4)
                        // Enable macOS 26 Intelligence Writing Tools
                        .writingToolsBehavior(.complete)
                }
            }
            .padding(8)
            
            // Footer Info
            HStack {
                Label(selectedTab.rawValue, systemImage: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(text.wrappedValue.count) characters")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.thinMaterial)
        }
    }
}
