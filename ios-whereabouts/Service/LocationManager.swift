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

        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, error in
            guard let self = self,
                  let placemark = placemarks?.first,
                  let country = placemark.country,
                  let code = placemark.isoCountryCode else { return }

            let visit = CountryVisit(
                countryCode: code,
                countryName: country,
                timestamp: Date(),
                coordinates: loc.coordinate
            )

            // update "current location" UI
            DispatchQueue.main.async {
                self.latestVisit = visit
            }

            // Only persist if the last saved country is different
            if let lastSaved = VisitStore.shared.visits.first,
               lastSaved.countryCode == code {
                return
            }

            // Save visit and update `lastCountryCode`
            DispatchQueue.main.async {
                self.lastCountryCode = code
                VisitStore.shared.saveVisit(from: visit)
                print("Logged visit: \(country) at \(visit.timestamp)")
            }
        }
    }

}
