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
}
