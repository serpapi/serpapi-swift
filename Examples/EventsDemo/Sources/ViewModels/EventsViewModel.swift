import Foundation
import SerpApi
import CoreLocation
import SwiftUI

@MainActor
class EventsViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @AppStorage("serpapi_key") var apiKey: String = ""
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedLocation: String = "Austin, TX"
    @Published var useCurrentLocation = true
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    
    // Filters
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date()
    
    private let locationManager = CLLocationManager()
    private var geocoder = CLGeocoder()
    
    override init() {
        super.init()
        locationManager.delegate = self
        setupDefaultDates()
    }
    
    func setupDefaultDates() {
        // Set default to next weekend
        let calendar = Calendar.current
        let today = Date()
        
        // Find next Saturday
        // 1 = Sunday, 7 = Saturday
        let weekday = calendar.component(.weekday, from: today)
        let daysToSaturday = (7 - weekday + 7) % 7
        // If today is Saturday, next Saturday is +7 days, otherwise it's later this week
        let nextSaturday = calendar.date(byAdding: .day, value: daysToSaturday == 0 ? 7 : daysToSaturday, to: today)!
        let nextSunday = calendar.date(byAdding: .day, value: 1, to: nextSaturday)!
        
        self.startDate = nextSaturday
        self.endDate = nextSunday
    }
    
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            locationStatus = self.locationManager.authorizationStatus
            
            #if os(iOS)
            if locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways {
                self.locationManager.startUpdatingLocation()
            }
            #elseif os(macOS)
            if locationStatus == .authorizedAlways || locationStatus == .authorized {
                 self.locationManager.startUpdatingLocation()
            }
            #endif
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // manager.stopUpdatingLocation() // Unsafe to call on non-isolated manager if we want to be strict, but actually it's fine on the delegate thread.
        // However, better to do it on MainActor if possible or just use self.locationManager
        
        guard let location = locations.last else { return }
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.locationManager.stopUpdatingLocation()
            
            if useCurrentLocation {
                geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
                    guard let self = self else { return }
                    
                    if let place = placemarks?.first {
                        let city = place.locality ?? ""
                        let state = place.administrativeArea ?? ""
                        let locationString = !city.isEmpty ? "\(city), \(state)" : ""
                        
                        if !locationString.isEmpty {
                            Task { @MainActor in
                                self.selectedLocation = locationString
                            }
                        }
                    }
                }
            }
        }
    }
    
    func searchEvents() async {
        guard !apiKey.isEmpty else {
            errorMessage = "Please enter your SerpApi Key in Profile"
            return
        }
        
        isLoading = true
        errorMessage = nil
        events = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Construct query
        // Google Events uses parameters like htichips=date:next_week etc. or simply `q=Events in [Location] [Date]`
        // Or we can construct a search query.
        // Let's use `q=Events in [Location]` and use filters if available, or just append date to query.
        // A robust way is "Events in [Location] from [Start] to [End]"
        
        let dateString = "from \(dateFormatter.string(from: startDate)) to \(dateFormatter.string(from: endDate))"
        let query = "Events in \(selectedLocation) \(dateString)"
        
        let params: [String: String] = [
            "engine": "google_events",
            "q": query,
            "hl": "en",
            "gl": "us",
            "api_key": apiKey
        ]
        
        do {
            let client = SerpApiClient(params: params)
            let result = try await client.search()
            
            if let eventsData = result["events_results"] as? [[String: Any]] {
                self.events = eventsData.compactMap { Event(dict: $0) }
            } else {
                // Fallback: try reading "organic_results" if events_results is missing (unlikely for google_events engine)
                errorMessage = "No events found."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

struct Event: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let date: String
    let address: [String]
    let link: String?
    let image: String?
    let description: String?
    
    init(dict: [String: Any]) {
        self.title = dict["title"] as? String ?? "No Title"
        
        if let dateObj = dict["date"] as? [String: Any] {
            self.date = dateObj["when"] as? String ?? ""
        } else {
            self.date = ""
        }
        
        self.address = dict["address"] as? [String] ?? []
        self.link = dict["link"] as? String
        self.image = dict["image"] as? String
        self.description = dict["description"] as? String
    }
}
