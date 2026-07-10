import Foundation

/// Connection settings for a CineChill server instance.
/// Base address format per the API doc: `http://<服务器IP>:5256`.
struct ServerConfig: Codable, Equatable, Sendable {
    var scheme: String       // "http" or "https"
    var host: String         // IP or domain
    var port: Int            // default 5256

    static let defaultPort = 5256

    init(scheme: String = "http", host: String = "", port: Int = ServerConfig.defaultPort) {
        self.scheme = scheme
        self.host = host
        self.port = port
    }

    /// Builds a `ServerConfig` from a user-typed string such as
    /// `192.168.1.10:5256`, `http://nas.local:5256` or `https://example.com`.
    init?(raw: String) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        var scheme = "http"
        if let range = text.range(of: "://") {
            scheme = String(text[..<range.lowerBound]).lowercased()
            text = String(text[range.upperBound...])
        }
        // Strip any trailing path.
        if let slash = text.firstIndex(of: "/") {
            text = String(text[..<slash])
        }

        var host = text
        var port = scheme == "https" ? 443 : ServerConfig.defaultPort
        if let colon = text.lastIndex(of: ":") {
            host = String(text[..<colon])
            if let p = Int(text[text.index(after: colon)...]) { port = p }
        }
        guard !host.isEmpty else { return nil }
        self.scheme = scheme
        self.host = host
        self.port = port
    }

    var baseURL: URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = port
        return components.url
    }

    var displayString: String { "\(scheme)://\(host):\(port)" }

    var isValid: Bool { baseURL != nil && !host.isEmpty }
}
