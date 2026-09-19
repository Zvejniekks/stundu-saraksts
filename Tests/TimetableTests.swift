import XCTest
@testable import TimetableCore

final class TimetableTests: XCTestCase {
    private func fixture() throws -> [String: Any] {
        let url = Bundle.module.url(forResource: "group31", withExtension: "json", subdirectory: "Fixtures")!
        return try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    }
    private var week: PublishedWeek {
        PublishedWeek(id: "507", title: "14.09.2026.-18.09.2026.", from: SchoolDate.iso("2026-09-14")!, until: SchoolDate.iso("2026-09-19")!)
    }
    func testRealGroup31Fixture() throws {
        let schedule = try TimetableParser.schedule(fixture(), week: week)
        XCTAssertEqual(schedule.group(matching: "31")?.id, "-257")
        XCTAssertEqual(schedule.group(matching: "31.grupa")?.name, "2.k. 31.grupa")
        XCTAssertEqual(schedule.lessons.count, 26)
        XCTAssertFalse(schedule.lessons(for: "-257", day: 1).isEmpty)
        XCTAssertTrue(schedule.lessons.allSatisfy { !$0.subject.isEmpty && $0.groupID == "-257" })
        XCTAssertEqual(schedule.lessons(for: "-257", day: 1).count, 3)
        XCTAssertNil(schedule.group(matching: "9999"))
    }
    func testSourceTimesAreNotInvented() throws {
        let schedule = try TimetableParser.schedule(fixture(), week: week)
        XCTAssertNil(SchoolDate.at("50:50", on: week.from))
        XCTAssertNil(SchoolDate.at("09:99", on: week.from))
        XCTAssertTrue(schedule.lessons.contains { $0.start != nil && $0.end == nil })
        for lesson in schedule.lessons where lesson.day == 1 {
            XCTAssertNotNil(lesson.start)
            XCTAssertNotNil(lesson.end)
        }
    }
    func testPublicationDoesNotRepeatNextWeek() throws {
        let data: [String: Any] = ["regular": ["timetables": [
            ["tt_num": "507", "text": "14.09.2026.-18.09.2026. (14. 09. - 18. 09. 2026)", "datefrom": "2026-09-14", "hidden": false],
            ["tt_num": "hidden", "text": "21.09.2026.-25.09.2026.", "datefrom": "2026-09-21", "hidden": true]
        ]]]
        let weeks = try TimetableParser.weeks(data)
        XCTAssertEqual(weeks.count, 1)
        XCTAssertTrue(weeks[0].contains(SchoolDate.iso("2026-09-18")!))
        XCTAssertFalse(weeks[0].contains(SchoolDate.iso("2026-09-21")!))
        XCTAssertFalse(weeks[0].contains(SchoolDate.iso("2026-09-19")!))
    }
    func testRigaDateAndCacheRoundTrip() throws {
        let schedule = try TimetableParser.schedule(fixture(), week: week)
        let decoded = try JSONDecoder().decode(SchoolSchedule.self, from: JSONEncoder().encode(schedule))
        XCTAssertEqual(decoded.lessons.count, 26)
        XCTAssertEqual(SchoolDate.day(week.from), 0)
        XCTAssertEqual(SchoolDate.time(SchoolDate.at("08:10", on: week.from)!), "08:10")
    }
    func testUnexpectedSchemaFails() {
        XCTAssertThrowsError(try TimetableParser.schedule([:], week: week))
        XCTAssertThrowsError(try TimetableParser.weeks([:]))
    }
}
