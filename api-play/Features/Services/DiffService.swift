import Foundation
import SwiftUI

enum DiffType {
    case added
    case removed
    case equal
}

struct DiffLine: Identifiable {
    let id = UUID()
    let content: String
    let type: DiffType
    let lineNumber: Int? // Optional: for showing line numbers in UI
}

class DiffService {
    static let shared = DiffService()
    
    /// Compares two strings and returns a list of DiffLine objects
    func computeDiff(old: String, new: String) -> [DiffLine] {
        let oldLines = old.components(separatedBy: .newlines)
        let newLines = new.components(separatedBy: .newlines)
        
        // Using Apple's built-in CollectionDifference (available iOS 13+ / macOS 10.15+)
        let difference = newLines.difference(from: oldLines)
        
        var result: [DiffLine] = []
        
        // We first populate with the "Old" state
        for (index, line) in oldLines.enumerated() {
            result.append(DiffLine(content: line, type: .equal, lineNumber: index + 1))
        }
        
        // Then we apply the changes to identify additions and removals
        for change in difference {
            switch change {
            case .remove(let offset, _, _):
                // Mark the line as removed
                let line = result[offset]
                result[offset] = DiffLine(content: line.content, type: .removed, lineNumber: line.lineNumber)
                
            case .insert(let offset, let element, _):
                // Insert the new line and mark as added
                result.insert(DiffLine(content: element, type: .added, lineNumber: nil), at: offset)
            }
        }
        
        return result
    }
    
    /// Helper to prettify JSON before diffing to ensure the comparison is meaningful
    func prettifyForDiff(_ jsonString: String) -> String {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) else {
            return jsonString
        }
        return String(data: prettyData, encoding: .utf8) ?? jsonString
    }
}
