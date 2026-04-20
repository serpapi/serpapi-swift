import SwiftUI
import CoreLocation

struct FiltersView: View {
    @ObservedObject var viewModel: EventsViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Location") {
                    Toggle("Use Current Location", isOn: $viewModel.useCurrentLocation)
                        .onChange(of: viewModel.useCurrentLocation) { newValue in
                            if newValue {
                                viewModel.requestLocation()
                            }
                        }
                    
                    if !viewModel.useCurrentLocation {
                        TextField("City, State (e.g. Austin, TX)", text: $viewModel.selectedLocation)
                            .border(Color.secondary.opacity(0.3))
                    } else {
                        // Display current lat/long or geocoded location
                        if viewModel.selectedLocation.isEmpty {
                            Text("Getting location...")
                                .foregroundColor(.secondary)
                        } else {
                            Text("Current: \(viewModel.selectedLocation)")
                        }
                    }
                }
                
                Section("Date Range") {
                    DatePicker("Start Date", selection: $viewModel.startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $viewModel.endDate, displayedComponents: .date)
                    
                    Button("Set to Next Weekend") {
                        viewModel.setupDefaultDates()
                    }
                }
                
                Section {
                    Button(action: {
                        dismiss()
                        Task {
                            await viewModel.searchEvents()
                        }
                    }) {
                        Label("Apply & Search", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Search Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
