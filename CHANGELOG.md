# Changelog

All notable changes to this project are documented in this file.

## [1.1.0] - Unreleased

### Added

- `md(params:)` returns the search results as Markdown (`output=md`), for LLM / RAG pipelines.
- `searchArchive(searchID:format:)` accepts `format: "md"` (`/searches/{id}.md`).
- HTML and Markdown errors now include the SerpApi `error` message from the JSON error body,
  e.g. `Invalid API key`, or a truncated preview of a non-JSON body.
  Previously `html()` and archive HTML only reported the status code.

### Behavior changes

- `html(params:)` now really sends `output=html` and returns the engine's HTML.
  It previously sent no `output` param and returned the JSON response as text.
- `search(params:)` always sends `output=json`, even when `output` is set in the constructor or per call.
  The constructor params are not mutated.
- `searchArchive(searchID:format:)` percent-encodes the search id as a single path segment,
  so characters such as `/`, `?` and `#` can no longer change the request path or query.
- `searchArchive(searchID:format:)` sends `output=<format>`, so an `output` set in the constructor
  no longer overrides the requested format (SerpApi honors `output` over the path extension).
- `html()`, `md()` and archive HTML / Markdown raise `SerpApiError.requestFailed` when a 200 response
  is a JSON body carrying an `error` message, instead of returning that JSON as text.
- Errors for non-2xx JSON responses without an `error` field show a truncated preview of the raw body.
- `SerpApiError.htmlParseError` describes itself as `Response decode error: ...`, since it also covers Markdown.

### Internal

- SwiftLint 0.65.1 runs in strict mode in a separate CI job and in the default `rake` pipeline.
  The CI download is checksum-verified.
- CI test failures are no longer ignored, and the coverage report reads the right test binary.

## [1.0.0] - 2026-06-08

- Initial release: `search`, `html`, `location`, `account` and `searchArchive` with Swift async/await,
  persistent `URLSession` connections, configurable timeout, automatic retries with exponential backoff,
  and API key redaction in error messages.
