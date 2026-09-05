import Foundation
import XCTest
@testable import OnsenCore

final class PhotoRepositoryTests: XCTestCase {
    private var directory: URL!
    private var photos: PhotoRepository!
    private var records: RecordRepository!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("YumeguriPhotoTests-\(UUID().uuidString)", isDirectory: true)
        photos = PhotoRepository(directoryURL: directory.appendingPathComponent("Photos"))
        records = RecordRepository(fileURL: directory.appendingPathComponent("records.json"))
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func testExistingJSONWithoutPhotosLoadsAndSavesWithoutLosingRecord() throws {
        let original = OnsenRecord(spot: OnsenCatalog.spots[0], memo: "以前の記録")
        let encoded = try JSONEncoder().encode([original])
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [[String: Any]])
        legacy[0].removeValue(forKey: "photoIDs")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: legacy).write(to: records.fileURL)

        XCTAssertEqual(try records.load(), [original])
        try records.save(records.load())
        XCTAssertEqual(try records.load().first?.photoIDs, [])
    }

    func testPhotoOrderSurvivesRoundTripAndStatusChange() throws {
        let ids = [UUID().uuidString, UUID().uuidString, UUID().uuidString]
        var record = OnsenRecord(
            spot: OnsenCatalog.spots[0], status: .visited, rating: .good,
            visitedOn: Date(), memo: "露天風呂", photoIDs: ids
        )
        try records.save([record])
        XCTAssertEqual(try records.load(), [record])
        record.status = .wantToGo
        try records.save([record])
        let reloaded = try XCTUnwrap(records.load().first)
        XCTAssertEqual(reloaded.photoIDs, ids)
        XCTAssertNil(reloaded.rating)
        XCTAssertNil(reloaded.visitedOn)
    }

    func testInvalidDuplicateAndTooManyPhotoIDsRetainExistingRecord() throws {
        let original = OnsenRecord(spot: OnsenCatalog.spots[0])
        try records.save([original])
        let id = UUID().uuidString
        let cases: [[String]] = [
            ["../outside"], [id, id], [id, id.lowercased()],
            (0...PhotoRepository.maxPhotosPerRecord).map { _ in UUID().uuidString }
        ]
        for invalidIDs in cases {
            var invalid = original
            invalid.photoIDs = invalidIDs
            XCTAssertThrowsError(try records.save([invalid]))
            XCTAssertEqual(try records.load(), [original])
        }
    }

    func testLoadRejectsInvalidPhotoMetadata() throws {
        let invalid = OnsenRecord(spot: OnsenCatalog.spots[0], photoIDs: ["../outside"])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode([invalid]).write(to: records.fileURL)
        XCTAssertThrowsError(try records.load())
    }

    func testStageAndCancelRemovesOnlyUnsavedPhotos() throws {
        let data = Data("jpeg test data".utf8)
        let savedID = try photos.stage(data)
        try photos.commit([savedID])
        try photos.discardDrafts([savedID])
        let draftID = try photos.stage(data)
        let draftURL = try photos.fileURL(for: draftID)
        XCTAssertEqual(draftURL.deletingLastPathComponent().lastPathComponent, "Drafts")
        XCTAssertEqual(try Data(contentsOf: draftURL), data)

        try photos.discardDrafts([savedID, draftID])
        XCTAssertFalse(FileManager.default.fileExists(atPath: draftURL.path))
        XCTAssertThrowsError(try photos.fileURL(for: draftID))
        XCTAssertEqual(try Data(contentsOf: photos.fileURL(for: savedID)), data)
    }

    func testCommitIsIdempotentAndLeavesSourcesUntilRecordSaveSucceeds() throws {
        let data = Data("photo bytes".utf8)
        let id = try photos.stage(data)
        let source = try photos.fileURL(for: id)
        try photos.commit([id])
        let savedURL = try photos.fileURL(for: id)
        XCTAssertNotEqual(source, savedURL)
        XCTAssertEqual(savedURL.deletingLastPathComponent().path, photos.directoryURL.path)
        XCTAssertEqual(try Data(contentsOf: source), data)
        XCTAssertEqual(try Data(contentsOf: savedURL), data)
        try photos.commit([id, id])
        try photos.discardDrafts([id])
        try photos.commit([id])
        XCTAssertEqual(try Data(contentsOf: photos.fileURL(for: id)), data)
    }

    func testMissingPhotoDuringCommitKeepsEveryDraftAvailable() throws {
        let data = Data("keep for retry".utf8)
        let id = try photos.stage(data)
        let source = try photos.fileURL(for: id)
        let missingID = UUID().uuidString
        XCTAssertThrowsError(try photos.commit([id, missingID])) { error in
            XCTAssertEqual(error as? PhotoRepositoryError, .missingPhoto(missingID))
        }
        XCTAssertEqual(try Data(contentsOf: source), data)
        XCTAssertEqual(try photos.fileURL(for: id), source)
        try photos.commit([id])
        XCTAssertEqual(try Data(contentsOf: photos.fileURL(for: id)), data)
    }

    func testFailedRecordSaveLeavesCommittedPhotoAndDraftAvailableForRetry() throws {
        let data = Data("recoverable image".utf8)
        let id = try photos.stage(data)
        let draftURL = try photos.fileURL(for: id)
        try records.save([OnsenRecord(spot: OnsenCatalog.spots[0])])
        let corrupt = Data("{broken".utf8)
        try corrupt.write(to: records.fileURL)
        try photos.commit([id])
        XCTAssertThrowsError(try records.save([OnsenRecord(spot: OnsenCatalog.spots[0], photoIDs: [id])]))
        XCTAssertEqual(try Data(contentsOf: draftURL), data)
        XCTAssertEqual(try Data(contentsOf: photos.fileURL(for: id)), data)
        XCTAssertEqual(try Data(contentsOf: records.fileURL), corrupt)
    }

    func testCleanupRemovesOnlyUnreferencedPermanentManagedFiles() throws {
        let data = Data("photo".utf8)
        let retainedID = try photos.stage(data)
        let removedID = try photos.stage(data)
        let draftID = try photos.stage(data)
        try photos.commit([retainedID, removedID])
        try photos.discardDrafts([retainedID, removedID])
        let removedURL = try photos.fileURL(for: removedID)
        let unrelatedURL = photos.directoryURL.appendingPathComponent("notes.jpg")
        let unrelatedTextURL = photos.directoryURL.appendingPathComponent("\(UUID().uuidString).txt")
        let unrelatedDirectory = photos.directoryURL.appendingPathComponent("\(UUID().uuidString).jpg")
        try data.write(to: unrelatedURL)
        try data.write(to: unrelatedTextURL)
        try FileManager.default.createDirectory(at: unrelatedDirectory, withIntermediateDirectories: true)

        try photos.removeUnreferenced(keeping: [retainedID.lowercased()])
        XCTAssertEqual(try Data(contentsOf: photos.fileURL(for: retainedID)), data)
        XCTAssertFalse(FileManager.default.fileExists(atPath: removedURL.path))
        XCTAssertEqual(try Data(contentsOf: photos.fileURL(for: draftID)), data)
        XCTAssertEqual(try Data(contentsOf: unrelatedURL), data)
        XCTAssertEqual(try Data(contentsOf: unrelatedTextURL), data)
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelatedDirectory.path))
    }

    func testInvalidIdentifiersCannotReadCommitOrDeleteOutsidePhotos() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sentinelURL = directory.appendingPathComponent("outside.jpg")
        let sentinel = Data("untouched".utf8)
        try sentinel.write(to: sentinelURL)
        let id = try photos.stage(sentinel)
        let draftURL = try photos.fileURL(for: id)
        for invalidID in ["../outside", "../../outside", "/tmp/outside", "", "\(id)/../outside"] {
            XCTAssertThrowsError(try photos.fileURL(for: invalidID))
            XCTAssertThrowsError(try photos.commit([invalidID]))
            XCTAssertThrowsError(try photos.discardDrafts([id, invalidID]))
            XCTAssertThrowsError(try photos.removeUnreferenced(keeping: [invalidID]))
        }
        XCTAssertEqual(try Data(contentsOf: sentinelURL), sentinel)
        XCTAssertEqual(try Data(contentsOf: draftURL), sentinel)
    }

    func testStartupDraftCleanupKeepsSavedPhotosAndUnmanagedFiles() throws {
        let data = Data("photo".utf8)
        let savedID = try photos.stage(data)
        try photos.commit([savedID])
        let draftID = try photos.stage(data)
        let draftURL = try photos.fileURL(for: draftID)
        let sentinelURL = draftURL.deletingLastPathComponent().appendingPathComponent("unrelated.jpg")
        try data.write(to: sentinelURL)
        try photos.discardAllDrafts()
        XCTAssertThrowsError(try photos.fileURL(for: draftID))
        XCTAssertEqual(try Data(contentsOf: photos.fileURL(for: savedID)), data)
        XCTAssertEqual(try Data(contentsOf: sentinelURL), data)
        try photos.discardAllDrafts()
    }

    func testSymbolicLinksAreNotReturnedOrCleanedUp() throws {
        try FileManager.default.createDirectory(at: photos.directoryURL, withIntermediateDirectories: true)
        let target = directory.appendingPathComponent("outside.jpg")
        let data = Data("original".utf8)
        try data.write(to: target)
        let id = UUID().uuidString
        let link = photos.directoryURL.appendingPathComponent("\(id).jpg")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        XCTAssertThrowsError(try photos.fileURL(for: id))
        try photos.removeUnreferenced(keeping: [])
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: link.path), target.path)
        XCTAssertEqual(try Data(contentsOf: target), data)
    }

    func testEmptyDataRejectedAndCleanupOfMissingDirectoryIsSafe() throws {
        XCTAssertThrowsError(try photos.stage(Data())) { error in
            XCTAssertEqual(error as? PhotoRepositoryError, .emptyData)
        }
        try photos.commit([])
        try photos.discardDrafts([UUID().uuidString])
        try photos.removeUnreferenced(keeping: [])
        try photos.discardAllDrafts()
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }
}
