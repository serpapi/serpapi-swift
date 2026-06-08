# EventsDemo

A SwiftUI app (macOS and iOS) that searches for local events using the [Google Events engine](https://serpapi.com/google-events-api).

## Features

- Browse upcoming events by location and date range
- Uses device GPS to auto-detect current location (CoreLocation)
- API key stored persistently via `@AppStorage`
- Picks up `SERPAPI_KEY` from the environment on first launch if no key is saved

## Structure

```
Sources/
├── EventsApp.swift           # App entry point
├── SerpApiTheme.swift        # Brand colors and styling constants
├── WindowFrameAdjuster.swift # macOS window size helper
├── ViewModels/
│   └── EventsViewModel.swift # Fetches events, manages location & filters
└── Views/
    ├── ContentView.swift     # TabView root (Events + Profile tabs)
    ├── EventsListView.swift  # Event cards list
    ├── FiltersView.swift     # Date range and location filters
    └── ProfileView.swift     # API key entry
```

## Run

```bash
SERPAPI_KEY=your_key swift run --package-path Examples/EventsDemo
```

Or via Rake from the repo root:

```bash
SERPAPI_KEY=your_key rake events
```

To run in an iOS simulator:

```bash
rake ios
```

> On the simulator, set a location via `Features > Location` in the Simulator menu.

## Test

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Examples/EventsDemo
```
