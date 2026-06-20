import SwiftUI

struct CodeGenView: View {
    let request: APIRequest
    
    @Environment(AICoordinator.self) private var ai
    
    @State private var selectedLang: CodeLang = .curl
    @State private var schemaResult: String = ""
    @State private var isFetchingSchema = false
    @State private var showCopySuccess = false
    @State private var swiftModelResult: String = ""
    @State private var isGeneratingSwiftModel = false

    enum CodeLang: String, CaseIterable {
        case curl = "cURL", swift = "Swift", python = "Python", javascript = "JS", swiftModel = "Models"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 🔹 ADAPTIVE HEADER
            headerSection
                .padding(.horizontal, 12)
                .frame(height: 38, alignment: .center)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)

            Divider()

            // 🔥 GRAPHQL SCHEMA TOOLBAR
            if request.requestType == .graphql {
                graphqlToolbar
                Divider()
            }
            
            // 🔥 AI SWIFT MODEL TOOLBAR
            if selectedLang == .swiftModel {
                swiftModelToolbar
                Divider()
            }

            // 🔹 CODE DISPLAY AREA
            ZStack(alignment: .topTrailing) {
                ScrollView(.vertical) {
                    Text(displayContent())
                        .font(.system(.subheadline, design: .monospaced))
                        // This is the key: forces text to wrap instead of growing wider
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .padding(.trailing, 40) // Make room for the copy button
                        .textSelection(.enabled)
                }
                .background(Color(nsColor: .textBackgroundColor))
                
                copyButton
            }
            
            Divider()

            // 🔹 RESPONSIVE FOOTER
            footerSection
        }
        // Set a reasonable minimum width to prevent UI collapse
        .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: request.lastResponse) { _, newValue in
            if newValue != nil && selectedLang == .swiftModel {
                Task { await generateSwiftModels() }
            }
        }
        .onChange(of: selectedLang) { _, newValue in
            if newValue == .swiftModel && swiftModelResult.isEmpty && request.lastResponse != nil {
                Task { await generateSwiftModels() }
            }
        }
    }

    // MARK: - Subviews
    
    private var headerSection: some View {
        HStack {
            headerLabel
            Spacer(minLength: 20)
            languagePicker.frame(width: 220)
        }
    }

    private var headerLabel: some View {
        Label("Code Snippet", systemImage: "chevron.left.forwardslash.chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var languagePicker: some View {
        Picker("", selection: $selectedLang) {
            ForEach(CodeLang.allCases, id: \.self) { lang in
                Text(lang.rawValue).tag(lang)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
    }

    private var graphqlToolbar: some View {
        HStack {
            Button(action: { Task { await fetchSchema() } }) {
                Label(schemaResult.isEmpty ? "Introspect" : "Refresh",
                      systemImage: "network.badge.shield.half.filled")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isFetchingSchema)

            if isFetchingSchema {
                ProgressView().controlSize(.small).scaleEffect(0.7)
            }

            Spacer()
            
            if !schemaResult.isEmpty {
                Button("Clear") { schemaResult = "" }
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private var swiftModelToolbar: some View {
        HStack {
            if isGeneratingSwiftModel {
                ProgressView().controlSize(.small).scaleEffect(0.7)
                Text("Generating Swift Models...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if request.lastResponse == nil {
                Text("⚠️ Send request first to auto-generate models")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Label("AI Auto-Generated Models", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private var copyButton: some View {
        Button {
            copy(displayContent())
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showCopySuccess = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showCopySuccess = false }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: showCopySuccess ? "checkmark" : "doc.on.doc")
                if !showCopySuccess { Text("Copy").font(.system(size: 10, weight: .bold)) }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.separator, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .padding(12)
        .help("Copy code to clipboard")
    }

    private var footerSection: some View {
        HStack {
            Label {
                Text(request.lastResponse != nil ? "Live Sync" : "Draft")
                    .font(.system(size: 10, weight: .medium))
            } icon: {
                Circle()
                    .fill(request.lastResponse != nil ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
            }
            
            Spacer()
            
            Text(selectedLang.rawValue.uppercased())
                .font(.system(size: 9, weight: .black))
                .opacity(0.4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .foregroundStyle(.secondary)
    }

    // MARK: - Generation Logic

    private func displayContent() -> String {
        if selectedLang == .swiftModel {
            return swiftModelResult.isEmpty ? "// Swift Models will be generated here automatically when a response is received." : swiftModelResult
        }
        return schemaResult.isEmpty ? generateCode() : schemaResult
    }

    private func generateCode() -> String {
        switch selectedLang {
        case .curl: return curl()
        case .swift: return swift()
        case .python: return python()
        case .javascript: return js()
        case .swiftModel: return "" // Handled dynamically
        }
    }

    private func curl() -> String {
        if request.requestType == .graphql {
            return """
            curl -X POST "\(request.urlString)" \\
              -H "Content-Type: application/json" \\
              -d '{
                "query": "\(escape(request.graphqlQuery))",
                "variables": \(request.graphqlVariables.isEmpty ? "{}" : request.graphqlVariables)
              }'
            """
        }
        var cmd = "curl -X \(request.httpMethod.rawValue) \"\(request.urlString)\""
        for h in request.headers where h.isEnabled {
            cmd += " \\\n  -H \"\(h.key): \(h.value)\""
        }
        if !request.requestBody.isEmpty {
            cmd += " \\\n  -d '\(request.requestBody)'"
        }
        return cmd
    }

    private func swift() -> String {
        """
        import Foundation

        var request = URLRequest(url: URL(string: "\(request.urlString)")!)
        request.httpMethod = "\(request.httpMethod.rawValue)"
        \(headersSwift())

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                print(String(data: data, encoding: .utf8) ?? "")
            }
        }
        task.resume()
        """
    }

    private func python() -> String {
        """
        import requests
        import json

        url = "\(request.urlString)"
        headers = {
        \(headersPython())
        }

        response = requests.request(
            "\(request.httpMethod.rawValue)",
            url,
            headers=headers,
            data=\(request.requestBody.isEmpty ? "None" : "json.dumps(" + request.requestBody + ")")
        )

        print(response.text)
        """
    }

    private func js() -> String {
        """
        fetch("\(request.urlString)", {
            method: "\(request.httpMethod.rawValue)",
            headers: {
                "Content-Type": "application/json",
                \(headersJS())
            },
            body: \(request.requestBody.isEmpty ? "null" : "JSON.stringify(" + request.requestBody + ")")
        })
        .then(res => res.json())
        .then(console.log);
        """
    }

    // MARK: - Helpers

    private func headersSwift() -> String {
        request.headers.filter { $0.isEnabled }
            .map { "request.setValue(\"\($0.value)\", forHTTPHeaderField: \"\($0.key)\")" }
            .joined(separator: "\n")
    }

    private func headersPython() -> String {
        request.headers.filter { $0.isEnabled }
            .map { "    \"\($0.key)\": \"\($0.value)\"," }
            .joined(separator: "\n")
    }

    private func headersJS() -> String {
        request.headers.filter { $0.isEnabled }
            .map { "        \"\($0.key)\": \"\($0.value)\"," }
            .joined(separator: "\n")
    }

    private func fetchSchema() async {
        guard let url = URL(string: request.urlString) else { return }
        isFetchingSchema = true
        defer { isFetchingSchema = false }

        let introspectionQuery = "{ \"query\": \"{ __schema { types { name } } }\" }"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = introspectionQuery.data(using: .utf8)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
                schemaResult = String(data: prettyData, encoding: .utf8) ?? "Schema empty"
            }
        } catch {
            schemaResult = "Error: \(error.localizedDescription)"
        }
    }

    private func generateSwiftModels() async {
        guard let response = request.lastResponse else { return }
        isGeneratingSwiftModel = true
        defer { isGeneratingSwiftModel = false }
        
        do {
            let code = try await ai.generateSwiftModel(from: response.body)
            swiftModelResult = code
        } catch {
            swiftModelResult = "// Error generating models: \(error.localizedDescription)"
        }
    }

    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
