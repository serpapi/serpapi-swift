import XCTest
@testable import SerpApi

/// Offline tests: request construction and response handling against a stubbed network layer.
final class RequestTests: XCTestCase {

    private let secret = "secret_key_123"

    private func makeClient(_ params: [String: String] = [:]) -> SerpApiClient {
        var all = ["api_key": secret, "engine": "google", "max_retries": "0", "retry_base_delay": "0"]
        all.merge(params) { _, new in new }
        return SerpApiClient(params: all, protocolClasses: [StubURLProtocol.self])
    }

    private var lastRequest: URLRequest? {
        StubURLProtocol.requests.last
    }

    private var lastPath: String? {
        lastRequest?.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.percentEncodedPath }
    }

    private var lastQuery: [String: String] {
        guard let url = lastRequest?.url,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            return [:]
        }
        return Dictionary(items.map { ($0.name, $0.value ?? "") }) { first, _ in first }
    }

    /// Run `body`, expect a `SerpApiError.requestFailed` and return its message.
    private func requestFailedMessage(_ body: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async -> String {
        do {
            try await body()
            XCTFail("Expected requestFailed", file: file, line: line)
        } catch SerpApiError.requestFailed(let message) {
            return message
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
        return ""
    }

    // MARK: - Request construction

    func testSearchSendsOutputJsonAndSource() async throws {
        StubURLProtocol.stub(.json(#"{"search_metadata": {"id": "1"}}"#))
        let results = try await makeClient(["timeout": "30", "persistent": "false"]).search(params: ["q": "coffee"])

        XCTAssertNotNil(results["search_metadata"])
        XCTAssertEqual(lastRequest?.httpMethod, "GET")
        XCTAssertEqual(lastRequest?.url?.host, "serpapi.com")
        XCTAssertEqual(lastPath, "/search")
        XCTAssertEqual(lastQuery["output"], "json")
        XCTAssertEqual(lastQuery["q"], "coffee")
        XCTAssertEqual(lastQuery["engine"], "google")
        XCTAssertEqual(lastQuery["api_key"], secret)
        XCTAssertEqual(lastQuery["source"], "serpapi-swift:\(SerpApi.version)")
        // client-only params never reach the API
        for key in ["timeout", "persistent", "max_retries", "retry_base_delay", "retry_max_delay"] {
            XCTAssertNil(lastQuery[key], "\(key) must not be sent")
        }
    }

    func testSearchForcesOutputJsonWithoutMutatingDefaults() async throws {
        StubURLProtocol.stub(.json("{}"))
        let client = makeClient(["output": "html"])
        _ = try await client.search(params: ["q": "coffee", "output": "md"])

        XCTAssertEqual(lastQuery["output"], "json")
        XCTAssertEqual(client.params["output"], "html")
    }

    func testPerCallParamsOverrideDefaults() async throws {
        StubURLProtocol.stub(.json("{}"))
        let client = makeClient(["q": "tea"])
        _ = try await client.search(params: ["q": "coffee", "engine": "bing"])

        XCTAssertEqual(lastQuery["q"], "coffee")
        XCTAssertEqual(lastQuery["engine"], "bing")
        XCTAssertEqual(client.params["q"], "tea")
        XCTAssertEqual(client.params["engine"], "google")
    }

    func testCustomSourceIsKept() async throws {
        StubURLProtocol.stub(.json("{}"))
        _ = try await makeClient(["source": "my-app"]).search()
        XCTAssertEqual(lastQuery["source"], "my-app")
    }

    func testHtmlSendsOutputHtml() async throws {
        StubURLProtocol.stub(.text("<html>coffee</html>", contentType: "text/html; charset=utf-8"))
        let html = try await makeClient().html(params: ["q": "coffee"])

        XCTAssertEqual(html, "<html>coffee</html>")
        XCTAssertEqual(lastPath, "/search")
        XCTAssertEqual(lastQuery["output"], "html")
        XCTAssertEqual(lastQuery["q"], "coffee")
    }

    func testMdSendsOutputMd() async throws {
        StubURLProtocol.stub(.text("---\nsearch_metadata:\n", contentType: "text/markdown; charset=utf-8"))
        let md = try await makeClient().md(params: ["q": "coffee"])

        XCTAssertEqual(md, "---\nsearch_metadata:\n")
        XCTAssertEqual(lastPath, "/search")
        XCTAssertEqual(lastQuery["output"], "md")
        XCTAssertEqual(lastQuery["q"], "coffee")
    }

    func testMdOverridesCallerOutput() async throws {
        StubURLProtocol.stub(.text("# md", contentType: "text/markdown"))
        let client = makeClient(["output": "html"])
        _ = try await client.md(params: ["q": "coffee", "output": "json"])

        XCTAssertEqual(lastQuery["output"], "md")
        XCTAssertEqual(client.params["output"], "html")
    }

    func testSearchArchivePaths() async throws {
        let client = makeClient()

        StubURLProtocol.stub(.json(#"{"search_metadata": {"id": "abc123"}}"#))
        let json = try await client.searchArchive(searchID: "abc123")
        XCTAssertEqual(lastPath, "/searches/abc123.json")
        XCTAssertNotNil((json as? [String: Any])?["search_metadata"])

        StubURLProtocol.stub(.text("<html></html>", contentType: "text/html"))
        let html = try await client.searchArchive(searchID: "abc123", format: "html")
        XCTAssertEqual(lastPath, "/searches/abc123.html")
        XCTAssertEqual(html as? String, "<html></html>")

        StubURLProtocol.stub(.text("---\n", contentType: "text/markdown"))
        let md = try await client.searchArchive(searchID: "abc123", format: "md")
        XCTAssertEqual(lastPath, "/searches/abc123.md")
        XCTAssertEqual(md as? String, "---\n")

        XCTAssertNil(lastQuery["output"])
        XCTAssertEqual(lastQuery["api_key"], secret)
        XCTAssertEqual(lastQuery["source"], "serpapi-swift:\(SerpApi.version)")
    }

    func testSearchArchiveEscapesID() async throws {
        let client = makeClient()
        let cases = [
            "abc?x=1": "/searches/abc%3Fx%3D1.json",
            "../account": "/searches/..%2Faccount.json",
            "a#b c%": "/searches/a%23b%20c%25.json"
        ]
        for (id, expectedPath) in cases {
            StubURLProtocol.stub(.json("{}"))
            _ = try await client.searchArchive(searchID: id)
            XCTAssertEqual(lastPath, expectedPath, "searchID \(id)")
            XCTAssertNil(lastQuery["x"], "searchID \(id) must not add query params")
            XCTAssertNil(lastRequest?.url?.fragment, "searchID \(id) must not add a fragment")
        }
    }

    func testLocationRequest() async throws {
        StubURLProtocol.stub(.json(#"[{"name": "Austin, TX"}]"#))
        let locations = try await makeClient().location(params: ["q": "Austin", "limit": "3"])

        XCTAssertEqual(locations.first?["name"] as? String, "Austin, TX")
        XCTAssertEqual(lastPath, "/locations.json")
        XCTAssertEqual(lastQuery["q"], "Austin")
        XCTAssertEqual(lastQuery["limit"], "3")
    }

    func testAccountRequest() async throws {
        let client = makeClient()

        StubURLProtocol.stub(.json(#"{"account_email": "a@b.c"}"#))
        let account = try await client.account()
        XCTAssertEqual(account["account_email"] as? String, "a@b.c")
        XCTAssertEqual(lastPath, "/account")
        XCTAssertEqual(lastQuery["api_key"], secret)

        _ = try await client.account(apiKey: "other_key")
        XCTAssertEqual(lastQuery["api_key"], "other_key")
    }

    func testUnexpectedJsonShapes() async {
        let client = makeClient()
        StubURLProtocol.stub(.json("[]"))
        await assertJsonParseError { _ = try await client.search() }
        await assertJsonParseError { _ = try await client.account() }
        StubURLProtocol.stub(.json("{}"))
        await assertJsonParseError { _ = try await client.location() }
    }

    private func assertJsonParseError(_ body: () async throws -> Void, line: UInt = #line) async {
        do {
            try await body()
            XCTFail("Expected jsonParseError", line: line)
        } catch SerpApiError.jsonParseError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)", line: line)
        }
    }

    // MARK: - Response handling

    func testNon2xxJsonErrorSurfacesApiMessage() async {
        let client = makeClient()
        let calls: [(String, () async throws -> Void)] = [
            ("search", { _ = try await client.search(params: ["q": "coffee"]) }),
            ("html", { _ = try await client.html(params: ["q": "coffee"]) }),
            ("md", { _ = try await client.md(params: ["q": "coffee"]) }),
            ("archive html", { _ = try await client.searchArchive(searchID: "abc", format: "html") }),
            ("archive md", { _ = try await client.searchArchive(searchID: "abc", format: "md") })
        ]
        for (name, call) in calls {
            StubURLProtocol.stub(.json(#"{"error": "Invalid API key. Your API key should be here"}"#, status: 401))
            let message = await requestFailedMessage(call)
            XCTAssertTrue(message.contains("Invalid API key"), "\(name): \(message)")
            XCTAssertTrue(message.contains("401"), "\(name): \(message)")
            XCTAssertTrue(message.contains("api_key=REDACTED"), "\(name): \(message)")
            XCTAssertFalse(message.contains(secret), "\(name) leaks the API key: \(message)")
        }
    }

    func testNon2xxNonJsonBodyIsTruncated() async {
        let body = "<html>" + String(repeating: "x", count: 1000) + "</html>"
        StubURLProtocol.stub(.text(body, contentType: "text/html", status: 404))
        let message = await requestFailedMessage { _ = try await self.makeClient().md() }

        XCTAssertTrue(message.contains("404"), message)
        XCTAssertTrue(message.contains("body: <html>xxx"), message)
        XCTAssertTrue(message.contains("..."), message)
        XCTAssertFalse(message.contains("</html>"), "body must be truncated: \(message)")
        XCTAssertTrue(message.contains("api_key=REDACTED"), message)
        XCTAssertFalse(message.contains(secret), message)
    }

    func testNon2xxJsonWithoutErrorShowsBody() async {
        StubURLProtocol.stub(.json(#"{"foo": "bar"}"#, status: 400))
        let message = await requestFailedMessage { _ = try await self.makeClient().search() }
        XCTAssertTrue(message.contains("400"), message)
        XCTAssertTrue(message.contains(#"{"foo": "bar"}"#), message)
    }

    func testNon2xxEmptyBody() async {
        StubURLProtocol.stub(.http(status: 403, headers: [:], body: Data()))
        let message = await requestFailedMessage { _ = try await self.makeClient().html() }
        XCTAssertTrue(message.hasPrefix("HTTP request failed with response status: 403 on get url: https://serpapi.com/search?"), message)
    }

    func testNon2xxNonUTF8Body() async {
        StubURLProtocol.stub(.http(status: 400, headers: [:], body: Data([0xFF, 0xFE])))
        let message = await requestFailedMessage { _ = try await self.makeClient().html() }
        XCTAssertTrue(message.contains("400 body: <non-UTF-8 body>"), message)
    }

    func testTextOutputWithJsonErrorOn200Throws() async {
        StubURLProtocol.stub(.json(#"{"error": "Unsupported engine"}"#))
        let message = await requestFailedMessage { _ = try await self.makeClient().md() }
        XCTAssertTrue(message.contains("Unsupported engine"), message)
    }

    func testTextOutputWithJsonWithoutErrorOn200ReturnsBody() async throws {
        StubURLProtocol.stub(.json(#"{"ok": true}"#))
        let text = try await makeClient().html()
        XCTAssertEqual(text, #"{"ok": true}"#)
    }

    func testTextOutputInvalidUTF8() async {
        StubURLProtocol.stub(.http(status: 200, headers: ["Content-Type": "text/markdown"], body: Data([0xFF, 0xFE, 0xFD])))
        do {
            _ = try await makeClient().md()
            XCTFail("Expected htmlParseError")
        } catch SerpApiError.htmlParseError(let message) {
            XCTAssertTrue(message.contains("Failed to decode response body as UTF-8"), message)
            XCTAssertFalse(message.contains(secret), message)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInvalidJsonBody() async {
        StubURLProtocol.stub(.text("not json", contentType: "text/plain"))
        do {
            _ = try await makeClient().search()
            XCTFail("Expected jsonParseError")
        } catch SerpApiError.jsonParseError(let message) {
            XCTAssertTrue(message.contains("api_key=REDACTED"), message)
            XCTAssertFalse(message.contains(secret), message)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Retries and network errors

    func testRetriesTransientStatusThenSucceeds() async throws {
        StubURLProtocol.stub(
            .http(status: 503, headers: ["Retry-After": "0.01"], body: Data()),
            .http(status: 429, headers: [:], body: Data()),
            .json(#"{"ok": true}"#)
        )
        let results = try await makeClient(["max_retries": "2", "retry_base_delay": "0.001"]).search()
        XCTAssertEqual(results["ok"] as? Bool, true)
        XCTAssertEqual(StubURLProtocol.requests.count, 3)
    }

    func testRetriesExhausted() async {
        StubURLProtocol.stub(.json(#"{"error": "Service unavailable"}"#, status: 503))
        let message = await requestFailedMessage { _ = try await self.makeClient(["max_retries": "1"]).search() }
        XCTAssertTrue(message.contains("Service unavailable"), message)
        XCTAssertTrue(message.contains("503"), message)
        XCTAssertEqual(StubURLProtocol.requests.count, 2)
    }

    func testClientErrorIsNotRetried() async {
        StubURLProtocol.stub(.json(#"{"error": "Invalid API key"}"#, status: 401))
        _ = await requestFailedMessage { _ = try await self.makeClient(["max_retries": "3"]).search() }
        XCTAssertEqual(StubURLProtocol.requests.count, 1)
    }

    func testTransientNetworkErrorRetriedThenFails() async {
        StubURLProtocol.stub(.failure(URLError(.timedOut)))
        let message = await requestFailedMessage { _ = try await self.makeClient(["max_retries": "1"]).search() }
        XCTAssertTrue(message.contains("network error"), message)
        XCTAssertTrue(message.contains("api_key=REDACTED"), message)
        XCTAssertFalse(message.contains(secret), message)
        XCTAssertEqual(StubURLProtocol.requests.count, 2)
    }

    func testNonTransientNetworkErrorIsNotRetried() async {
        StubURLProtocol.stub(.failure(URLError(.badServerResponse)))
        _ = await requestFailedMessage { _ = try await self.makeClient(["max_retries": "3"]).md() }
        XCTAssertEqual(StubURLProtocol.requests.count, 1)
    }

    func testCancelledRequestPropagatesCancellation() async {
        StubURLProtocol.stub(.failure(URLError(.cancelled)))
        do {
            _ = try await makeClient(["max_retries": "3"]).search()
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            XCTAssertEqual(StubURLProtocol.requests.count, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
