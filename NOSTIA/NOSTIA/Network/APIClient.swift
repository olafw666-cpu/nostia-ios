import Foundation

final class APIClient {
    static let shared = APIClient()
    private let baseURL = AppConfig.apiBaseURL
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - Generic Request

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        // Demo builds answer from `DemoBackend` and never open a socket. This sits above
        // the token guard on purpose: there is nothing to authenticate against, and a
        // missing Keychain entry must not turn every request into `noToken`. Everything
        // below — the decoder, the error types, the callers — is untouched, because what
        // comes back is the same `Data` a real response would carry.
        if AppConfig.isDemoMode {
            let data = try await DemoBackend.respond(path: path, method: method, body: body)
            return try decode(data)
        }

        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            guard let token = AuthManager.shared.getToken() else { throw APIError.noToken }
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        return try await executeRequest(urlRequest, requiresAuth: requiresAuth, allowRetry: requiresAuth, path: path, method: method, body: body)
    }

    private func executeRequest<T: Decodable>(
        _ urlRequest: URLRequest,
        requiresAuth: Bool,
        allowRetry: Bool,
        path: String,
        method: String,
        body: [String: Any]?
    ) async throws -> T {
        let (data, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }

        if http.statusCode == 401 {
            if requiresAuth && allowRetry {
                // Attempt silent token refresh before forcing logout
                if let newToken = try? await AuthAPI.shared.refreshAccessToken() {
                    var retryRequest = urlRequest
                    retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                    return try await executeRequest(retryRequest, requiresAuth: requiresAuth, allowRetry: false, path: path, method: method, body: body)
                }
                AuthManager.shared.logout()
                throw APIError.httpError(statusCode: 401, message: "Session expired. Please log in again.")
            } else if requiresAuth {
                AuthManager.shared.logout()
                throw APIError.httpError(statusCode: 401, message: "Session expired. Please log in again.")
            } else {
                throw APIError.httpError(statusCode: 401, message: "Incorrect login information, try again.")
            }
        }

        if http.statusCode == 403 {
            let errMsg = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.error ?? ""
            if errMsg == "Invalid or expired token" {
                AuthManager.shared.logout()
                throw APIError.httpError(statusCode: 403, message: "Session expired. Please log in again.")
            }
            throw APIError.httpError(statusCode: 403, message: errMsg.isEmpty ? "Access denied" : errMsg)
        }

        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.error ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw APIError.httpError(statusCode: http.statusCode, message: msg)
        }

        return try decode(data)
    }

    /// Shared by the live and demo paths so both fail the same way on a shape mismatch.
    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    // Void response variant (for DELETE, PUT that return no body)
    func requestVoid(
        _ path: String,
        method: String,
        body: [String: Any]? = nil
    ) async throws {
        // Same short-circuit as `request(_:)`, above the token guard for the same reason.
        if AppConfig.isDemoMode {
            _ = try await DemoBackend.respond(path: path, method: method, body: body)
            return
        }

        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Every `requestVoid` caller is an authenticated mutation. Sending it
        // token-less (the old behaviour when the Keychain was empty) guaranteed a
        // 401, and the 401 path calls `logout()` — so a missing token turned a
        // no-op into a forced sign-out plus a cache wipe. Fail before the wire,
        // the way `request(_:)` already does.
        guard let token = AuthManager.shared.getToken() else { throw APIError.noToken }
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let body {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        try await executeRequestVoid(urlRequest, allowRetry: true, path: path, method: method, body: body)
    }

    private func executeRequestVoid(
        _ urlRequest: URLRequest,
        allowRetry: Bool,
        path: String,
        method: String,
        body: [String: Any]?
    ) async throws {
        let (data, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }

        if http.statusCode == 401 {
            if allowRetry {
                if let newToken = try? await AuthAPI.shared.refreshAccessToken() {
                    var retryRequest = urlRequest
                    retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                    return try await executeRequestVoid(retryRequest, allowRetry: false, path: path, method: method, body: body)
                }
            }
            AuthManager.shared.logout()
            throw APIError.httpError(statusCode: 401, message: "Session expired. Please log in again.")
        }
        if http.statusCode == 403 {
            let errMsg = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.error ?? "Access denied"
            if errMsg == "Invalid or expired token" { AuthManager.shared.logout() }
            throw APIError.httpError(statusCode: 403, message: errMsg)
        }

        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.error ?? "Request failed"
            throw APIError.httpError(statusCode: http.statusCode, message: msg)
        }
    }
}

struct APIErrorResponse: Decodable {
    let error: String
}
