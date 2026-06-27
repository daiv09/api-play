import SwiftUI
import SwiftData

struct EnvironmentEditor: View {
    @Bindable var environment: APIEnvironment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection
            
            Divider()
            
            variableListHeader
            
            ScrollView {
                VStack(spacing: 8) {
                    // Use the array directly; the subview will handle the binding
                    ForEach(environment.variables) { variable in
                        EnvVarRow(variable: variable) {
                            removeVariable(variable)
                        }
                    }
                    
                    if environment.variables.isEmpty {
                        ContentUnavailableView(
                            "No Variables",
                            systemImage: "bolt.fill",
                            description: Text("Add variables to use them in your requests as {{key}}")
                        )
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center) // 👈 Completely centers it across the available viewport area
                        .listRowBackground(Color.clear) // 👈 Optional: Hides list backgrounds if this view lives inside a List section
                    }
                }
            }
            
            Button(action: addVariable) {
                Label("Add Variable", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding()
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(alignment: .leading) {
            Text("Environment Settings")
                .font(.caption)
                .foregroundStyle(.secondary)
                .bold()
            
            TextField("Environment Name", text: $environment.name)
                .font(.title2)
                .bold()
                .textFieldStyle(.plain)
        }
    }
    
    private var variableListHeader: some View {
        HStack {
            Text("Variables")
                .font(.headline)
            Spacer()
            Toggle("Active", isOn: $environment.isActive)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
    
    // MARK: - Actions
    
    private func addVariable() {
        withAnimation {
            let newVar = EnvVar(key: "", value: "", isEnabled: true)
            newVar.environment = environment
            environment.variables.append(newVar)
        }
    }
    
    private func removeVariable(_ variable: EnvVar) {
        withAnimation {
            environment.variables.removeAll { $0.id == variable.id }
        }
    }
}

/// Helper Row View to handle individual Bindings for EnvVar models
struct EnvVarRow: View {
    @Bindable var variable: EnvVar
    var onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $variable.isEnabled)
                .toggleStyle(.checkbox)
                .labelsHidden()
            
            TextField("Key", text: $variable.key)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            
            Group {
                if variable.isSensitive {
                    SecureField("Value", text: $variable.value)
                } else {
                    TextField("Value", text: $variable.value)
                }
            }
            .textFieldStyle(.roundedBorder)
            
            Button(action: { variable.isSensitive.toggle() }) {
                Image(systemName: variable.isSensitive ? "eye.slash" : "eye")
                    .foregroundStyle(variable.isSensitive ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .help(variable.isSensitive ? "Show Value" : "Hide Value")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
