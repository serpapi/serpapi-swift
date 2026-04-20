import SwiftUI

struct EventsListView: View {
    @ObservedObject var viewModel: EventsViewModel
    @State private var showingFilters = false
    
    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            if viewModel.events.isEmpty && !viewModel.isLoading {
                if #available(iOS 17.0, macOS 14.0, *) {
                    ContentUnavailableView("No Events Found", systemImage: "magnifyingglass", description: Text("Try searching for something else or change filters."))
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { Task { await viewModel.searchEvents() } }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            FiltersView(viewModel: viewModel)
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
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
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
                        .font(.caption)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
