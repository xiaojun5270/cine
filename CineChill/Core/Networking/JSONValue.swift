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
}

extension JSONValue {
    /// Best-effort conversion from a loosely-typed Swift value, used to build
    /// request bodies ergonomically: `JSONValue.obj(["cid": cid, "enabled": true])`.
    init(any value: Any?) {
        switch value {
        case .none: self = .null
        case let v as JSONValue: self = v
        case let v as String: self = .string(v)
        case let v as Bool: self = .bool(v)
        case let v as Int: self = .number(Double(v))
        case let v as Double: self = .number(v)
        case let v as [Any?]: self = .array(v.map { JSONValue(any: $0) })
        case let v as [String: Any?]: self = .object(v.mapValues { JSONValue(any: $0) })
        default:
            if case Optional<Any>.none = value { self = .null } else { self = .null }
        }
    }

    /// Builds a JSON object from a dictionary literal.
    static func obj(_ dict: [String: Any?]) -> JSONValue {
        .object(dict.mapValues { JSONValue(any: $0) })
    }

    /// Extracts an array of items from common container shapes.
    func items(_ extraKeys: String...) -> [JSONValue] {
        if let a = array { return a }
        for k in ["items", "results", "data", "list", "tasks", "records", "containers", "users"] + extraKeys {
            if let a = self[k].array { return a }
        }
        if let a = self["data"]["items"].array { return a }
        return []
    }
}
