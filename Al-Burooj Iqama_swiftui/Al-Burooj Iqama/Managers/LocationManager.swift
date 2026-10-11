import Foundation
import CoreLocation
import Observation
import SwiftUI

@Observable
final class LocationManager: NSObject {
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var location: CLLocation?
    var heading: CLHeading?

    // Persisted coordinates — stored via AppStorage, not manual UserDefaults.
    @ObservationIgnored
    @AppStorage(LATT) var latitude: Double = 0
    @ObservationIgnored
    @AppStorage(LONG) var longitude: Double = 0
    @ObservationIgnored
    @AppStorage(CITY) var city: String = ""

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastGeocodedCoordinate: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter = kCLHeadingFilterNone
        manager.requestWhenInUseAuthorization()
    }

    /// Starts location and heading updates. Safe to call multiple times.
    func start() {
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    /// Stops location and heading updates.
    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self else { return }
            guard error == nil, let placemark = placemarks?.first else { return }

            let cityName = placemark.locality ?? placemark.administrativeArea ?? ""

            DispatchQueue.main.async {
                self.city = cityName
                self.lastGeocodedCoordinate = location.coordinate
            }
        }
    }

    private func shouldReverseGeocode(_ location: CLLocation) -> Bool {
        guard let lastGeocodedCoordinate else { return true }
        let lastLocation = CLLocation(latitude: lastGeocodedCoordinate.latitude,
                                      longitude: lastGeocodedCoordinate.longitude)
        // Re-geocode if moved more than 1000 meters.
        return location.distance(from: lastLocation) > 1000
    }
}

extension LocationManager: CLLocationManagerDelegate {
    // iOS 14 and later
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        authorizationStatus = status
        handleAuthorizationChange(status)
    }

    // iOS 13 and earlier
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        handleAuthorizationChange(status)
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            start()
        default:
            stop()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location

        // Update AppStorage-backed properties.
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude

        // Reverse geocode the city name, but avoid doing it on every update.
        if city.isEmpty || shouldReverseGeocode(location) {
            reverseGeocode(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let error = error as? CLError, error.code == .denied {
            authorizationStatus = .denied
            stop()
        }
    }
}
