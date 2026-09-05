import Foundation
import MapKit
import Observation

/// Searches Apple Maps without needing an account or a third-party API key.
@MainActor
@Observable
final class OnsenSearchService {
    private(set) var results: [OnsenSpot] = []
    private(set) var isSearching = false
    var errorMessage: String?

    @ObservationIgnored private var activeSearch: MKLocalSearch?
    @ObservationIgnored private var activeSearchID: UUID?

    func search(query: String, region: MKCoordinateRegion? = nil) async {
        // A task cancelled before it starts must not cancel a newer request.
        guard !Task.isCancelled else { return }
        cancel()
        results = []
        errorMessage = nil

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = Self.onsenQuery(query)
        request.resultTypes = [.pointOfInterest]
        if let region {
            request.region = region
        }

        let search = MKLocalSearch(request: request)
        let searchID = UUID()
        activeSearch = search
        activeSearchID = searchID
        isSearching = true

        defer {
            // An earlier response must never alter a newer search's state.
            if activeSearchID == searchID {
                activeSearch = nil
                activeSearchID = nil
                isSearching = false
            }
        }

        do {
            let response = try await withTaskCancellationHandler {
                try await search.start()
            } onCancel: {
                Task { @MainActor [weak self] in
                    guard self?.activeSearchID == searchID else { return }
                    self?.cancel()
                }
            }

            guard activeSearchID == searchID, !Task.isCancelled else { return }

            var seen = Set<String>()
            results = response.mapItems.compactMap { item in
                guard let spot = Self.spot(from: item), seen.insert(spot.id).inserted else {
                    return nil
                }
                return spot
            }
        } catch {
            guard activeSearchID == searchID, !Task.isCancelled else { return }
            if (error as NSError).domain == MKErrorDomain,
               (error as NSError).code == MKError.placemarkNotFound.rawValue {
                errorMessage = nil
            } else {
                errorMessage = "温泉を検索できませんでした。通信状況を確認して、もう一度お試しください。"
            }
        }
    }

    func cancel() {
        activeSearchID = nil
        activeSearch?.cancel()
        activeSearch = nil
        isSearching = false
    }

    private static func onsenQuery(_ query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "温泉" }
        let terms = ["温泉", "銭湯", "スパ", "湯", "onsen", "spa", "hot spring"]
        return terms.contains(where: trimmed.lowercased().contains) ? trimmed : "\(trimmed) 温泉"
    }

    private static func spot(from item: MKMapItem) -> OnsenSpot? {
        let coordinate = item.placemark.coordinate
        guard CLLocationCoordinate2DIsValid(coordinate),
              let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }

        // String hashing is randomly seeded by Swift. Use explicit, locale-independent
        // coordinates so a place keeps its identity after the app is restarted.
        let coordinateKey = String(
            format: "%.5f,%.5f",
            locale: Locale(identifier: "en_US_POSIX"),
            coordinate.latitude,
            coordinate.longitude
        )
        let nameKey = name.precomposedStringWithCanonicalMapping.lowercased()
        let components = [
            item.placemark.administrativeArea,
            item.placemark.locality,
            item.placemark.subLocality,
            item.placemark.thoroughfare,
            item.placemark.subThoroughfare
        ].compactMap { $0 }.filter { !$0.isEmpty }
        var seenComponents = Set<String>()
        let address = components.filter { seenComponents.insert($0).inserted }.joined()

        return OnsenSpot(
            id: "map:\(nameKey):\(coordinateKey)",
            name: name,
            address: address.isEmpty ? (item.placemark.title ?? "住所情報はありません") : address,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            phoneNumber: item.phoneNumber,
            websiteURL: item.url
        )
    }
}
