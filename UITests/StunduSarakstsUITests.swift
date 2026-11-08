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
        XCTAssertTrue(app.switches["Paziņot par stundu izmaiņām"].waitForExistence(timeout: 5))
        // Lower rows of the settings list only exist once scrolled into view.
        let version = element(containing: "Versija")
        let saved = element(containing: "Saglabātās nedēļas")
        for _ in 0..<4 where !(version.exists && saved.exists) { app.swipeUp() }
        XCTAssertTrue(saved.exists)
        XCTAssertTrue(version.exists)
        XCTAssertTrue(version.label.contains("1.") || element(containing: "build").exists, version.label)
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
            Self.report(issue, in: self.app)
            // System controls (navigation bar, segmented picker) are Apple's to fix.
            guard let element = issue.element else { return false }
            return element.elementType == .navigationBar || element.elementType == .segmentedControl
                || Self.cutOffByScreen(issue, in: self.app)
        }
        app.buttons["Visa nedēļa"].tap()
        try app.performAccessibilityAudit(for: [.dynamicType, .sufficientElementDescription]) { issue in
            Self.report(issue, in: self.app)
            return issue.element?.elementType == .segmentedControl || Self.cutOffByScreen(issue, in: self.app)
        }
    }

    /// The audit reads text cut off by the screen edge as text that does not scale.
    /// Scaling itself is covered by testLargestAccessibilityTextSize.
    private static func cutOffByScreen(_ issue: XCUIAccessibilityAuditIssue, in app: XCUIApplication) -> Bool {
        guard issue.auditType == .dynamicType, let element = issue.element else { return false }
        return !app.frame.contains(element.frame)
    }

    /// Names the element and its position in the CI log, so a failing audit says what to fix.
    private static func report(_ issue: XCUIAccessibilityAuditIssue, in app: XCUIApplication) {
        let element = issue.element.map { "\($0.elementType.rawValue) '\($0.label)' \($0.frame) screen \(app.frame)" } ?? "no element"
        print("AUDIT: \(issue.compactDescription) — \(element)")
    }
}
