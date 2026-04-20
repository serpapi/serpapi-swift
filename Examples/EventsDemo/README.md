# EventsDemo App

This is a SwiftUI application demonstrating how to use SerpApi to search for local events.

## Prerequisites

- Xcode 13.0 or later
- A SerpApi API Key (you can get one at [serpapi.com](https://serpapi.com))

## How to Run

1. Open the `Package.swift` file in Xcode.
   ```bash
   open Package.swift
   ```
2. In Xcode, select the `EventsDemo` scheme from the toolbar.
3. Select an iOS Simulator (e.g., iPhone 15 Pro) as the destination.
4. Press `Cmd + R` to run.

## Features

- **Profile**: Enter and save your SerpApi Key.
- **Events**: View local events with images, dates, and locations.
- **Filters**:
  - **Location**: Use GPS (default) or manually enter a city (e.g., "Paris, France").
  - **Date Range**: Select custom dates or use the "Next Weekend" shortcut.

## Notes

- The app uses `CLLocationManager` for GPS. On the simulator, you can simulate location via `Features > Location`.
- API Requests are made to `serpapi.com` using the `google_events` engine.
