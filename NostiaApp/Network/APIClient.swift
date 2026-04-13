import Foundation

final class APIClient {
    static let shared = APIClient()
    private let baseURL = AppConfig.apiBaseURL
    private let session = URLSession.shared

    private init() {}

    // MARK: - Generic Request

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            guard let token = AuthManager.shared.getToken() else { throw APIError.noToken }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }

        if http.statusCode == 401 {
            AuthManager.shared.logout()
            throw APIError.httpError(statusCode: 401, message: "Session expired. Please log in again.")
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

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = AuthManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }

        if http.statusCode == 401 { AuthManager.shared.logout(); return }
        if http.statusCode == 403 {
            let errMsg = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.error ?? ""
            if errMsg == "Invalid or expired token" { AuthManager.shared.logout() }
            return
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
