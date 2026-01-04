# SerpApi Swift Library

[![SerpApi](https://img.shields.io/badge/SerpApi-Swift-blue)](https://serpapi.com)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange)](https://swift.org)

Integrate search data into your AI workflow, RAG / fine-tuning, or iOS/macOS application using this official wrapper for [SerpApi](https://serpapi.com).

SerpApi supports Google, Google Maps, Google Shopping, Baidu, Yandex, Yahoo, eBay, App Stores, and [more](https://serpapi.com).

Query a vast range of data at scale, including web search results, flight schedules, stock market data, news headlines, and [more](https://serpapi.com).

## Features

* **Persistent Connections**: Uses `URLSession` persistent connection pooling for faster response times (2x faster).
* **Async/Await**: Native Swift concurrency support for non-blocking operations.
* **Type-Safe**: Clean API design with error handling.
* **Extensive Documentation**: Easy to follow with real-world examples.

## Installation

### Swift Package Manager

Add the following to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/serpapi/serpapi-swift", from: "1.0.0")
]
```

Or add it via Xcode: `File > Add Packages...` and search for `https://github.com/serpapi/serpapi-swift`.

## Simple Usage

```swift
import SerpApi

// Initialize the client
let client = SerpApiClient(params: ["engine": "google", "api_key": "YOUR_API_KEY"])

// Perform a search
do {
    let results = try await client.search(params: ["q": "coffee"])
    print(results)
} catch {
    print(error)
}
```

The SerpApi key can be obtained from [serpapi.com/signup](https://serpapi.com/users/sign_up?plan=free).

## Advanced Usage

### Configuration

You can configure the client with default parameters that will be applied to every request.

```swift
let client = SerpApiClient(params: [
    "engine": "google",
    "api_key": ProcessInfo.processInfo.environment["SERPAPI_KEY"] ?? "",
    "timeout": "30",   // HTTP timeout in seconds (default: 120)
    "persistent": "true" // Keep socket open (default: true)
])

// Override specific parameters per request
let results = try await client.search(params: [
    "q": "Coffee",
    "location": "Austin, TX"
])
```

### Async Search (Non-blocking)

SerpApi supports non-blocking search submission via `async=true`. This allows you to submit a batch of searches and retrieve them later.

```swift
// Submit search with async=true
let response = try await client.search(params: ["q": "Tesla", "async": "true"])

if let searchMetadata = response["search_metadata"] as? [String: Any],
   let searchID = searchMetadata["id"] as? String {
    
    // Retrieve results later using the Search Archive API
    let archived = try await client.searchArchive(searchID: searchID)
    print(archived)
}
```

### HTML Output

Get the raw HTML from the search engine.

```swift
let html = try await client.html(params: ["q": "Coffee"])
print(html) // "<!doctype html>..."
```

## APIs Supported

### Location API

```swift
let locations = try await client.location(params: ["q": "Austin", "limit": "3"])
for location in locations {
    print(location["name"] ?? "")
}
```

### Search Archive API

Retrieve past search results (free of charge).

```swift
let results = try await client.searchArchive(searchID: "SEARCH_ID")
```

### Account API

Get your account information and usage.

```swift
let account = try await client.account()
print(account)
```

## Developer Guide

### Dependencies
Ruby and Rake must be installed to run the tests and demo, as well Swift via Xcode command line tools.

```bash
brew install ruby
```

### Tests

To run the tests, you need a SerpApi key set in your environment variables.

```bash
export SERPAPI_KEY="your_key"
rake test
```

### Demo

Run the demo application to see the library in action.

```bash
rake demo
```

### Documentation

Generate documentation using:

```bash
rake doc
```

For the full list of targets, run:

```bash
rake -T
```

## License

MIT License.
