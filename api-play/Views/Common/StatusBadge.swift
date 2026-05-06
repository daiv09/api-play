import SwiftUI

struct StatusBadge: View {
    let method: HTTPMethod
    
    var body: some View {
        Text(method.rawValue.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(methodColor)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(methodColor.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(methodColor.opacity(0.2), lineWidth: 1)
            )
            // Ensures the badge doesn't stretch weirdly in List rows or Grids
            .fixedSize()
    }
    
    private var methodColor: Color {
        switch method {
        case .GET:
            return .blue
        case .POST:
            return .green
        case .PUT:
            return .orange
        case .PATCH:
            return .yellow
        case .DELETE:
            return .red
        case .HEAD:
            return .purple
        case .OPTIONS:
            return .cyan
        }
    }
}

// MARK: - Preview for Development
#Preview {
    VStack(spacing: 10) {
        ForEach(HTTPMethod.allCases, id: \.self) { method in
            StatusBadge(method: method)
        }
    }
    .padding()
}
