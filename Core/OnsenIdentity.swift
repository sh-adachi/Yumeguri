import Foundation

extension OnsenSpot {
    /// Recognizes an existing record when Maps uses a shorter landmark name.
    /// Matching requires both a meaningful shared name and nearby coordinates.
    public func representsSamePlace(as other: OnsenSpot) -> Bool {
        if id == other.id { return true }
        guard !identityNames.isDisjoint(with: other.identityNames) else { return false }
        let north = (latitude - other.latitude) * 111_320
        let east = (longitude - other.longitude) * 111_320 * cos((latitude + other.latitude) * .pi / 360)
        return hypot(north, east) <= 100
    }

    private var identityNames: Set<String> {
        func normalize(_ value: String) -> String {
            value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "ja_JP"))
                .components(separatedBy: .whitespacesAndNewlines).joined()
        }
        var names: Set<String> = [normalize(name)]
        let components = name.components(separatedBy: "・")
        if components.count > 1, let landmark = components.last,
           landmark.count >= 2, landmark != "温泉街" {
            names.insert(normalize(landmark))
        }
        names.remove("")
        return names
    }
}
