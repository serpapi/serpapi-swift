import SwiftUI

struct ContentView: View {
    @AppStorage("serpapi_key") var apiKey: String = ""
    @StateObject private var viewModel = EventsViewModel()
    @State private var selection = 0
    @State private var didLoadDefaultKey = false
    
    var body: some View {
        TabView(selection: $selection) {
            eventsRootView
            .tabItem {
                Label("Events", systemImage: "calendar")
            }
            .tag(0)
            
            profileRootView
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
            .tag(1)
        }
        .onAppear {
            loadDefaultAPIKeyFromEnvironmentIfNeeded()
            if apiKey.isEmpty {
                selection = 1
            }
        }
    }

    private func loadDefaultAPIKeyFromEnvironmentIfNeeded() {
        guard !didLoadDefaultKey else { return }
        didLoadDefaultKey = true
        guard apiKey.isEmpty else { return }

        let envKey = ProcessInfo.processInfo.environment["SERPAPI_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !envKey.isEmpty {
            apiKey = envKey
        }
    }

    @ViewBuilder
    private var eventsRootView: some View {
        if #available(macOS 13.0, iOS 16.0, *) {
            NavigationStack {
                EventsListView(viewModel: viewModel)
            }
        } else {
            NavigationView {
                EventsListView(viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private var profileRootView: some View {
        if #available(macOS 13.0, iOS 16.0, *) {
            NavigationStack {
                ProfileView()
            }
        } else {
            NavigationView {
                ProfileView()
            }
        }
    }
}
