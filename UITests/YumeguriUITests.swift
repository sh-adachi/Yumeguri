import XCTest

/// Exercises the real app and its isolated, disk-backed UI-testing store.
/// Map search needs the network; these workflows use the bundled discovery list.
final class YumeguriUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--uitesting", "--reset-records"]
        app.launch()
        XCTAssertTrue(element("tab.explore").waitForExistence(timeout: 15))
    }

    func testWishlistVisitRatingMemoAndPersistence() {
        screenshot("01-discover")
        tap("catalog.firstSpot")
        tap("detail.status.wantToGo")
        saveDetail()

        tap("tab.wishlist")
        XCTAssertTrue(element("records.firstSpot").waitForExistence(timeout: 5))
        screenshot("02-wishlist")
        tap("records.firstSpot")
        assertSelected("detail.status.wantToGo")

        tap("detail.status.visited")
        tap("detail.rating.good")
        assertSelected("detail.status.visited")
        assertSelected("detail.rating.good")

        tap("detail.memo")
        element("detail.memo").typeText("A peaceful afternoon in the hot spring.")
        saveDetail()

        tap("tab.visited")
        XCTAssertTrue(element("records.firstSpot").waitForExistence(timeout: 5))
        screenshot("03-visited")

        // Relaunch without resetting to verify that records survive app termination.
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        tap("tab.visited")
        tap("records.firstSpot")
        assertSelected("detail.status.visited")
        assertSelected("detail.rating.good")
        reveal("detail.memo")
        XCTAssertEqual(element("detail.memo").value as? String,
                       "A peaceful afternoon in the hot spring.")
        reveal("detail.status.visited")
        screenshot("04-saved-detail")
    }

    func testEveryRatingSavesAndReturningToWishlistClearsVisitDetails() {
        tap("catalog.firstSpot")
        tap("detail.status.visited")
        tap("detail.rating.good")
        tap("detail.memo")
        element("detail.memo").typeText("Come back in winter.")
        saveDetail()
        tap("tab.visited")
        tap("records.firstSpot")
        assertSelected("detail.rating.good")

        // Each choice must survive saving and reopening, including replacing a rating.
        for rating in ["average", "bad"] {
            tap("detail.rating.\(rating)")
            saveDetail()
            tap("records.firstSpot")
            assertSelected("detail.rating.\(rating)")
            for other in ["good", "average", "bad"] where other != rating {
                XCTAssertEqual(element("detail.rating.\(other)").value as? String, "未選択")
            }
        }

        reveal("detail.visitedOn")
        XCTAssertTrue(element("detail.visitedOn").exists)
        tap("detail.status.wantToGo")
        saveDetail()
        XCTAssertFalse(element("records.firstSpot").exists,
                       "A wishlist record must disappear from the visited list.")

        // Check the persisted wishlist state after a fresh launch.
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        tap("tab.wishlist")
        tap("records.firstSpot")
        assertSelected("detail.status.wantToGo")
        XCTAssertFalse(element("detail.visitedOn").exists)
        XCTAssertFalse(element("detail.rating.bad").exists)
        reveal("detail.memo")
        XCTAssertEqual(element("detail.memo").value as? String, "Come back in winter.")

        // A fresh visit must not silently restore the old rating.
        tap("detail.status.visited")
        for rating in ["good", "average", "bad"] {
            reveal("detail.rating.\(rating)")
            XCTAssertEqual(element("detail.rating.\(rating)").value as? String, "未選択")
        }
    }

    func testDeleteSavedRecord() {
        tap("catalog.firstSpot")
        tap("detail.status.wantToGo")
        saveDetail()
        tap("tab.wishlist")
        tap("records.firstSpot")
        tap("detail.delete")
        let confirmByID = element("detail.confirmDelete")
        if confirmByID.waitForExistence(timeout: 2) {
            confirmByID.tap()
        } else {
            // Some iOS releases expose only the system confirmation button label.
            let confirmByLabel = app.buttons["記録を削除"].firstMatch
            XCTAssertTrue(confirmByLabel.waitForExistence(timeout: 5))
            confirmByLabel.tap()
        }
        waitForDetailDismissal()
        tap("tab.wishlist")

        let disappeared = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: disappeared,
                                                    object: element("records.firstSpot"))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)

        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        tap("tab.wishlist")
        XCTAssertFalse(element("records.firstSpot").exists)
    }

    /// Live integration check: this test intentionally needs Apple Maps connectivity.
    func testLiveAppleMapsSearchAndSave() {
        // The catalog calls this landmark 草津温泉・湯畑, while Maps calls it 湯畑.
        tap("catalog.firstSpot")
        saveDetail()
        tap("explore.search")
        element("explore.search").typeText("Kusatsu Onsen")
        tap("explore.submit")
        XCTAssertTrue(element("search.firstSpot").waitForExistence(timeout: 40), "Apple Maps must return a real search result.")
        screenshot("05-live-map-search")
        tap("search.firstSpot")
        tap("detail.status.wantToGo")
        saveDetail()
        tap("tab.wishlist")
        XCTAssertTrue(element("records.firstSpot").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1件の温泉"].exists, "The same landmark from catalog and Maps must not create duplicate records.")
        screenshot("06-saved-search-result")
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
            // Both screens have 24-point content padding. Dragging in the 8-point
            // gutter scrolls the page without panning its Map or TextEditor.
            let x = min(8 / max(frame.width, 1), 0.04)
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: x, dy: targetIsAbove ? 0.25 : 0.82))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: x, dy: targetIsAbove ? 0.82 : 0.25))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(target.isHittable, "Control is offscreen: \(identifier)", file: file, line: line)
    }

    private func assertSelected(_ identifier: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier)
        reveal(identifier, file: file, line: line)
        XCTAssertEqual(target.value as? String, "選択中", file: file, line: line)
    }

    private func saveDetail() {
        tap("detail.save")
        waitForDetailDismissal()
    }

    private func waitForDetailDismissal(file: StaticString = #filePath, line: UInt = #line) {
        let disappeared = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: disappeared, object: element("detail.close"))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed,
                       "Detail did not dismiss after saving or deleting.", file: file, line: line)
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
