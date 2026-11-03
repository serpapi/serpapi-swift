# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Build the library
swift build

# Run tests (requires SERPAPI_KEY for integration tests)
# Note: must set DEVELOPER_DIR or XCTest won't be found
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

# Run tests for example apps
swift test --package-path Examples/Demo
swift test --package-path Examples/EventsDemo

# Run the CLI demo
swift run --package-path Examples/Demo

# Run the EventsDemo GUI (macOS)
swift run --package-path Examples/EventsDemo

# Lint
swiftlint

# Generate DocC documentation
swift package generate-documentation
```

Using Rake:
```bash
rake            # full pipeline: check, dependency, version, lint, build, test, oobt
rake build      # build library only
rake test       # run tests
rake lint       # swiftlint --strict (CI pins SwiftLint 0.65.1)
rake format     # swiftformat
rake demo       # run CLI demo
rake events     # run EventsDemo GUI
rake coverage   # test with coverage report (offline: env -u SERPAPI_KEY rake coverage)
rake tag        # create git tag from version in Version.swift
```

Integration tests require `SERPAPI_KEY` env var; they are skipped automatically when it is absent.
Offline tests in `Tests/SerpApiTests/RequestTests.swift` stub the network with `StubURLProtocol`, passed through the internal `init(params:protocolClasses:)`.

## Architecture

### Library (`Sources/SerpApi/`)

A single-file public API surface:

- **`SerpApiClient`** — the main class. Initialized with a `[String: String]` params dict. Client-side params (`timeout`, `persistent`, `max_retries`, `retry_base_delay`, `retry_max_delay`) are consumed by the constructor and stripped before being sent to the API. All requests go through the private `get(endpoint:decoder:params:)` method which merges constructor params with per-call overrides.
- **`SerpApiError`** — a `LocalizedError` enum with cases: `invalidParams`, `requestFailed`, `jsonParseError`, `invalidDecoder`, `htmlParseError`, `cancellationError`. Non-2xx responses raise `requestFailed` with the status, the redacted URL and SerpApi's JSON `error` message (or a truncated body preview).
- **`Version`** — a single `static let version` string injected as the `source` query param on every request.

Public API methods:
| Method | Endpoint | Returns |
|--------|----------|---------|
| `search(params:)` | `/search?output=json` | `[String: Any]` |
| `html(params:)` | `/search?output=html` | `String` |
| `md(params:)` | `/search?output=md` | `String` |
| `location(params:)` | `/locations.json` | `[[String: Any]]` |
| `account(apiKey:)` | `/account` | `[String: Any]` |
| `searchArchive(searchID:format:)` | `/searches/{id}.json\|html\|md` | `Any` |

### Examples (`Examples/`)

Each example is a standalone Swift package that depends on the local library via `path: "../../"`.

- **`Examples/Demo`** — CLI executable that exercises all six public API methods sequentially.
- **`Examples/EventsDemo`** — macOS/iOS SwiftUI app. Uses MVVM: `EventsViewModel` fetches Google Events results from SerpApi and exposes them to `ContentView`, `EventsListView`, `FiltersView`, and `ProfileView`. Theme constants live in `SerpApiTheme.swift`.

### Concurrency and networking

`SerpApiClient` uses `async/await` throughout. Session mode is controlled by the `persistent` param: `"true"` (default) uses `URLSessionConfiguration.default` for connection pooling; `"false"` uses `.ephemeral`. The `api_key` param is redacted from URLs in error messages via `redactedURLString(_:)`.
