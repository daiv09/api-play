import SwiftUI

struct EnvironmentEditor: View {
    @Bindable var environment: APIEnvironment
    
    var body: some View {
        VStack {
            TextField("Environment Name", text: $environment.name)
                .font(.title2)
                .textFieldStyle(.plain)
            
            // Reusing your KVPairEditor logic, adapted for EnvVar
            ScrollView {
                ForEach($environment.variables) { $v in
                    HStack {
                        TextField("Key", text: $v.key)
                        TextField("Value", text: $v.value)
                        Button(action: { /* remove logic */ }) {
                            Image(systemName: "xmark.circle")
                        }
                    }
                }
                Button("Add Variable") {
                    environment.variables.append(EnvVar(key: "", value: ""))
                }
            }
        }
        .padding()
    }
}
