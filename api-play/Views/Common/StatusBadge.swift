import SwiftUI

struct StatusBadge: View {
    let method: HTTPMethod
    
    private var color: Color {
        switch method {
        case .GET: return .blue
        case .POST: return .green
        case .PUT: return .orange
        case .PATCH: return .yellow
        case .DELETE: return .red
        case .HEAD: return .purple
        case .OPTIONS: return .cyan
        }
    }
    
    var body: some View {
        Text(method.rawValue)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.15))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(0.3), lineWidth: 0.5)
            )
    }
}
