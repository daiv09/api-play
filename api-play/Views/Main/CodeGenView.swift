import SwiftUI

struct CodeGenView: View {
    let request: APIRequest
    
    @Environment(AICoordinator.self) private var ai
    
    @State private var selectedLang: CodeLang = .curl
    @State private var showCopySuccess = false
    @State private var swiftModelResult: String = ""
    @State private var isGeneratingSwiftModel = false

    enum CodeLang: String, CaseIterable {
        case curl = "cURL"
        case swift = "Swift"
        case python = "Python"
        case javascript = "JS"
        case swiftModel = "Models"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 🔹 1. ADAPTIVE HEADER CONTROL BAR
            headerSection
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(.ultraThinMaterial)

            Divider()
            
            // 🔹 2. CONDITIONAL AI MODEL ENGINE BAR
            if selectedLang == .swiftModel {
                swiftModelToolbar
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                Divider()
            }

            // 🔹 3. CODE EDITOR WORKSPACE VIEWPORT
            ZStack(alignment: .topTrailing) {
                ScrollView(.vertical) {
                    Text(displayContent())
                        .font(.system(.subheadline, design: .monospaced))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                        .padding(.leading, 20)
                        .padding(.trailing, 76) // Space for copy button
                        .textSelection(.enabled)
                }
                .scrollIndicators(.automatic)
                .background(Color(nsColor: .textBackgroundColor))
                
                copyButton
                    .padding(.top, 12)
                    .padding(.trailing, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()

            // 🔹 4. GLOBAL VIEWPORT FOOTER STATUS
            footerSection
                .padding(.horizontal, 16)
                .frame(height: 32)
                .background(.ultraThinMaterial)
        }
        .frame(minWidth: 550, minHeight: 450)
        // Fixed .onChange blocks to use the standard single-argument syntax
        .onChange(of: request.lastResponse) { newResponse in
            if newResponse != nil && selectedLang == .swiftModel {
                Task { await generateSwiftModels() }
            }
        }
        .onChange(of: selectedLang) { newLang in
            if newLang == .swiftModel && swiftModelResult.isEmpty && request.lastResponse != nil {
                Task { await generateSwiftModels() }
            }
        }
    }

    // MARK: - Subviews
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            Label("Code Snippet", systemImage: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.8))
                .lineLimit(1)
            
            Spacer(minLength: 16)
            
            Picker("", selection: $selectedLang) {
                ForEach(CodeLang.allCases, id: \.self) { lang in
                    Text(lang.rawValue).tag(lang)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.regular)
            .frame(width: 280)
        }
    }

    private var swiftModelToolbar: some View {
        HStack(spacing: 8) {
            if isGeneratingSwiftModel {
                ProgressView().controlSize(.small).scaleEffect(0.65)
                Text("Analyzing payload and generating models...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if request.lastResponse == nil {
                Text("⚠️ Send a network request first to auto-generate Swift models")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
            } else {
                Label("AI Auto-Generated Decodable Models", systemImage: "sparkles")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
            }
            Spacer()
        }
    }

    private var copyButton: some View {
        Button {
            copy(displayContent())
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                showCopySuccess = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showCopySuccess = false }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: showCopySuccess ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                if !showCopySuccess {
                    Text("Copy")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.separator, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var footerSection: some View {
        HStack {
            Label {
                Text(request.lastResponse != nil ? "Synced with Response" : "Draft (No Live Context)")
                    .font(.system(size: 10, weight: .medium))
            } icon: {
                Circle()
                    .fill(request.lastResponse != nil ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
            }
            
            Spacer()
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Core Execution Engine Logic

    private func displayContent() -> String {
        if selectedLang == .swiftModel {
            return swiftModelResult.isEmpty ? "// Swift Models will be generated here automatically when a response is received." : swiftModelResult
        }
        return generateCode()
    }

    private func generateCode() -> String {
        switch selectedLang {
        case .curl: return curl()
        case .swift: return swift()
        case .python: return python()
        case .javascript: return js()
        case .swiftModel: return ""
        }
    }

    private func getBodyPayload() -> String {
        if request.requestType == .graphql {
            let variablesStr = request.graphqlVariables.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "{}" : request.graphqlVariables
            return "{\"query\": \"\(escape(request.graphqlQuery))\", \"variables\": \(variablesStr)}"
        }
        return request.requestBody
    }

    private func curl() -> String {
        let method = request.requestType == .graphql ? "POST" : request.httpMethod.rawValue
        var cmd = "curl -X \(method) \"\(request.urlString)\""
        
        var standardHeaders = request.headers.filter { $0.isEnabled }
        if request.requestType == .graphql && !standardHeaders.contains(where: { $0.key.lowercased() == "content-type" }) {
            cmd += " \\\n  -H \"Content-Type: application/json\""
        }
        
        for h in standardHeaders {
            cmd += " \\\n  -H \"\(h.key): \(h.value)\""
        }
        
        let payload = getBodyPayload()
        if !payload.isEmpty {
            cmd += " \\\n  -d '\(payload)'"
        }
        return cmd
    }

    private func swift() -> String {
        let method = request.requestType == .graphql ? "POST" : request.httpMethod.rawValue
        let payload = getBodyPayload()
        
        var bodySnippet = ""
        if !payload.isEmpty {
            bodySnippet = """
            \nrequest.httpBody = \"\"\"
            \(payload)
            \"\"\".data(using: .utf8)
            """
        }
        
        return """
        import Foundation

        var request = URLRequest(url: URL(string: "\(request.urlString)")!)
        request.httpMethod = "\(method)"
        \(request.requestType == .graphql ? "request.setValue(\"application/json\", forHTTPHeaderField: \"Content-Type\")\n" : "")\(headersSwift())\(bodySnippet)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                print(String(data: data, encoding: .utf8) ?? "")
            }
        }
        task.resume()
        """
    }

    private func python() -> String {
        let method = request.requestType == .graphql ? "POST" : request.httpMethod.rawValue
        let payload = getBodyPayload()
        
        // 🛠️ FIX: Removed the invalid stray escape character sequence here
        var hMap = request.headers.filter { $0.isEnabled }.map { "    \"\($0.key)\": \"\($0.value)\"," }.joined(separator: "\n")
        if request.requestType == .graphql && !request.headers.contains(where: { $0.key.lowercased() == "content-type" }) {
            hMap = "    \"Content-Type\": \"application/json\",\n" + hMap
        }
        
        var dataArg = "data=None"
        if !payload.isEmpty {
            dataArg = "data=\"\"\"\(payload)\"\"\""
        }

        return """
        import requests

        url = "\(request.urlString)"
        headers = {
        \(hMap)
        }

        response = requests.request(
            "\(method)",
            url,
            headers=headers,
            \(dataArg)
        )

        print(response.text)
        """
    }

    private func js() -> String {
        let method = request.requestType == .graphql ? "POST" : request.httpMethod.rawValue
        let payload = getBodyPayload()
        
        var hMap = request.headers.filter { $0.isEnabled }.map { "        \"\($0.key)\": \"\($0.value)\"," }.joined(separator: "\n")
        if request.requestType == .graphql && !request.headers.contains(where: { $0.key.lowercased() == "content-type" }) {
            hMap = "        \"Content-Type\": \"application/json\",\n" + hMap
        }
        
        var bodyArg = "body: null"
        if !payload.isEmpty {
            bodyArg = "body: `\(payload)`"
        }

        return """
        fetch("\(request.urlString)", {
            method: "\(method)",
            headers: {
        \(hMap)
            },
            \(bodyArg)
        })
        .then(res => res.json())
        .then(console.log)
        .catch(console.error);
        """
    }

    // MARK: - String Extensions & Format Helpers

    private func headersSwift() -> String {
        request.headers.filter { $0.isEnabled }
            .map { "request.setValue(\"\($0.value)\", forHTTPHeaderField: \"\($0.key)\")" }
            .joined(separator: "\n")
    }

    private func generateSwiftModels() async {
        guard let response = request.lastResponse else { return }
        isGeneratingSwiftModel = true
        defer { isGeneratingSwiftModel = false }
        
        do {
            let code = try await ai.generateSwiftModel(from: response.body)
            swiftModelResult = code
        } catch {
            swiftModelResult = "// Error executing structural codegen task:\n// \(error.localizedDescription)"
        }
    }

    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
