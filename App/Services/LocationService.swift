import CoreLocation
import Foundation
import Observation

/// A one-shot location request. Creating this service never asks for permission.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var coordinate: CLLocationCoordinate2D?
    private(set) var isLocating = false
    var errorMessage: String?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var locationRequestStarted = false
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.delegate = self
    }

    /// Call only in response to the user's current-location button.
    func requestLocation() {
        guard !isLocating else { return }
        errorMessage = nil
        coordinate = nil
        isLocating = true

        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            handleAuthorization(manager.authorizationStatus)
        }
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        guard isLocating else { return }

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            guard !locationRequestStarted else { return }
            locationRequestStarted = true
            manager.requestLocation()
            timeoutTask?.cancel()
            timeoutTask = Task { [weak self] in
                do {
                    try await Task.sleep(for: .seconds(20))
                } catch {
                    return
                }
                guard let self, self.isLocating else { return }
                self.finish(error: "現在地を取得できませんでした。地名で検索するか、少し待って再度お試しください。")
            }
        case .denied:
            finish(error: "位置情報の利用が許可されていません。設定アプリで許可するか、地名で温泉を検索してください。")
        case .restricted:
            finish(error: "この端末では位置情報の利用が制限されています。地名で温泉を検索してください。")
        case .notDetermined:
            break
        @unknown default:
            finish(error: "現在地を利用できません。地名で温泉を検索してください。")
        }
    }

    private func finish(error: String? = nil) {
        timeoutTask?.cancel()
        timeoutTask = nil
        manager.stopUpdatingLocation()
        locationRequestStarted = false
        isLocating = false
        errorMessage = error
    }

    // Delegate callbacks can arrive outside Swift's actor isolation. Only small,
    // copied values cross into the main actor; UI state always changes there.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.handleAuthorization(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latestCoordinate = locations.last(where: {
            $0.horizontalAccuracy >= 0 &&
            CLLocationCoordinate2DIsValid($0.coordinate) &&
            abs($0.timestamp.timeIntervalSinceNow) < 60
        })?.coordinate

        Task { @MainActor [weak self] in
            guard let self, self.isLocating else { return }
            guard let latestCoordinate else {
                self.finish(error: "現在地を取得できませんでした。地名で検索するか、もう一度お試しください。")
                return
            }
            self.coordinate = latestCoordinate
            self.finish()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsError = error as NSError
        let denied = nsError.domain == kCLErrorDomain && nsError.code == CLError.denied.rawValue
        Task { @MainActor [weak self] in
            guard let self, self.isLocating else { return }
            self.finish(error: denied
                ? "位置情報を利用できません。設定アプリで位置情報を確認するか、地名で検索してください。"
                : "現在地を取得できませんでした。地名で検索するか、少し待って再度お試しください。")
        }
    }
}
