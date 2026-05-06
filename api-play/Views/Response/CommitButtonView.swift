import SwiftUI
import SwiftData

/// A premium macOS-native button that handles the commit workflow.
/// It intelligently detects if changes have been made before allowing a new snapshot.
struct CommitButtonView: View {
    @Bindable var request: APIRequest
    
    // MARK: - State
    @State private var showCommitSheet = false
    @State private var showNoChangesAlert = false
    
    var body: some View {
        Button {
            handleCommitIntent()
        } label: {
            Label("Commit", systemImage: "arrow.up.circle.fill")
                .foregroundStyle(request.isDirty ? .primary : .secondary)
        }
        .help(request.isDirty ? "Save a snapshot of your current changes" : "No changes to commit")
        
        // MARK: - Alerts
        .alert("No Changes Detected", isPresented: $showNoChangesAlert) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Your current request state perfectly matches the most recent snapshot in history. Modify the URL, headers, or body to enable committing.")
        }
        
        // MARK: - Sheets
        .sheet(isPresented: $showCommitSheet) {
            CommitDialog(request: request)
        }
    }
    
    private func handleCommitIntent() {
        if request.isDirty {
            showCommitSheet = true
        } else {
            // Native macOS haptic/feedback or just the alert
            showNoChangesAlert = true
        }
    }
}

/// A clean, focused dialog for entering commit details.
struct CommitDialog: View {
    @Bindable var request: APIRequest
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var message: String = ""
    @State private var description: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Commit Changes")
                    .font(.headline)
                Text("Create a historical snapshot of this request's current state.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                TextField("Summary (e.g. Added auth headers)", text: $message)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(saveCommit)
                
                TextEditor(text: $description)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 80)
                    .padding(4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                    )
            }
            
            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Button("Create Snapshot") {
                    saveCommit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(message.isEmpty)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding(20)
        .frame(width: 400)
    }
    
    private func saveCommit() {
        guard !message.isEmpty else { return }
        
        let newCommit = RequestCommit(
            message: message,
            description: description,
            request: request
        )
        
        modelContext.insert(newCommit)
        try? modelContext.save()
        
        dismiss()
    }
}

#Preview {
    CommitButtonView(request: APIRequest(name: "Test Request"))
        .padding()
        .modelContainer(for: APIRequest.self, inMemory: true)
}
