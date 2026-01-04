import Foundation

public enum SerpApiError: Error, LocalizedError {
    case invalidParams(String)
    case requestFailed(String)
    case jsonParseError(String)
    case invalidDecoder(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidParams(let message):
            return "Invalid parameters: \(message)"
        case .requestFailed(let message):
            return "HTTP request failed: \(message)"
        case .jsonParseError(let message):
            return "JSON parse error: \(message)"
        case .invalidDecoder(let message):
            return "Invalid decoder: \(message)"
        }
    }
}

