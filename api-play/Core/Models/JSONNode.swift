import Foundation

// MARK: - JSONNode

/// A recursive data structure that models JSON values for use in a SwiftUI OutlineGroup.
indirect enum JSONNode: Identifiable {
    case object(key: String?, children: [JSONNode])
    case array(key: String?, children: [JSONNode])
    case string(key: String?, value: String)
    case number(key: String?, value: String)
    case bool(key: String?, value: Bool)
    case null(key: String?)

    /// Unique identifier required by the Identifiable protocol.
    /// Uses the key and a UUID fallback to ensure stability in the List view.
    var id: String {
        let prefix: String
        let keyPart: String
        
        switch self {
        case .object(let k, _): prefix = "obj"; keyPart = k ?? UUID().uuidString
        case .array(let k, _):  prefix = "arr"; keyPart = k ?? UUID().uuidString
        case .string(let k, _): prefix = "str"; keyPart = k ?? UUID().uuidString
        case .number(let k, _): prefix = "num"; keyPart = k ?? UUID().uuidString
        case .bool(let k, _):   prefix = "bool"; keyPart = k ?? UUID().uuidString
        case .null(let k):      prefix = "null"; keyPart = k ?? UUID().uuidString
        }
        
        return "\(prefix)-\(keyPart)"
    }

    /// The text displayed in the UI row.
    var label: String {
        switch self {
        case .object(let k, let c):
            let desc = "{ \(c.count) items }"
            return k.map { "\($0): \(desc)" } ?? desc
        case .array(let k, let c):
            let desc = "[ \(c.count) items ]"
            return k.map { "\($0): \(desc)" } ?? desc
        case .string(let k, let v):
            return k.map { "\($0): \"\(v)\"" } ?? "\"\(v)\""
        case .number(let k, let v):
            return k.map { "\($0): \(v)" } ?? v
        case .bool(let k, let v):
            return k.map { "\($0): \(v)" } ?? "\(v)"
        case .null(let k):
            return k.map { "\($0): null" } ?? "null"
        }
    }

    /// Returns the children if the node is a container (object or array).
    /// Used by SwiftUI's OutlineGroup for recursion.
    var children: [JSONNode]? {
        switch self {
        case .object(_, let c), .array(_, let c):
            return c.isEmpty ? nil : c
        default:
            return nil
        }
    }

    var isLeaf: Bool { children == nil }

    /// Categorizes the value for syntax highlighting in the UI.
    var valueType: ValueType {
        switch self {
        case .object, .array: return .container
        case .string:         return .stringValue
        case .number:         return .numberValue
        case .bool:           return .boolValue
        case .null:           return .nullValue
        }
    }

    enum ValueType {
        case container, stringValue, numberValue, boolValue, nullValue
    }
}

// MARK: - JSONParser

struct JSONParser {

    /// Parses a raw JSON string into a root JSONNode.
    /// Returns nil if the string is not valid JSON.
    static func parse(_ jsonString: String) -> JSONNode? {
        guard let data = jsonString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        else { return nil }
        
        return convert(value: object, key: nil)
    }

    /// Recursively converts Foundation JSON objects into JSONNode cases.
    private static func convert(value: Any, key: String?) -> JSONNode {
        switch value {
        case let dict as [String: Any]:
            let children = dict.sorted(by: { $0.key < $1.key })
                               .map { convert(value: $0.value, key: $0.key) }
            return .object(key: key, children: children)

        case let array as [Any]:
            let children = array.enumerated()
                                .map { convert(value: $0.element, key: "[\($0.offset)]") }
            return .array(key: key, children: children)

        case let str as String:
            return .string(key: key, value: str)

        case let num as NSNumber:
            // Correctly differentiate Booleans from Numbers in NSNumber
            if num === kCFBooleanTrue  { return .bool(key: key, value: true)  }
            if num === kCFBooleanFalse { return .bool(key: key, value: false) }
            return .number(key: key, value: num.stringValue)

        case is NSNull:
            return .null(key: key)

        default:
            // Fallback for unexpected types
            return .string(key: key, value: "\(value)")
        }
    }
}
