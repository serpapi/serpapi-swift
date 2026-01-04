import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Client implementation for SerpApi.com
///
/// Features:
/// * Async non-blocking search (via Swift Concurrency)
/// * Persistent HTTP connection (via URLSession)
/// * Search API
/// * Location API
/// * Account API
/// * Search Archive API
public class SerpApiClient: CustomStringConvertible {
    private let backend = "serpapi.com"
    
    /// HTTP timeout for requests in seconds
    public let timeout: TimeInterval
    
    /// Keep socket connection open to save on SSL handshake / connection reconnection
    public let persistent: Bool
    
    /// Default query parameters
    public private(set) var params: [String: String]
    
    private let session: URLSession
    
    /// Constructor
    ///
    /// The `SerpApiClient` constructor takes a dictionary of options as input.
    ///
    /// **Example:**
    ///
    /// ```swift
    /// let client = SerpApiClient(params: [
    ///     "api_key": "secure API key",
    ///     "engine": "google"
    /// ])
    /// ```
    ///
    /// - Parameter params: Dictionary of parameters.
    ///   - `api_key`: [String] User secret API key.
    ///   - `engine`: [String] Search engine selected.
    ///   - `persistent`: [String] "true" or "false". Keep socket connection open. [default: "true"]
    ///   - `timeout`: [String] HTTP get max timeout in seconds [default: "120"]
    public init(params: [String: String] = [:]) {
        self.timeout = TimeInterval(params["timeout"] ?? "120") ?? 120.0
        self.persistent = (params["persistent"] ?? "true") == "true"
        
        var baseParams = params
        // These are client-side config, not to be sent to API unless intended (async is sent)
        baseParams.removeValue(forKey: "timeout")
        baseParams.removeValue(forKey: "persistent")
        
        if baseParams["source"] == nil {
            baseParams["source"] = "serpapi-swift:\(SerpApi.version)"
        }
        self.params = baseParams
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = self.timeout
        // URLSession handles persistent connections by default via its connection pool.
        self.session = URLSession(configuration: configuration)
    }
    
    /// Perform a search using SerpApi.com
    ///
    /// See: https://serpapi.com/search-api
    ///
    /// - Parameter params: includes engine, api_key, search fields and more.
    ///   This overrides the default params provided to the constructor.
    /// - Returns: search results formatted as a Dictionary
    public func search(params: [String: String] = [:]) async throws -> [String: Any] {
        return try await get(endpoint: "/search", decoder: .json, params: params) as! [String: Any]
    }
    
    /// HTML search perform a search using SerpApi.com
    ///
    /// The output is raw HTML from the search engine.
    /// It is useful for training AI models, RAG, debugging or when you need to parse the HTML yourself.
    ///
    /// - Parameter params: includes engine, api_key, search fields and more.
    /// - Returns: raw HTML search results directly from the search engine
    public func html(params: [String: String] = [:]) async throws -> String {
        return try await get(endpoint: "/search", decoder: .html, params: params) as! String
    }
    
    /// Get location using Location API
    ///
    /// Doc: https://serpapi.com/locations-api
    ///
    /// - Parameter params: must include fields: `q`, `limit`
    /// - Returns: list of matching locations
    public func location(params: [String: String] = [:]) async throws -> [[String: Any]] {
        return try await get(endpoint: "/locations.json", decoder: .json, params: params) as! [[String: Any]]
    }
    
    /// Retrieve search result from the Search Archive API
    ///
    /// Doc: https://serpapi.com/search-archive-api
    ///
    /// - Parameters:
    ///   - searchID: from original search `results["search_metadata"]["id"]`
    ///   - format: "json" or "html" [default: "json"]
    /// - Returns: raw HTML or JSON Dictionary
    public func searchArchive(searchID: String, format: String = "json") async throws -> Any {
        guard format == "json" || format == "html" else {
            throw SerpApiError.invalidDecoder("format must be json or html")
        }
        let decoder: DecoderType = format == "json" ? .json : .html
        return try await get(endpoint: "/searches/\(searchID).\(format)", decoder: decoder)
    }
    
    /// Get account information using Account API
    ///
    /// Doc: https://serpapi.com/account-api
    ///
    /// - Parameter apiKey: secret key [optional if already provided to the constructor]
    /// - Returns: account information
    public func account(apiKey: String? = nil) async throws -> [String: Any] {
        var params: [String: String] = [:]
        if let apiKey = apiKey {
            params["api_key"] = apiKey
        }
        return try await get(endpoint: "/account", decoder: .json, params: params) as! [String: Any]
    }
    
    /// Default search engine
    public var engine: String? {
        return params["engine"]
    }
    
    /// API Key
    public var apiKey: String? {
        return params["api_key"]
    }
    
    /// Close open connection if active
    ///
    /// In URLSession, this invalidates the session and cancels tasks.
    public func close() {
        session.invalidateAndCancel()
    }
    
    public var description: String {
        let maskedKey = apiKey.map { key in
            if key.count > 8 {
                return "\(key.prefix(4))****\(key.suffix(4))"
            } else {
                return "****"
            }
        } ?? "nil"
        
        return "<SerpApiClient @engine=\(engine ?? "nil") @timeout=\(timeout) @persistent=\(persistent) api_key=\(maskedKey)>"
    }
    
    private enum DecoderType {
        case json
        case html
    }
    
    private func query(params: [String: String]) -> [String: String] {
        var q = self.params
        for (key, value) in params {
            q[key] = value
        }
        return q
    }
    
    private func get(endpoint: String, decoder: DecoderType, params: [String: String] = [:]) async throws -> Any {
        let queryItems = query(params: params).map { URLQueryItem(name: $0.key, value: $0.value) }
        var components = URLComponents(string: "https://\(backend)\(endpoint)")
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw SerpApiError.invalidParams("Invalid URL components")
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SerpApiError.requestFailed("Invalid response type")
        }
        
        switch decoder {
        case .json:
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                
                if let dict = json as? [String: Any], let error = dict["error"] as? String {
                    throw SerpApiError.requestFailed("HTTP request failed with error: \(error) from url: \(url), response status: \(httpResponse.statusCode)")
                }
                
                if httpResponse.statusCode != 200 {
                    // Try to parse error from body if possible
                    if let dict = json as? [String: Any] {
                         throw SerpApiError.requestFailed("HTTP request failed with response status: \(httpResponse.statusCode) response: \(dict) on get url: \(url)")
                    }
                    throw SerpApiError.requestFailed("HTTP request failed with response status: \(httpResponse.statusCode) on get url: \(url)")
                }
                
                return json
            } catch {
                if let decodingError = error as? SerpApiError {
                    throw decodingError
                }
                // If it wasn't our error, it's a parse error
                throw SerpApiError.jsonParseError("JSON parse error: \(error.localizedDescription) on get url: \(url), response status: \(httpResponse.statusCode)")
            }
        case .html:
            if httpResponse.statusCode != 200 {
                throw SerpApiError.requestFailed("HTTP request failed with response status: \(httpResponse.statusCode) on get url: \(url)")
            }
            guard let html = String(data: data, encoding: .utf8) else {
                throw SerpApiError.jsonParseError("Failed to decode HTML as UTF-8")
            }
            return html
        }
    }
}
