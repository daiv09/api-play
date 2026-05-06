import SwiftUI

struct RequestDiffView: View {
    let oldTitle: String
    let newTitle: String
    let oldContent: String
    let newContent: String
    
    @State private var diffLines: [DiffLine] = []
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(oldTitle).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                Text(newTitle).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(diffLines) { line in
                        HStack(spacing: 0) {
                            // Left side (Old/Removed)
                            ZStack(alignment: .leading) {
                                if line.type == .removed || line.type == .equal {
                                    Text(line.content)
                                        .font(.system(.body, design: .monospaced))
                                        .padding(.horizontal, 4)
                                        .background(line.type == .removed ? Color.red.opacity(0.2) : Color.clear)
                                } else {
                                    Color.gray.opacity(0.1) // Empty space for addition on the other side
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Divider()
                            
                            // Right side (New/Added)
                            ZStack(alignment: .leading) {
                                if line.type == .added || line.type == .equal {
                                    Text(line.content)
                                        .font(.system(.body, design: .monospaced))
                                        .padding(.horizontal, 4)
                                        .background(line.type == .added ? Color.green.opacity(0.2) : Color.clear)
                                } else {
                                    Color.gray.opacity(0.1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 20)
                        Divider()
                    }
                }
            }
        }
        .onAppear {
            computeDiff()
        }
    }
    
    private func computeDiff() {
        let oldPretty = DiffService.shared.prettifyForDiff(oldContent)
        let newPretty = DiffService.shared.prettifyForDiff(newContent)
        self.diffLines = DiffService.shared.computeDiff(old: oldPretty, new: newPretty)
    }
}
