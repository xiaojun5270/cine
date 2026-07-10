import Foundation

/// A fully dynamic JSON value.
///
/// The CineChill server exposes 305 endpoints but declares almost no response
/// schemas in its OpenAPI document, so the client cannot rely on fixed models
/// for most GET responses. `JSONValue` decodes *any* JSON payload and offers
/// ergonomic, crash-free accessors (`json["items"].array`, `json["title"].string`, ...).
@dynamicMemberLookup
enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    // MARK: Decoding

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .object(let o): try container.encode(o)
        case .array(let a): try container.encode(a)
        case .null: try container.encodeNil()
        }
    }

    // MARK: Accessors

    subscript(dynamicMember key: String) -> JSONValue { self[key] }

    subscript(key: String) -> JSONValue {
        if case .object(let dict) = self { return dict[key] ?? .null }
        return .null
    }

    subscript(index: Int) -> JSONValue {
        if case .array(let arr) = self, arr.indices.contains(index) { return arr[index] }
        return .null
    }

    var string: String? {
        switch self {
        case .string(let s): return s
        case .number(let n): return n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(n)
        case .bool(let b): return String(b)
        default: return nil
        }
    }

    var int: Int? {
        switch self {
        case .number(let n): return Int(n)
        case .string(let s): return Int(s) ?? Double(s).map(Int.init)
        case .bool(let b): return b ? 1 : 0
        default: return nil
        }
    }

    var double: Double? {
        switch self {
        case .number(let n): return n
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    var bool: Bool? {
        switch self {
        case .bool(let b): return b
        case .number(let n): return n != 0
        case .string(let s): return ["1", "true", "yes", "on"].contains(s.lowercased())
        default: return nil
        }
    }

    var array: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    var object: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }

    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    /// First non-null value among the given keys — useful when the server uses
    /// different field names across endpoints (e.g. `title` vs `name`).
    func firstString(_ keys: String...) -> String? {
        for k in keys {
            if let v = self[k].string, !v.isEmpty { return v }
        }
        return nil
    }

    /// Finds the first numeric value for any of the given keys, searching nested
    /// containers as a fallback. Key matching ignores case, `_`, `-` and spaces.
    func firstInt(_ keys: String...) -> Int? {
        firstNumber(keys).map { Int($0) }
    }

    /// Finds the first numeric value for any of the given keys, searching nested
    /// containers as a fallback. Useful for loosely-shaped dashboard payloads.
    func firstDouble(_ keys: String...) -> Double? {
        firstNumber(keys)
    }

    /// Finds a numeric value in entries shaped like `{ label: "电影", value: 123 }`.
    func firstInt(labeled labels: String...) -> Int? {
        firstLabeledNumber(labels).map { Int($0) }
    }

    /// Finds a numeric value in entries shaped like `{ label: "CPU", percent: 12 }`.
    func firstDouble(labeled labels: String...) -> Double? {
        firstLabeledNumber(labels)
    }

    /// Returns a nested value for a fixed object path.
    func value(at path: [String]) -> JSONValue? {
        guard !path.isEmpty else { return self }
        var current = self
        for key in path {
            let next = current[key]
            guard !next.isNull else { return nil }
            current = next
        }
        return current
    }

    private func firstNumber(_ keys: [String]) -> Double? {
        let wanted = Set(keys.map(Self.normalizedKey))
        return firstNumber(matching: wanted)
    }

    private func firstLabeledNumber(_ labels: [String]) -> Double? {
        let wanted = Set(labels.map(Self.normalizedKey))
        return firstLabeledNumber(matching: wanted)
    }

    private func firstNumber(matching wanted: Set<String>) -> Double? {
        guard !wanted.isEmpty else { return nil }
        switch self {
        case .object(let dict):
            for (key, value) in dict where wanted.contains(Self.normalizedKey(key)) {
                if let number = value.numberForMatchedContainer() { return number }
            }
            for value in dict.values {
                if let number = value.firstNumber(matching: wanted) { return number }
            }
            return nil
        case .array(let array):
            for value in array {
                if let number = value.firstNumber(matching: wanted) { return number }
            }
            return nil
        case .string(let string):
            return Self.parsedJSONString(string)?.firstNumber(matching: wanted)
        default:
            return nil
        }
    }

    private func firstLabeledNumber(matching wanted: Set<String>) -> Double? {
        guard !wanted.isEmpty else { return nil }
        switch self {
        case .object(let dict):
            if let label = firstString("label", "title", "name", "key", "type", "metric"),
               Self.label(label, matches: wanted) {
                let valueKeys = [
                    "value", "display_value", "displayValue", "text", "display", "summary",
                    "count", "total", "num", "number", "amount", "percent", "percentage", "usage", "used"
                ]
                for key in valueKeys {
                    let normalized = Self.normalizedKey(key)
                    for (rawKey, value) in dict where Self.normalizedKey(rawKey) == normalized {
                        if let number = value.numberForMatchedContainer() { return number }
                    }
                }
                for value in dict.values {
                    if let number = value.numberForMatchedContainer() { return number }
                }
            }
            for value in dict.values {
                if let number = value.firstLabeledNumber(matching: wanted) { return number }
            }
            return nil
        case .array(let array):
            for value in array {
                if let number = value.firstLabeledNumber(matching: wanted) { return number }
            }
            return nil
        case .string(let string):
            return Self.parsedJSONString(string)?.firstLabeledNumber(matching: wanted)
        default:
            return nil
        }
    }

    private func numberForMatchedContainer() -> Double? {
        switch self {
        case .number(let n):
            return n
        case .string(let s):
            return Self.decoratedNumber(s)
        case .bool(let b):
            return b ? 1 : 0
        case .array(let a):
            return Double(a.count)
        case .object(let dict):
            let countKeys = [
                "count", "total", "value", "display_value", "displayValue", "text",
                "num", "number", "amount", "percent", "percentage", "usage",
                "usage_percent", "used_percent"
            ]
            for key in countKeys {
                let wanted = Self.normalizedKey(key)
                for (rawKey, value) in dict where Self.normalizedKey(rawKey) == wanted {
                    if let number = value.numberForMatchedContainer() { return number }
                }
            }
            return nil
        case .null:
            return nil
        }
    }

    private static func normalizedKey(_ key: String) -> String {
        key.lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private static func decoratedNumber(_ string: String) -> Double? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let compact = trimmed
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "% "))
        if let exact = Double(compact) { return exact }

        guard let range = compact.range(of: #"[-+]?\d+(?:\.\d+)?"#, options: .regularExpression),
              let number = Double(String(compact[range])) else {
            return nil
        }

        if compact.contains("亿") { return number * 100_000_000 }
        if compact.contains("万") { return number * 10_000 }
        if compact.range(of: #"(?i)\d+(?:\.\d+)?k\b"#, options: .regularExpression) != nil {
            return number * 1_000
        }
        return number
    }

    private static func parsedJSONString(_ string: String) -> JSONValue? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "{" || trimmed.first == "[" else { return nil }
        guard let data = trimmed.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(JSONValue.self, from: data)
    }

    private static func label(_ label: String, matches wanted: Set<String>) -> Bool {
        let normalized = normalizedKey(label)
        return wanted.contains(where: { normalized.contains($0) || $0.contains(normalized) })
    }
}

extension JSONValue {
    /// Best-effort conversion from a loosely-typed Swift value, used to build
    /// request bodies ergonomically: `JSONValue.obj(["cid": cid, "enabled": true])`.
    init(any value: Any?) {
        guard let value else {
            self = .null
            return
        }
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            if let child = mirror.children.first {
                self = JSONValue(any: child.value)
            } else {
                self = .null
            }
            return
        }

        switch value {
        case let v as JSONValue: self = v
        case let v as String: self = .string(v)
        case let v as Bool: self = .bool(v)
        case let v as Int: self = .number(Double(v))
        case let v as Double: self = .number(v)
        case let v as Float: self = .number(Double(v))
        case let v as [JSONValue]: self = .array(v)
        case let v as [String]: self = .array(v.map { .string($0) })
        case let v as [Int]: self = .array(v.map { .number(Double($0)) })
        case let v as [Double]: self = .array(v.map { .number($0) })
        case let v as [Bool]: self = .array(v.map { .bool($0) })
        case let v as [Any?]: self = .array(v.map { JSONValue(any: $0) })
        case let v as [Any]: self = .array(v.map { JSONValue(any: $0) })
        case let v as [String: JSONValue]: self = .object(v)
        case let v as [String: String]: self = .object(v.mapValues { .string($0) })
        case let v as [String: Int]: self = .object(v.mapValues { .number(Double($0)) })
        case let v as [String: Double]: self = .object(v.mapValues { .number($0) })
        case let v as [String: Bool]: self = .object(v.mapValues { .bool($0) })
        case let v as [String: Any?]: self = .object(v.mapValues { JSONValue(any: $0) })
        case let v as [String: Any]: self = .object(v.mapValues { JSONValue(any: $0) })
        default:
            self = .null
        }
    }

    /// Builds a JSON object from a dictionary literal.
    static func obj(_ dict: [String: Any?]) -> JSONValue {
        .object(dict.mapValues { JSONValue(any: $0) })
    }

    func prettyJSONString() -> String {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8) ?? (string ?? "")
        } catch {
            return string ?? ""
        }
    }

    static func parse(_ text: String) throws -> JSONValue {
        guard let data = text.data(using: .utf8) else { throw APIError.decoding("JSON 不是 UTF-8 文本") }
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    static func parseObjectOrEmpty(_ text: String) throws -> JSONValue {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .obj([:]) : try parse(text)
    }

    /// Extracts an array of items from common container shapes.
    func items(_ extraKeys: String...) -> [JSONValue] {
        if let a = array { return a }
        for k in ["items", "results", "data", "list", "tasks", "records", "containers", "images", "users", "entries", "sources", "presets", "reminders", "audit", "history"] + extraKeys {
            if let a = self[k].array { return a }
        }
        if let a = self["data"]["items"].array { return a }
        return []
    }
}
