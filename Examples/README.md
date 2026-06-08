# Examples

Two example apps demonstrating the SerpApi Swift library.

| Example | Type | Description |
|---------|------|-------------|
| [Demo](Demo/) | CLI (macOS) | Exercises all five public API methods sequentially |
| [EventsDemo](EventsDemo/) | SwiftUI GUI (macOS / iOS) | Browse local events using the Google Events engine |

Each example is a standalone Swift package that depends on the local library via `path: "../../"`.

## Requirements

- Xcode 15+ / Swift 6.2+
- A SerpApi API key — [sign up free](https://serpapi.com/users/sign_up?plan=free)
- Set the `SERPAPI_KEY` environment variable before running
