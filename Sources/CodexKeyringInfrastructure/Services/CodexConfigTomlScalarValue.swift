import Foundation

public enum CodexConfigTomlScalarValue: Equatable, Sendable {
    case string(String)
    case bool(Bool)

    var rendered: String {
        switch self {
        case .string(let s): return "\"\(Self.escape(s))\""
        case .bool(let b): return b ? "true" : "false"
        }
    }

    private static func escape(_ value: String) -> String {
        var out = ""
        out.reserveCapacity(value.count)
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04X", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out
    }
}

extension CodexConfigTomlEditor {
    public typealias ScalarValue = CodexConfigTomlScalarValue
}
