import Foundation

/// Normalised error surfaced to the UI layer.
enum APIError: LocalizedError, Equatable {
    case notConfigured
    case invalidURL
    case unauthorized
    case http(status: Int, message: String?)
    case validation([String])
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "尚未配置服务器地址，请先在设置中填写。"
        case .invalidURL:
            return "服务器地址无效。"
        case .unauthorized:
            return "登录已失效，请重新登录。"
        case .http(let status, let message):
            if let message, !message.isEmpty { return "请求失败（\(status)）：\(message)" }
            return "请求失败，HTTP \(status)。"
        case .validation(let items):
            return "参数校验失败：\(items.joined(separator: "；"))"
        case .decoding(let detail):
            return "数据解析失败：\(detail)"
        case .transport(let detail):
            return "网络错误：\(detail)"
        }
    }
}
