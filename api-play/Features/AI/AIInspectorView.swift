import SwiftUI

struct AIInspectorView: View {
    @Bindable var ai: AICoordinator
    let bodyText: String
    
    // Track if this instance was opened specifically for Vision
    var isVisionMode: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Apple Intelligence", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                if ai.isAnalyzing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.bottom, 4)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if ai.isAnalyzing {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(isVisionMode ? "Analyzing visual snapshot..." : "Analyzing response structure...")
                                .italic()
                                .foregroundStyle(.secondary)
                            ProgressView()
                                .progressViewStyle(.linear)
                        }
                        .padding(.top)
                    } else if !ai.analysisResult.isEmpty {
                        // Markdown rendering via LocalizedStringKey
                        Text(LocalizedStringKey(ai.analysisResult))
                            .textSelection(.enabled)
                            .lineSpacing(4)
                            .animation(.easeIn, value: ai.analysisResult)
                    } else {
                        Text("No analysis available.")
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .onAppear {
            // Only trigger the JSON analysis if we aren't in Vision mode
            // and no analysis has been performed yet.
            if !isVisionMode && ai.analysisResult.isEmpty && !ai.isAnalyzing {
                Task {
                    await ai.explainResponse(bodyText)
                }
            }
        }
    }
}
