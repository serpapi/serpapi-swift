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
    
    private static let backend = "serpapi.com"
    private static let defaultTimeout: TimeInterval = 120.0
    private static let defaultPersistent = true
    private static let paramTimeout = "timeout"
    private static let paramPersistent = "persistent"
    private static let paramSource = "source"
    private static let paramApiKey = "api_key"
    private static let paramEngine = "engine"
    private static let endpointSearch = "/search"
    private static let endpointLocations = "/locations.json"
    private static let endpointAccount = "/account"
    private static let endpointSearches = "/searches"
    private static let formatJson = "json"
    private static let formatHtml = "html"
    private static let httpStatusCodeSuccess = 200
    
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
        self.timeout = TimeInterval(params[Self.paramTimeout] ?? String(Self.defaultTimeout)) ?? Self.defaultTimeout
        self.persistent = (params[Self.paramPersistent] ?? (Self.defaultPersistent ? "true" : "false")) == "true"
        
        var baseParams = params
        // These are client-side config, not to be sent to API unless intended (async is sent)
        baseParams.removeValue(forKey: Self.paramTimeout)
        baseParams.removeValue(forKey: Self.paramPersistent)
        
        if baseParams[Self.paramSource] == nil {
            baseParams[Self.paramSource] = "serpapi-swift:\(SerpApi.version)"
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
        let result = try await get(endpoint: Self.endpointSearch, decoder: .json, params: params)
        guard let dict = result as? [String: Any] else {
            throw SerpApiError.jsonParseError("Expected dictionary but got \(type(of: result))")
        }
        return dict
    }
    
    /// HTML search perform a search using SerpApi.com
    ///
    /// The output is raw HTML from the search engine.
    /// It is useful for training AI models, RAG, debugging or when you need to parse the HTML yourself.
    ///
    /// - Parameter params: includes engine, api_key, search fields and more.
    /// - Returns: raw HTML search results directly from the search engine
    public func html(params: [String: String] = [:]) async throws -> String {
        let result = try await get(endpoint: Self.endpointSearch, decoder: .html, params: params)
        guard let html = result as? String else {
            throw SerpApiError.jsonParseError("Expected string but got \(type(of: result))")
        }
        return html
    }
    
    /// Get location using Location API
    ///
    /// Doc: https://serpapi.com/locations-api
    ///
    /// - Parameter params: must include fields: `q`, `limit`
    /// - Returns: list of matching locations
    public func location(params: [String: String] = [:]) async throws -> [[String: Any]] {
        let result = try await get(endpoint: Self.endpointLocations, decoder: .json, params: params)
        guard let array = result as? [[String: Any]] else {
            throw SerpApiError.jsonParseError("Expected array of dictionaries but got \(type(of: result))")
        }
        return array
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
        guard format == Self.formatJson || format == Self.formatHtml else {
            throw SerpApiError.invalidDecoder("format must be \(Self.formatJson) or \(Self.formatHtml)")
        }
        let decoder: DecoderType = format == Self.formatJson ? .json : .html
        return try await get(endpoint: "\(Self.endpointSearches)/\(searchID).\(format)", decoder: decoder)
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
            params[Self.paramApiKey] = apiKey
        }
        let result = try await get(endpoint: Self.endpointAccount, decoder: .json, params: params)
        guard let dict = result as? [String: Any] else {
            throw SerpApiError.jsonParseError("Expected dictionary but got \(type(of: result))")
        }
        return dict
    }
    
    /// Default search engine
    public var engine: String? {
        return params[Self.paramEngine]
    }
    
    /// API Key
    public var apiKey: String? {
        return params[Self.paramApiKey]
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
        var components = URLComponents(string: "https://\(Self.backend)\(endpoint)")
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
                
                if httpResponse.statusCode != Self.httpStatusCodeSuccess {
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
            if httpResponse.statusCode != Self.httpStatusCodeSuccess {
                throw SerpApiError.requestFailed("HTTP request failed with response status: \(httpResponse.statusCode) on get url: \(url)")
            }
            guard let html = String(data: data, encoding: .utf8) else {
                throw SerpApiError.htmlParseError("Failed to decode HTML as UTF-8 from url: \(url)")
            }
            return html
        }
    }
}
