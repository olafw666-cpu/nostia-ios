import Combine
import Foundation
import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var permissionDenied = false

    private let manager = CLLocationManager()
    private var periodicTimer: Timer?
    private let syncInterval: TimeInterval = 600 // 10 minutes

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocationOnce() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            permissionDenied = true
        }
    }

    func startPeriodicSync() {
        requestLocationIfAuthorized()
        periodicTimer?.invalidate()
        let timer = Timer(timeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.requestLocationIfAuthorized() }
        }
        RunLoop.main.add(timer, forMode: .common)
        periodicTimer = timer
    }

    func stopPeriodicSync() {
        periodicTimer?.invalidate()
        periodicTimer = nil
    }

    private func requestLocationIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func startUpdating() {
        guard manager.authorizationStatus == .authorizedWhenInUse ||
              manager.authorizationStatus == .authorizedAlways else { return }
        manager.startUpdatingLocation()
    }

    /// In-context acquisition for "Start an adventure" (Product Definition v2
    /// §4.2): permission is asked at the moment it buys the user something —
    /// the tap that needs a location — never on a cold splash screen. Awaits a
    /// reasonably fresh fix; returns nil on denial or timeout so callers can
    /// degrade honestly (denied state has its own UI, never a silent failure).
    func acquireLocation(timeout: TimeInterval = 8) async -> CLLocation? {
        if let loc = location, loc.timestamp.timeIntervalSinceNow > -300 { return loc }
        requestLocationOnce() // asks permission if undetermined; the grant callback requests the fix
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if permissionDenied { return nil }
            if let loc = location, loc.timestamp.timeIntervalSinceNow > -300 { return loc }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return location // stale beats nothing for composing a nearby plan
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.location = loc
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.permissionDenied = false
                manager.requestLocation()
            case .denied, .restricted:
                self.permissionDenied = true
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
