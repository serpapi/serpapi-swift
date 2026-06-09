import XCTest
@testable import SerpApi

final class SerpApiTests: XCTestCase {
    
    var apiKey: String!
    
    override func setUp() {
        super.setUp()
        apiKey = ProcessInfo.processInfo.environment["SERPAPI_KEY"]
    }
    
    func testInitialization() {
        let params = [
            "api_key": "test_key",
            "engine": "google",
            "timeout": "30",
            "persistent": "false"
        ]
        let client = SerpApiClient(params: params)
        
        XCTAssertEqual(client.apiKey, "test_key")
        XCTAssertEqual(client.engine, "google")
        XCTAssertEqual(client.timeout, 30.0)
        XCTAssertEqual(client.persistent, false)
        // Check source param exists
        XCTAssertTrue(client.params["source"]?.starts(with: "serpapi-swift") ?? false)
    }
    
    func testDefaultParams() {
        let client = SerpApiClient()
        XCTAssertEqual(client.timeout, 120.0)
        XCTAssertEqual(client.persistent, true)
        XCTAssertNotNil(client.params["source"])
    }

    func testClientParamsDoNotIncludeClientSideOptions() {
        let client = SerpApiClient(params: [
            "api_key": "test_key",
            "engine": "google",
            "timeout": "30",
            "persistent": "false"
        ])

        XCTAssertNil(client.params["timeout"])
        XCTAssertNil(client.params["persistent"])
        XCTAssertEqual(client.params["api_key"], "test_key")
        XCTAssertEqual(client.params["engine"], "google")
    }

    func testRedactedURLStringMasksApiKey() throws {
        let url = try XCTUnwrap(URL(string: "https://serpapi.com/search?q=coffee&api_key=secret123&engine=google"))
        let redacted = SerpApiClient.redactedURLString(url)

        XCTAssertFalse(redacted.contains("secret123"))
        XCTAssertTrue(redacted.contains("api_key=REDACTED"))
        XCTAssertTrue(redacted.contains("q=coffee"))
    }
    
    // MARK: - Integration Tests
    
    func testSearch() async throws {
        try XCTSkipIf(apiKey == nil, "SERPAPI_KEY not set")
        
        let client = SerpApiClient(params: ["api_key": apiKey, "engine": "google"])
        let results = try await client.search(params: ["q": "Coffee", "location": "Austin, TX"])
        
        XCTAssertNotNil(results["search_metadata"])
        XCTAssertNotNil(results["organic_results"])
        
        if let organic = results["organic_results"] as? [[String: Any]] {
            XCTAssertGreaterThan(organic.count, 0)
        }
    }
    
    func testHtmlSearch() async throws {
        try XCTSkipIf(apiKey == nil, "SERPAPI_KEY not set")
        
        let client = SerpApiClient(params: ["api_key": apiKey, "engine": "google"])
        let html = try await client.html(params: ["q": "Coffee"])
        
        XCTAssertFalse(html.isEmpty)
        // Check for common HTML tags instead of strict doctype
        // Some engines might return partial HTML or just text depending on query/error
        // But for a successful google search it should be substantial
        XCTAssertGreaterThan(html.count, 100)
    }
    
    func testLocation() async throws {
        try XCTSkipIf(apiKey == nil, "SERPAPI_KEY not set")
        
        let client = SerpApiClient(params: ["api_key": apiKey])
        let locations = try await client.location(params: ["q": "Austin", "limit": "3"])
        
        XCTAssertGreaterThan(locations.count, 0)
        // Verify we found Austin, TX but don't hardcode ID which might change
        let austin = locations.first(where: { ($0["name"] as? String)?.contains("Austin") ?? false })
        XCTAssertNotNil(austin, "Should find Austin in locations")
    }
    
    func testAccount() async throws {
        try XCTSkipIf(apiKey == nil, "SERPAPI_KEY not set")
        
        let client = SerpApiClient(params: ["api_key": apiKey])
        let account = try await client.account()
        
        XCTAssertNotNil(account["account_email"])
        XCTAssertNotNil(account["api_key"])
    }
    
    func testSearchArchive() async throws {
        try XCTSkipIf(apiKey == nil, "SERPAPI_KEY not set")
        
        let client = SerpApiClient(params: ["api_key": apiKey, "engine": "google"])
        // First, perform a search to get an ID
        let search = try await client.search(params: ["q": "Coffee"])
        
        guard let metadata = search["search_metadata"] as? [String: Any],
              let searchID = metadata["id"] as? String else {
            XCTFail("Could not get search ID")
            return
        }
        
        // Retrieve archive
        let archive = try await client.searchArchive(searchID: searchID)
        
        guard let archiveDict = archive as? [String: Any] else {
            XCTFail("Archive result is not a dictionary")
            return
        }
        
        XCTAssertNotNil(archiveDict["search_metadata"])
    }
    
    func testInvalidKey() async {
        let client = SerpApiClient(params: ["api_key": "invalid_key", "engine": "google"])
        
        do {
            _ = try await client.search(params: ["q": "Coffee"])
            XCTFail("Should fail with invalid key")
        } catch let error as SerpApiError {
            // Expected error
             switch error {
             case .requestFailed(let msg):
                 XCTAssertTrue(msg.contains("Invalid API key") || msg.contains("401"), "Unexpected error message: \(msg)")
             default:
                 XCTFail("Unexpected error type: \(error)")
             }
        } catch {
             XCTFail("Unexpected error type: \(error)")
        }
    }

    func testErrorDescriptions() {
        let errors: [SerpApiError] = [
            .invalidParams("param error"),
            .requestFailed("request failed"),
            .jsonParseError("parse error"),
            .invalidDecoder("decoder error")
        ]
        
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }
    
    func testClientDescription() {
        // Test with long key
        let longKeyClient = SerpApiClient(params: ["api_key": "1234567890", "engine": "google"])
        let desc1 = String(describing: longKeyClient)
        XCTAssertTrue(desc1.contains("1234****7890"))
        XCTAssertTrue(desc1.contains("google"))
        
        // Test with short key
        let shortKeyClient = SerpApiClient(params: ["api_key": "123", "engine": "google"])
        let desc2 = String(describing: shortKeyClient)
        XCTAssertTrue(desc2.contains("****"))
        
        // Test with no key
        let noKeyClient = SerpApiClient(params: ["engine": "google"])
        let desc3 = String(describing: noKeyClient)
        XCTAssertTrue(desc3.contains("nil"))
    }
    
    func testInvalidArchiveFormat() async {
        let client = SerpApiClient()
        do {
            _ = try await client.searchArchive(searchID: "123", format: "xml")
            XCTFail("Should fail with invalid format")
        } catch let error as SerpApiError {
            switch error {
            case .invalidDecoder(let msg):
                XCTAssertEqual(msg, "format must be json or html")
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testHtmlError() async {
        // Trigger an error in HTML mode (e.g. 401 with invalid key)
        let client = SerpApiClient(params: ["api_key": "invalid_key", "engine": "google"])
        do {
            _ = try await client.html(params: ["q": "Coffee"])
            XCTFail("Should fail with invalid key")
        } catch let error as SerpApiError {
            switch error {
            case .requestFailed(let msg):
                XCTAssertTrue(msg.contains("401"), "Should be a request failure with 401: \(msg)")
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
             XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSessionCleanup() {
        // Test that close() properly invalidates the session
        let client = SerpApiClient(params: ["api_key": "test_key"])
        // Call close to invalidate the session
        client.close()
        // If this doesn't crash, the invalidation worked
        // Note: deinit will also call invalidateAndCancel() automatically
    }

    func testMultipleClientsCleanup() {
        // Create and deallocate multiple clients to ensure cleanup doesn't leak resources
        for _ in 0..<10 {
            let client = SerpApiClient(params: ["api_key": "test_key"])
            // Explicit cleanup
            client.close()
        }
        // No crashes or resource exhaustion should occur
    }

    func testDeinitCleanup() {
        // Test that deinit automatically cleans up the session
        var client: SerpApiClient? = SerpApiClient(params: ["api_key": "test_key", "persistent": "true"])
        XCTAssertNotNil(client)
        // When client goes out of scope and is deallocated, deinit will call invalidateAndCancel()
        client = nil
        // No crashes should occur during deallocation
    }

    func testCancellationErrorCase() {
        let error = SerpApiError.cancellationError
        XCTAssertEqual(error.errorDescription, "Request was cancelled")
    }

    func testCancellationErrorDescription() {
        let error = SerpApiError.cancellationError
        XCTAssertEqual(error.errorDescription, "Request was cancelled")
    }

    // MARK: - Retry / Backoff

    func testRetryConfigDefaults() {
        let client = SerpApiClient()
        XCTAssertEqual(client.maxRetries, 3)
        XCTAssertEqual(client.retryBaseDelay, 0.5)
        XCTAssertEqual(client.retryMaxDelay, 8.0)
    }

    func testRetryConfigCustom() {
        let client = SerpApiClient(params: [
            "max_retries": "5",
            "retry_base_delay": "1.5",
            "retry_max_delay": "30"
        ])
        XCTAssertEqual(client.maxRetries, 5)
        XCTAssertEqual(client.retryBaseDelay, 1.5)
        XCTAssertEqual(client.retryMaxDelay, 30)

        // Retry config is client-side only and must not leak into outgoing query params
        XCTAssertNil(client.params["max_retries"])
        XCTAssertNil(client.params["retry_base_delay"])
        XCTAssertNil(client.params["retry_max_delay"])
    }

    func testRetryConfigDisabledAndNegativeClamped() {
        XCTAssertEqual(SerpApiClient(params: ["max_retries": "0"]).maxRetries, 0)
        // Negative values are clamped to zero
        XCTAssertEqual(SerpApiClient(params: ["max_retries": "-5"]).maxRetries, 0)
    }

    func testIsRetryableStatus() {
        for code in [429, 500, 502, 503, 504] {
            XCTAssertTrue(SerpApiClient.isRetryable(status: code), "\(code) should be retryable")
        }
        for code in [200, 400, 401, 403, 404] {
            XCTAssertFalse(SerpApiClient.isRetryable(status: code), "\(code) should not be retryable")
        }
    }

    func testIsRetryableURLError() {
        for code: URLError.Code in [.timedOut, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed] {
            XCTAssertTrue(SerpApiClient.isRetryable(urlError: URLError(code)))
        }
        // Cancellation must never be retried
        XCTAssertFalse(SerpApiClient.isRetryable(urlError: URLError(.cancelled)))
        XCTAssertFalse(SerpApiClient.isRetryable(urlError: URLError(.badURL)))
    }

    func testBackoffDelayWithinBounds() {
        let base = 0.5
        let maxDelay = 8.0
        for attempt in 0..<6 {
            let delay = SerpApiClient.backoffDelay(attempt: attempt, base: base, max: maxDelay)
            let expectedCap = Swift.min(maxDelay, base * pow(2.0, Double(attempt)))
            XCTAssertGreaterThanOrEqual(delay, 0)
            XCTAssertLessThanOrEqual(delay, expectedCap)
        }
    }

    func testBackoffDelayCappedAtMax() {
        // A large attempt index must never exceed the configured ceiling
        for _ in 0..<50 {
            let delay = SerpApiClient.backoffDelay(attempt: 20, base: 0.5, max: 8.0)
            XCTAssertLessThanOrEqual(delay, 8.0)
        }
    }

    func testBackoffDelayZeroBaseIsZero() {
        XCTAssertEqual(SerpApiClient.backoffDelay(attempt: 3, base: 0, max: 8.0), 0)
    }

    func testParseRetryAfterSeconds() {
        XCTAssertEqual(SerpApiClient.parseRetryAfter("5"), 5)
        XCTAssertEqual(SerpApiClient.parseRetryAfter("  10  "), 10)
        XCTAssertEqual(SerpApiClient.parseRetryAfter("0"), 0)
        // Negative delta clamps to zero
        XCTAssertEqual(SerpApiClient.parseRetryAfter("-5"), 0)
    }

    func testParseRetryAfterHTTPDate() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        let header = formatter.string(from: Date().addingTimeInterval(120))
        let parsed = SerpApiClient.parseRetryAfter(header)
        XCTAssertNotNil(parsed)
        // ~120s minus a tiny elapsed amount
        XCTAssertGreaterThan(parsed ?? 0, 100)
        XCTAssertLessThanOrEqual(parsed ?? 0, 120)
    }

    func testParseRetryAfterInvalid() {
        XCTAssertNil(SerpApiClient.parseRetryAfter("not-a-date"))
        XCTAssertNil(SerpApiClient.parseRetryAfter(""))
    }
}
