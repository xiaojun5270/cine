import Foundation

/// Thin async networking layer over the CineChill FastAPI backend.
///
/// * Base address is configured at runtime (`http://<IP>:5256`).
/// * Auth is cookie/session based — `POST /api/login` returns a session
///   cookie that `URLSession`'s shared cookie storage replays automatically.
/// * Responses are decoded into `JSONValue` by default because the server
///   declares almost no response schemas; typed decoding is opt-in.
final class APIClient: @unchecked Sendable {
    static let shared = APIClient()

    private let lock = NSLock()
    private var _baseURL: URL?
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }

    var baseURL: URL? {
        lock.lock(); defer { lock.unlock() }
        return _baseURL
    }

    func configure(server: ServerConfig) {
        lock.lock(); _baseURL = server.baseURL; lock.unlock()
    }

    func clearCookies() {
        guard let url = baseURL, let cookies = HTTPCookieStorage.shared.cookies(for: url) else { return }
        cookies.forEach(HTTPCookieStorage.shared.deleteCookie)
    }

    // MARK: - HTTP verbs

    enum Method: String { case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE", put = "PUT" }

    /// Performs a request and returns a decoded `JSONValue`.
    @discardableResult
    func request(
        _ method: Method,
        _ path: String,
        query: [String: String?] = [:],
        body: (any Encodable)? = nil
    ) async throws -> JSONValue {
        let data = try await rawData(method, path, query: query, body: body)
        if data.isEmpty { return .null }
        do {
            return try JSONDecoder().decode(JSONValue.self, from: data)
        } catch {
            // Non-JSON payloads (plain text / streams) — wrap as string.
            if let text = String(data: data, encoding: .utf8) { return .string(text) }
            throw APIError.decoding(error.localizedDescription)
        }
    }

    /// Performs a request and decodes into a concrete `Decodable` type.
    func request<T: Decodable>(
        _ type: T.Type,
        _ method: Method,
        _ path: String,
        query: [String: String?] = [:],
        body: (any Encodable)? = nil
    ) async throws -> T {
        let data = try await rawData(method, path, query: query, body: body)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    /// Core request execution with error normalisation.
    func rawData(
        _ method: Method,
        _ path: String,
        query: [String: String?] = [:],
        body: (any Encodable)? = nil
    ) async throws -> Data {
        guard let base = baseURL else { throw APIError.notConfigured }
        guard var components = URLComponents(url: base.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path),
                                             resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        let items = query.compactMap { key, value -> URLQueryItem? in
            guard let value else { return nil }
            return URLQueryItem(name: key, value: value)
        }
        if !items.isEmpty { components.queryItems = items }
        guard let url = components.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.transport("无响应")
            }
            switch http.statusCode {
            case 200...299:
                return data
            case 401, 403:
                throw APIError.unauthorized
            case 422:
                throw APIError.validation(Self.parseValidation(data))
            default:
                throw APIError.http(status: http.statusCode, message: Self.parseMessage(data))
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }

    // MARK: - Image URLs

    /// Absolute URL for an image-proxy / media endpoint, cookies applied automatically by AsyncImage's session.
    func mediaURL(_ path: String, query: [String: String?] = [:]) -> URL? {
        guard let base = baseURL else { return nil }
        guard var comps = URLComponents(url: base.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path),
                                        resolvingAgainstBaseURL: false) else { return nil }
        let items = query.compactMap { k, v -> URLQueryItem? in v.map { URLQueryItem(name: k, value: $0) } }
        if !items.isEmpty { comps.queryItems = items }
        return comps.url
    }

    // MARK: - Error parsing

    private static func parseValidation(_ data: Data) -> [String] {
        guard let json = try? JSONDecoder().decode(JSONValue.self, from: data),
              let details = json["detail"].array else { return ["请求参数不正确"] }
        return details.compactMap { $0["msg"].string }
    }

    private static func parseMessage(_ data: Data) -> String? {
        guard let json = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            return String(data: data, encoding: .utf8)
        }
        return json.firstString("detail", "message", "error", "msg")
    }
}

/// Type-erased Encodable so heterogeneous request bodies can be passed around.
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ wrapped: any Encodable) { encodeFunc = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}
