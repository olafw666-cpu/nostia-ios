import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case noToken
    case httpError(statusCode: Int, message: String)
    case decodingError(String)
    case networkError(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noToken: return "Not authenticated"
        case .httpError(_, let msg): return msg
        case .decodingError(let msg): return "Data error: \(msg)"
        case .networkError(let msg): return msg
        case .unknown: return "An unknown error occurred"
        }
    }
}
