import Foundation
import XCTest
@testable import OnsenCore

final class OnsenCoreTests: XCTestCase {
    private var directory: URL!
    private var repository: RecordRepository!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("YumeguriTests-\(UUID().uuidString)", isDirectory: true)
        repository = RecordRepository(fileURL: directory.appendingPathComponent("nested/records.json"))
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func testNewRepositoryStartsEmptyWithoutCreatingFile() throws {
        XCTAssertEqual(try repository.load(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.fileURL.path))
    }

    func testRoundTripRetainsUnicodeMetadataDatesAndStableIdentity() throws {
        let time = Date(timeIntervalSince1970: 1_750_000_000.125)
        let spot = OnsenSpot(
            id: "日本語-id-♨️", name: "湯の里「やすらぎ」", address: "東京都・テスト町",
            latitude: 35.6, longitude: 139.7, phoneNumber: "03-1234-5678",
            websiteURL: URL(string: "https://example.com/onsen?q=water")
        )
        let records = [OnsenRecord(
            spot: spot, status: .visited, rating: .good, visitedOn: time,
            memo: "雨の日に訪問。\n露天風呂が良かった ♨️\n\"また行きたい\"",
            createdAt: time, updatedAt: time.addingTimeInterval(1.5)
        )]
        try repository.save(records)
        let reloaded = try RecordRepository(fileURL: repository.fileURL).load()
        XCTAssertEqual(reloaded, records)
        XCTAssertEqual(reloaded.first?.id, spot.id)
    }

    func testChangingToWantToGoClearsRatingAndVisitDateButKeepsMemoAndIdentity() {
        var record = visitedRecord()
        let originalID = record.id
        record.status = .wantToGo
        XCTAssertNil(record.rating)
        XCTAssertNil(record.visitedOn)
        XCTAssertEqual(record.memo, "また行きたい")
        XCTAssertEqual(record.id, originalID)
    }

    func testWantToGoInitializerIgnoresVisitOnlyFields() {
        let record = OnsenRecord(spot: OnsenCatalog.spots[0], rating: .bad, visitedOn: Date())
        XCTAssertNil(record.rating)
        XCTAssertNil(record.visitedOn)
        XCTAssertEqual(record.updatedAt, record.createdAt)
    }

    func testSaveNormalizesFieldsAssignedAfterStatusChange() throws {
        var record = visitedRecord()
        record.status = .wantToGo
        record.rating = .good
        record.visitedOn = Date()
        try repository.save([record])
        let reloaded = try XCTUnwrap(repository.load().first)
        XCTAssertEqual(reloaded.status, .wantToGo)
        XCTAssertNil(reloaded.rating)
        XCTAssertNil(reloaded.visitedOn)
    }

    func testImportNormalizesInconsistentWantToGoData() throws {
        var record = visitedRecord()
        record.status = .wantToGo
        record.rating = .bad
        record.visitedOn = Date()
        let data = try JSONEncoder().encode([record])
        try FileManager.default.createDirectory(
            at: repository.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: repository.fileURL)
        let reloaded = try XCTUnwrap(repository.load().first)
        XCTAssertNil(reloaded.rating)
        XCTAssertNil(reloaded.visitedOn)
    }

    func testCorruptDataThrowsAndCannotBeSilentlyOverwritten() throws {
        try repository.save([visitedRecord()])
        let corrupt = Data("{broken UTF-8 日本語".utf8)
        try corrupt.write(to: repository.fileURL)
        XCTAssertThrowsError(try repository.load())
        XCTAssertThrowsError(try repository.save([]))
        XCTAssertEqual(try Data(contentsOf: repository.fileURL), corrupt)
    }

    func testDuplicateIDsRejectSaveAndRetainExistingRecords() throws {
        let record = visitedRecord()
        try repository.save([record])
        XCTAssertThrowsError(try repository.save([record, record])) { error in
            XCTAssertEqual(error as? RepositoryError, .duplicateIdentifier(record.id))
        }
        XCTAssertEqual(try repository.load(), [record])
    }

    func testInvalidCoordinatesRejectSaveAndRetainExistingRecords() throws {
        let valid = visitedRecord()
        try repository.save([valid])
        var invalid = valid
        invalid.spot.latitude = 91
        XCTAssertThrowsError(try repository.save([invalid]))
        invalid.spot.latitude = .nan
        XCTAssertThrowsError(try repository.save([invalid]))
        XCTAssertEqual(try repository.load(), [valid])
    }

    func testFileAsParentDirectoryFailsWithoutDestroyingIt() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let blockingURL = directory.appendingPathComponent("blocked")
        let sentinel = Data("keep me".utf8)
        try sentinel.write(to: blockingURL)
        let blockedRepository = RecordRepository(fileURL: blockingURL.appendingPathComponent("records.json"))
        XCTAssertThrowsError(try blockedRepository.save([visitedRecord()]))
        XCTAssertEqual(try Data(contentsOf: blockingURL), sentinel)
    }

    func testSavingAnEmptyListPersistsDeletion() throws {
        try repository.save([visitedRecord()])
        try repository.save([])
        XCTAssertEqual(try repository.load(), [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: repository.fileURL.path))
    }

    func testCatalogHasUniqueValidDestinationsAndDoesNotPrepopulateRecords() throws {
        XCTAssertEqual(OnsenCatalog.spots.count, 10)
        XCTAssertEqual(Set(OnsenCatalog.spots.map(\.id)).count, OnsenCatalog.spots.count)
        let samples = OnsenCatalog.spots.map { OnsenRecord(spot: $0) }
        try repository.save(samples)
        XCTAssertEqual(try repository.load(), samples)
        XCTAssertTrue(samples.allSatisfy { $0.status == .wantToGo && $0.rating == nil })
    }

    private func visitedRecord() -> OnsenRecord {
        OnsenRecord(
            spot: OnsenCatalog.spots[0], status: .visited, rating: .good,
            visitedOn: Date(timeIntervalSince1970: 1_750_000_000), memo: "また行きたい"
        )
    }
}
