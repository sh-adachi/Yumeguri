import XCTest

/// Uses the real system photo picker. The test simulator needs at least one
/// image in Photos (for example, imported with `xcrun simctl addmedia`).
final class PhotoAttachmentUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--uitesting", "--reset-records"]
        app.launch()
        XCTAssertTrue(element("tab.explore").waitForExistence(timeout: 15))
    }

    func testPhotoImportPreviewPersistenceAndDeletion() {
        tap("catalog.firstSpot")
        tap("detail.status.wantToGo")
        assertPhotoCount(0)
        importOnePhoto()
        capture("photo-attachments")
        tap("detail.photo.0")
        XCTAssertTrue(element("storedPhoto.loaded").waitForExistence(timeout: 10))
        capture("photo-preview")
        tap("photoPreview.close")
        saveDetail()

        relaunchAndOpenSavedRecord()
        assertPhotoCount(1)
        tap("detail.photo.0")
        XCTAssertTrue(element("storedPhoto.loaded").waitForExistence(timeout: 10))
        tap("photoPreview.close")

        tap("detail.photo.remove.0")
        assertPhotoCount(0)
        saveDetail()

        relaunchAndOpenSavedRecord()
        assertPhotoCount(0)
        XCTAssertFalse(element("detail.photo.0").exists,
                       "A deleted photo must not return when the saved record is reloaded.")
    }

    func testDiscardingPhotoRemovalPreservesSavedPhoto() {
        tap("catalog.firstSpot")
        tap("detail.status.wantToGo")
        importOnePhoto()
        saveDetail()

        tap("tab.wishlist")
        tap("records.firstSpot")
        assertPhotoCount(1)
        tap("detail.photo.remove.0")
        assertPhotoCount(0)
        tap("detail.close")

        let discard = element("detail.discardChanges")
        if discard.waitForExistence(timeout: 2) {
            discard.tap()
        } else {
            let discardByLabel = app.buttons["変更を破棄"].firstMatch
            XCTAssertTrue(discardByLabel.waitForExistence(timeout: 5))
            discardByLabel.tap()
        }
        waitForDetailDismissal()

        // Relaunch as well as reopening: an unsaved removal must leave both
        // the stored attachment metadata and its image file intact.
        relaunchAndOpenSavedRecord()
        assertPhotoCount(1)
        tap("detail.photo.0")
        XCTAssertTrue(element("storedPhoto.loaded").waitForExistence(timeout: 10))
        tap("photoPreview.close")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func importOnePhoto(file: StaticString = #filePath, line: UInt = #line) {
        tap("detail.photos.add", file: file, line: line)

        let photoLabels = NSPredicate(
            format: "label BEGINSWITH[c] %@ OR label BEGINSWITH %@ OR label BEGINSWITH %@ OR label BEGINSWITH %@",
            "Photo,", "写真、", "写真,", "写真，")
        let firstPhoto = app.images.matching(photoLabels).firstMatch
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 20),
                      "No photo found in the system picker. Seed the simulator photo library before running.",
                      file: file, line: line)
        // The iOS 26 remote picker reports visible thumbnails as non-hittable.
        // Use the discovered image's coordinates, not a fixed screen position.
        firstPhoto.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // PhotosPicker's multi-selection confirmation is localized and may
        // include the number of selected photos, such as “Add (1)” or “追加”.
        let confirmationLabels = NSPredicate(
            format: "label BEGINSWITH[c] %@ OR label BEGINSWITH %@ OR label == %@ OR label == %@",
            "Add", "追加", "Done", "完了")
        let confirmation = app.buttons.matching(confirmationLabels).firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 10),
                      "The system picker did not expose an Add confirmation.\n\(app.debugDescription)",
                      file: file, line: line)
        confirmation.tap()
        assertPhotoCount(1, timeout: 25, file: file, line: line)
    }

    private func assertPhotoCount(_ count: Int, timeout: TimeInterval = 10,
                                  file: StaticString = #filePath, line: UInt = #line) {
        reveal("detail.photos.count", file: file, line: line)
        let target = element("detail.photos.count")
        let expected = "\(count) / 10"
        let matches = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                target.exists && (target.label == expected || target.value as? String == expected)
            }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [matches], timeout: timeout), .completed,
                       "Expected photo count \(expected), found label '\(target.label)' and value '\(String(describing: target.value))'.",
                       file: file, line: line)
    }

    private func relaunchAndOpenSavedRecord() {
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        tap("tab.wishlist")
        tap("records.firstSpot")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func tap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        reveal(identifier, file: file, line: line)
        element(identifier).tap()
    }

    private func reveal(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: 10),
                      "Missing accessibility identifier: \(identifier)", file: file, line: line)
        for _ in 0..<7 {
            if target.isHittable { return }
            let scroll = app.scrollViews.allElementsBoundByIndex
                .filter { $0.isHittable && $0.frame.height > 220 }
                .max { $0.frame.height < $1.frame.height }
            guard let scroll else {
                XCTFail("No visible scroll view for \(identifier)", file: file, line: line)
                return
            }
            let frame = scroll.frame
            let targetIsAbove = !target.frame.isEmpty && target.frame.midY < frame.midY
            // Drag in the content gutter to avoid panning the embedded map.
            let x = min(8 / max(frame.width, 1), 0.04)
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: x, dy: targetIsAbove ? 0.25 : 0.82))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: x, dy: targetIsAbove ? 0.82 : 0.25))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(target.isHittable, "Control is offscreen: \(identifier)", file: file, line: line)
    }

    private func saveDetail() {
        tap("detail.save")
        waitForDetailDismissal()
    }

    private func waitForDetailDismissal(file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                                    object: element("detail.close"))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed,
                       "Detail did not dismiss after saving or discarding.", file: file, line: line)
    }
}
