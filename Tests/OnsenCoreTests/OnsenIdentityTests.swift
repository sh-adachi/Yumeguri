import XCTest
@testable import OnsenCore

final class OnsenIdentityTests: XCTestCase {
    func testCatalogAndMapLandmarkShareAnIdentity() {
        let catalog = OnsenCatalog.spots[0]
        let mapResult = OnsenSpot(id: "map-yubatake", name: "湯畑", address: "群馬県草津町草津", latitude: catalog.latitude + 0.0001, longitude: catalog.longitude)
        XCTAssertTrue(catalog.representsSamePlace(as: mapResult))
        XCTAssertTrue(mapResult.representsSamePlace(as: catalog))
    }

    func testEqualNamesAtDifferentLocationsRemainSeparate() {
        let first = OnsenSpot(id: "a", name: "金の湯", address: "", latitude: 35, longitude: 139)
        let other = OnsenSpot(id: "b", name: "金の湯", address: "", latitude: 36, longitude: 139)
        XCTAssertFalse(first.representsSamePlace(as: other))
    }

    func testGenericTownSuffixDoesNotMergeDistinctDestinations() {
        let first = OnsenSpot(id: "a", name: "箱根湯本温泉・温泉街", address: "", latitude: 35, longitude: 139)
        let other = OnsenSpot(id: "b", name: "黒川温泉・温泉街", address: "", latitude: 35, longitude: 139)
        XCTAssertFalse(first.representsSamePlace(as: other))
    }
}
