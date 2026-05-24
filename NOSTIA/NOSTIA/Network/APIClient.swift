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
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = AuthManager.shared.getToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

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
