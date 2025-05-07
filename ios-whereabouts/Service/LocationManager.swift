import Foundation
import CoreLocation

struct CountryVisit: Identifiable {
    let id = UUID()
    let countryCode: String
    let countryName: String
    let timestamp: Date
    let coordinates: CLLocationCoordinate2D
}

final class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    @Published var latestVisit: CountryVisit?
    
    private var lastCountryCode: String?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
#if !targetEnvironment(simulator)
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
#endif
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestAlwaysAuthorization()
    }
    
    func startTracking() {
        locationManager.startMonitoringSignificantLocationChanges()
    }
    
    func fetchCurrentLocationOnce() {
        locationManager.requestLocation() // Triggers one update only
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get one-time location: \(error.localizedDescription)")
    }
    
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let now = Date()
        
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, error in
            guard
                let self = self,
                let placemark = placemarks?.first,
                let country = placemark.country,
                let code = placemark.isoCountryCode
            else { return }
            
            let visit = CountryVisit(
                countryCode: code,
                countryName: country,
                timestamp: now,
                coordinates: loc.coordinate
            )
            
            DispatchQueue.main.async {
                self.latestVisit = visit
            }
            
            let store = VisitStore.shared
            
            let newEntity = CountryVisitEntity(context: store.container.viewContext)
            newEntity.id               = visit.id
            newEntity.countryCode      = visit.countryCode
            newEntity.countryName      = visit.countryName
            newEntity.latitude         = visit.coordinates.latitude
            newEntity.longitude        = visit.coordinates.longitude
            newEntity.startTimestamp   = now
            newEntity.endTimestamp     = nil
            
            // if we already have records
            if !store.visits.isEmpty {
                let lastVisit = store.visits.first!
                // only if country changed, start a new one
                if lastVisit.endTimestamp == nil {
                    if lastVisit.countryCode == code {
                        // still same country; no new record
                        return
                    } else {
                        // close the latest visit
                        lastVisit.endTimestamp = now
                        // create new entity with startTimestamp = now, endTimestamp = nil
                        do {
                            try store.container.viewContext.save()
                            store.fetchVisits()
                            print("Started visit in \(country) at \(now)")
                        } catch {
                            print("Failed saving visit: \(error)")
                        }
                        
                    }
                    
                }
            }
            else {
                do {
                    try store.container.viewContext.save()
                    store.fetchVisits()
                    print("Started visit in \(country) at \(now)")
                } catch {
                    print("Failed saving visit: \(error)")
                }
            }
            
        }
        
    }
    
}
