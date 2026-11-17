import CoreLocation
import Foundation

/// Keeps LyricDash awake while the phone is locked.
///
/// iOS puts apps to sleep a few seconds after you lock the phone. It keeps an
/// app running while it has a location session open (this is how navigation
/// apps stay awake), and it also lets that app keep updating its lyrics card.
/// Playing silent sound keeps an app awake too, but iOS then refuses to
/// update the card, which is why lyrics used to freeze.
///
/// The session uses the cheapest accuracy (cell towers and Wi-Fi, no GPS).
/// The locations themselves are thrown away: never saved, never sent.
final class LocationKeepAlive: NSObject, CLLocationManagerDelegate {
    enum Status {
        case off
        case on
        case waitingForPermission
        case notAllowed
    }

    private let manager = CLLocationManager()
    private var session: CLBackgroundActivitySession?
    private var wanted = false
    private(set) var isRunning = false

    /// Called whenever permission or running state changes.
    var onChange: (() -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
    }

    var status: Status {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            return .notAllowed
        case .notDetermined:
            return wanted ? .waitingForPermission : .off
        default:
            return isRunning ? .on : .off
        }
    }

    /// Call while the app is on screen.
    func start() {
        wanted = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            begin()
        default:
            break
        }
        onChange?()
    }

    func stop() {
        wanted = false
        if isRunning {
            manager.stopUpdatingLocation()
        }
        isRunning = false
        session?.invalidate()
        session = nil
        onChange?()
    }

    private func begin() {
        guard wanted else { return }

        // Setting "allowsBackgroundLocationUpdates" without the matching
        // background mode would crash, so check the app was built with it.
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        guard modes.contains("location") else { return }

        // With "While Using the App" permission, iOS needs this session object
        // to let location continue once the phone is locked.
        let always = manager.authorizationStatus == .authorizedAlways
        if always {
            session?.invalidate()
            session = nil
        } else if session == nil {
            session = CLBackgroundActivitySession()
        }

        guard !isRunning else { return }
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = !always
        manager.startUpdatingLocation()
        isRunning = true
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            begin()
        } else if status == .denied || status == .restricted {
            if isRunning {
                manager.stopUpdatingLocation()
            }
            isRunning = false
            session?.invalidate()
            session = nil
        }
        onChange?()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Nothing to do. The locations are not used.
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Nothing to do. A failed reading doesn't matter; the session stays open.
    }
}
