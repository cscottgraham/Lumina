import Foundation
import CoreLocation

/// One-shot location snapshot for item provenance metadata ("captured at …").
/// Requests when-in-use authorization on first use; returns nil if the user
/// declines or the fix fails — capture never blocks on location.
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    struct Snapshot: Sendable {
        let latitude: Double
        let longitude: Double
        let placeName: String?
    }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Current location + reverse-geocoded place name ("Brockville, ON"), or nil.
    func snapshot() async -> Snapshot? {
        guard let location = await requestLocation() else { return nil }
        var name: String?
        if let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first {
            name = [placemark.locality, placemark.administrativeArea]
                .compactMap { $0 }.joined(separator: ", ")
            if name?.isEmpty == true { name = placemark.name }
        }
        return Snapshot(latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        placeName: name)
    }

    private func requestLocation() async -> CLLocation? {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            return nil
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
        return await withCheckedContinuation { cont in
            // If a request is already in flight, fail the old one gracefully.
            continuation?.resume(returning: nil)
            continuation = cont
            manager.requestLocation()
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations.first)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // After the user answers the permission prompt, retry the pending fix.
        if manager.authorizationStatus == .authorizedWhenInUse
            || manager.authorizationStatus == .authorizedAlways {
            if continuation != nil { manager.requestLocation() }
        } else if manager.authorizationStatus == .denied {
            continuation?.resume(returning: nil)
            continuation = nil
        }
    }
}
