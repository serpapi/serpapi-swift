import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Offline `URLProtocol` stub: records every request and answers with queued replies.
///
/// The last queued reply is repeated once the queue is drained, so a single reply
/// answers every retry.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    enum Reply {
        case http(status: Int, headers: [String: String], body: Data)
        case failure(URLError)

        static func json(_ body: String, status: Int = 200) -> Reply {
            .http(status: status, headers: ["Content-Type": "application/json; charset=utf-8"], body: Data(body.utf8))
        }

        static func text(_ body: String, contentType: String, status: Int = 200) -> Reply {
            .http(status: status, headers: ["Content-Type": contentType], body: Data(body.utf8))
        }
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var replies: [Reply] = []
    nonisolated(unsafe) private static var recorded: [URLRequest] = []

    /// Queue replies and forget previously recorded requests.
    static func stub(_ replies: Reply...) {
        lock.withLock {
            self.replies = replies
            recorded = []
        }
    }

    /// Requests received since the last `stub(_:)` call.
    static var requests: [URLRequest] {
        lock.withLock { recorded }
    }

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let reply: Reply? = Self.lock.withLock {
            Self.recorded.append(request)
            return Self.replies.count > 1 ? Self.replies.removeFirst() : Self.replies.first
        }
        switch reply {
        case let .http(status, headers, body):
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        case nil:
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
        }
    }

    override func stopLoading() {}
}
