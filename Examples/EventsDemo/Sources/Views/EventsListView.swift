import SwiftUI

struct EventsListView: View {
    @ObservedObject var viewModel: EventsViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(SerpApiTheme.danger)
                }
            }

            if viewModel.events.isEmpty && !viewModel.isLoading {
                if #available(iOS 17.0, macOS 14.0, *) {
                    ContentUnavailableView(
                        "No Events Found",
                        systemImage: "magnifyingglass",
                        description: Text("Try searching for something else or change filters.")
                    )
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                        Text("No Events Found")
                            .font(.headline)
                        Text("Try searching for something else or change filters.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
            
            ForEach(viewModel.events) { event in
                EventRowView(event: event)
            }
        }
        .refreshable {
            await viewModel.searchEvents()
        }
        .navigationTitle("Events")
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .applySerpListChrome(colorScheme: colorScheme)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.searchEvents() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
        .task {
            // Initial load if api key exists
            if !viewModel.apiKey.isEmpty && viewModel.events.isEmpty {
                await viewModel.searchEvents()
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.events.isEmpty {
                ProgressView("Searching events...")
                    .padding()
                    .background(
                        SerpApiTheme.cardBackground(for: colorScheme).opacity(0.95),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(SerpApiTheme.cardBorder(for: colorScheme), lineWidth: 1)
                    )
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func applySerpListChrome(colorScheme: ColorScheme) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            self
                .scrollContentBackground(.hidden)
                .background(SerpApiTheme.appBackground(for: colorScheme))
        } else {
            self.background(SerpApiTheme.appBackground(for: colorScheme))
        }
    }
}

struct EventRowView: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageURL = event.image, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image.resizable()
                         .aspectRatio(contentMode: .fill)
                         .frame(height: 150)
                         .clipped()
                         .cornerRadius(8)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 150)
                        .cornerRadius(8)
                }
            }
            
            Text(event.title)
                .font(.headline)
            
            HStack {
                Image(systemName: "calendar")
                Text(event.date)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            if !event.address.isEmpty {
                HStack(alignment: .top) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(event.address.joined(separator: ", "))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            if let link = event.link, let url = URL(string: link) {
                Link(destination: url) {
                    Text("View More")
                        .font(.caption.weight(.semibold))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                        .background(SerpApiTheme.accentBlue.opacity(0.14))
                        .foregroundStyle(SerpApiTheme.accentBlue)
                        .cornerRadius(12)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
