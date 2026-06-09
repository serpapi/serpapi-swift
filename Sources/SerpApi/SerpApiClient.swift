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
public final class SerpApiClient: CustomStringConvertible, Sendable {
    
    private static let backend = "serpapi.com"
    private static let defaultTimeout: TimeInterval = 120.0
    private static let defaultPersistent = true
    private static let defaultMaxRetries = 3
    private static let defaultRetryBaseDelay: TimeInterval = 0.5
    private static let defaultRetryMaxDelay: TimeInterval = 8.0
    private static let paramTimeout = "timeout"
    private static let paramPersistent = "persistent"
    private static let paramMaxRetries = "max_retries"
    private static let paramRetryBaseDelay = "retry_base_delay"
    private static let paramRetryMaxDelay = "retry_max_delay"
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
    private static let headerRetryAfter = "Retry-After"
    /// HTTP status codes that are considered transient and worth retrying.
    private static let retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 504]

    /// HTTP timeout for requests in seconds
    public let timeout: TimeInterval

    /// Keep socket connection open to save on SSL handshake / connection reconnection
    public let persistent: Bool

    /// Maximum number of automatic retries for transient failures (HTTP 429/5xx and transient network errors)
    public let maxRetries: Int

    /// Base delay in seconds for exponential backoff between retries
    public let retryBaseDelay: TimeInterval

    /// Maximum delay in seconds for any single backoff wait (also caps server `Retry-After`)
    public let retryMaxDelay: TimeInterval

    /// Default query parameters
    public let params: [String: String]

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
    ///   - `max_retries`: [String] number of automatic retries for transient failures (HTTP 429/5xx, network blips) [default: "3"]
    ///   - `retry_base_delay`: [String] base delay in seconds for exponential backoff [default: "0.5"]
    ///   - `retry_max_delay`: [String] maximum delay in seconds for a single backoff wait [default: "8.0"]
    public init(params: [String: String] = [:]) {
        self.timeout = TimeInterval(params[Self.paramTimeout] ?? String(Self.defaultTimeout)) ?? Self.defaultTimeout
        self.persistent = (params[Self.paramPersistent] ?? (Self.defaultPersistent ? "true" : "false")) == "true"
        self.maxRetries = max(0, params[Self.paramMaxRetries].flatMap(Int.init) ?? Self.defaultMaxRetries)
        self.retryBaseDelay = max(0, params[Self.paramRetryBaseDelay].flatMap(TimeInterval.init) ?? Self.defaultRetryBaseDelay)
        self.retryMaxDelay = max(0, params[Self.paramRetryMaxDelay].flatMap(TimeInterval.init) ?? Self.defaultRetryMaxDelay)

        var baseParams = params
        // These are client-side config, not to be sent to API unless intended (async is sent)
        baseParams.removeValue(forKey: Self.paramTimeout)
        baseParams.removeValue(forKey: Self.paramPersistent)
        baseParams.removeValue(forKey: Self.paramMaxRetries)
        baseParams.removeValue(forKey: Self.paramRetryBaseDelay)
        baseParams.removeValue(forKey: Self.paramRetryMaxDelay)

        if baseParams[Self.paramSource] == nil {
            baseParams[Self.paramSource] = "serpapi-swift:\(SerpApi.version)"
        }
        self.params = baseParams
        
        let configuration = self.persistent ? URLSessionConfiguration.default : URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = self.timeout
        // URLSession handles persistent connections by default via its connection pool.
        // When `persistent` is false, an ephemeral configuration avoids persisting caches/cookies.
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
    
    deinit {
        session.invalidateAndCancel()
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

    static func redactedURLString(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        components.queryItems = components.queryItems?.map { item in
            if item.name == Self.paramApiKey {
                return URLQueryItem(name: item.name, value: "REDACTED")
            }
            return item
        }
        return components.string ?? url.absoluteString
    }

    /// Whether a response with the given HTTP status code should be retried.
    static func isRetryable(status: Int) -> Bool {
        retryableStatusCodes.contains(status)
    }

    /// Whether a thrown `URLError` is transient and worth retrying.
    /// `.cancelled` is intentionally excluded so cancellation propagates instead of being retried.
    static func isRetryable(urlError: URLError) -> Bool {
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    /// Full-jitter exponential backoff delay (in seconds) for a 0-based attempt index.
    ///
    /// Returns a uniformly random value in `0...min(maxDelay, base * 2^attempt)`, which spreads
    /// retries out to avoid thundering-herd behavior under concurrent load.
    static func backoffDelay(attempt: Int, base: TimeInterval, max maxDelay: TimeInterval) -> TimeInterval {
        let exponential = base * pow(2.0, Double(attempt))
        let capped = Swift.min(maxDelay, exponential)
        guard capped > 0 else { return 0 }
        return Double.random(in: 0...capped)
    }

    /// Parse a `Retry-After` header value into seconds from now.
    /// Supports both delta-seconds (e.g. `"5"`) and HTTP-date (e.g. `"Wed, 21 Oct 2015 07:28:00 GMT"`).
    static func parseRetryAfter(_ value: String) -> TimeInterval? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if let seconds = TimeInterval(trimmed) {
            return Swift.max(0, seconds)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let date = formatter.date(from: trimmed) {
            return Swift.max(0, date.timeIntervalSinceNow)
        }
        return nil
    }

    /// Sleep before the next retry, honoring a server `Retry-After` delay when present
    /// (capped to `retryMaxDelay`), otherwise using full-jitter exponential backoff.
    /// Cancellation-aware: `Task.sleep` throws `CancellationError` if the task is cancelled.
    private func sleepBeforeRetry(attempt: Int, retryAfter: TimeInterval?) async throws {
        let delay = retryAfter.map { Swift.min($0, retryMaxDelay) }
            ?? Self.backoffDelay(attempt: attempt, base: retryBaseDelay, max: retryMaxDelay)
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
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
        let redactedURL = Self.redactedURLString(url)

        var attempt = 0
        while true {
            let data: Data
            let httpResponse: HTTPURLResponse
            do {
                let (responseData, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse else {
                    throw SerpApiError.requestFailed("Invalid response type")
                }
                data = responseData
                httpResponse = http
            } catch let error as URLError {
                // A cancelled request must propagate as cancellation, never be retried or wrapped.
                if error.code == .cancelled {
                    throw CancellationError()
                }
                if attempt < maxRetries, Self.isRetryable(urlError: error) {
                    try await sleepBeforeRetry(attempt: attempt, retryAfter: nil)
                    attempt += 1
                    continue
                }
                throw SerpApiError.requestFailed(
                    "HTTP request failed with network error: \(error.localizedDescription) on get url: \(redactedURL)"
                )
            }

            let status = httpResponse.statusCode

            // Retry transient HTTP status codes while attempts remain, honoring Retry-After.
            if status != Self.httpStatusCodeSuccess,
               attempt < maxRetries,
               Self.isRetryable(status: status) {
                let retryAfter = httpResponse.value(forHTTPHeaderField: Self.headerRetryAfter)
                    .flatMap(Self.parseRetryAfter)
                try await sleepBeforeRetry(attempt: attempt, retryAfter: retryAfter)
                attempt += 1
                continue
            }

            return try decode(data: data, status: status, decoder: decoder, redactedURL: redactedURL)
        }
    }

    private func decode(data: Data, status: Int, decoder: DecoderType, redactedURL: String) throws -> Any {
        switch decoder {
        case .json:
            if status != Self.httpStatusCodeSuccess {
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    if let dict = json as? [String: Any] {
                        if let error = dict["error"] as? String {
                            throw SerpApiError.requestFailed(
                                "HTTP request failed with error: \(error) from url: \(redactedURL), response status: \(status)"
                            )
                        }
                        throw SerpApiError.requestFailed(
                            "HTTP request failed with response status: \(status) response: \(dict) on get url: \(redactedURL)"
                        )
                    }
                    throw SerpApiError.requestFailed(
                        "HTTP request failed with response status: \(status) on get url: \(redactedURL)"
                    )
                } catch is CancellationError {
                    throw SerpApiError.cancellationError
                } catch let error as SerpApiError {
                    throw error
                } catch {
                    let body = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "<non-utf8 body>"
                    let preview = String(body.prefix(500))
                    throw SerpApiError.requestFailed(
                        "HTTP request failed with response status: \(status) body: \(preview) on get url: \(redactedURL)"
                    )
                }
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                return json
            } catch is CancellationError {
                throw SerpApiError.cancellationError
            } catch {
                if let decodingError = error as? SerpApiError {
                    throw decodingError
                }
                throw SerpApiError.jsonParseError(
                    "JSON parse error: \(error.localizedDescription) on get url: \(redactedURL), response status: \(status)"
                )
            }
        case .html:
            if status != Self.httpStatusCodeSuccess {
                throw SerpApiError.requestFailed(
                    "HTTP request failed with response status: \(status) on get url: \(redactedURL)"
                )
            }
            guard let html = String(data: data, encoding: .utf8) else {
                throw SerpApiError.htmlParseError("Failed to decode HTML as UTF-8 from url: \(redactedURL)")
            }
            return html
        }
    }
}
