import XCTest

/// Runs the app with fixed sample data (`-uiTesting`), so no test depends on EduPage or the network.
final class StunduSarakstsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-selectedGroup", "31", "-showWholeWeek", "NO"]
    }

    /// Lesson cards are single VoiceOver elements, so find them by what their label says.
    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    func testDayShowsLessonsWithReadableLabels() {
        app.launch()
        let math = element(containing: "Matemātika")
        XCTAssertTrue(math.waitForExistence(timeout: 10))
        XCTAssertTrue(math.label.contains("1. stunda"), math.label)
        XCTAssertTrue(math.label.contains("kabinets 212."), math.label)
    }

    func testChangeIsAppliedAndAnnounced() {
        app.launch()
        let changed = element(containing: "bija Angļu valoda")
        XCTAssertTrue(changed.waitForExistence(timeout: 10))
        XCTAssertTrue(changed.label.contains("Programmēšana"), changed.label)
        XCTAssertTrue(changed.label.contains("kabinets V115., bija 213."), changed.label)
    }

    func testDayButtonsSayWhichDayAndChanges() {
        app.launch()
        let monday = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Pirmdiena")).firstMatch
        XCTAssertTrue(monday.waitForExistence(timeout: 10))
        XCTAssertTrue(monday.label.contains("ir izmaiņas"), monday.label)
        monday.tap()
        XCTAssertTrue(monday.isSelected)
    }

    func testWholeWeekView() {
        app.launch()
        let weekButton = app.buttons["Visa nedēļa"]
        XCTAssertTrue(weekButton.waitForExistence(timeout: 10))
        weekButton.tap()
        for day in ["Pirmdiena", "Otrdiena", "Trešdiena"] {
            XCTAssertTrue(element(containing: day).waitForExistence(timeout: 5), day)
        }
        XCTAssertTrue(element(containing: "Programmēšana, mainīta").exists)
    }

    func testSettingsShowVersionAndOfflineInfo() {
        app.launch()
        let settings = app.buttons["Iestatījumi"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        XCTAssertTrue(app.staticTexts["Versija"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Saglabātās nedēļas"].exists)
        XCTAssertTrue(app.switches["Paziņot par stundu izmaiņām"].exists)
    }

    func testLargestAccessibilityTextSize() {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(element(containing: "Matemātika").waitForExistence(timeout: 10))
        let settings = app.buttons["Iestatījumi"]
        XCTAssertTrue(settings.isHittable)
    }

    func testAccessibilityAudit() throws {
        app.launch()
        XCTAssertTrue(element(containing: "Matemātika").waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: [.dynamicType, .sufficientElementDescription, .hitRegion]) { issue in
            // System controls (navigation bar, segmented picker) are Apple's to fix.
            guard let element = issue.element else { return false }
            return element.elementType == .navigationBar || element.elementType == .segmentedControl
        }
        app.buttons["Visa nedēļa"].tap()
        try app.performAccessibilityAudit(for: [.dynamicType, .sufficientElementDescription]) { issue in
            issue.element?.elementType == .segmentedControl
        }
    }
}
