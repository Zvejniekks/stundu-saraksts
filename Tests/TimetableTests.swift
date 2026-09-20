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
    func testSchoolTableReplacesBrokenSourceTimes() throws {
        let schedule = try TimetableParser.schedule(fixture(), week: week)
        XCTAssertNil(SchoolDate.at("50:50", on: week.from))
        XCTAssertNil(SchoolDate.at("09:99", on: week.from))
        XCTAssertTrue(schedule.lessons.allSatisfy { $0.start != nil && $0.end != nil })
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
    func testFridayAndMondayTimes() throws {
        let friday = SchoolDate.iso("2026-09-18")!
        XCTAssertEqual(SchoolDate.time(BellTimes.time(period: 2, field: "starttime", day: 4, date: friday)!), "09:00")
        XCTAssertEqual(SchoolDate.time(BellTimes.time(period: 2, field: "endtime", day: 4, date: friday)!), "09:40")
        XCTAssertEqual(SchoolDate.time(BellTimes.time(period: 6, field: "starttime", day: 4, date: friday)!), "12:00")
        XCTAssertEqual(SchoolDate.time(BellTimes.time(period: 10, field: "endtime", day: 4, date: friday)!), "15:40")
        XCTAssertEqual(SchoolDate.time(BellTimes.time(period: 6, field: "starttime", day: 0, date: week.from)!), "12:40")
        XCTAssertEqual(SchoolDate.time(BellTimes.time(period: 2, field: "endtime", day: 0, date: week.from)!), "10:00")
    }
    func testDoubleLessonUsesLastPeriodEnd() throws {
        let schedule = try TimetableParser.schedule(fixture(), week: week)
        let lesson = try XCTUnwrap(schedule.lessons.first { $0.durationPeriods == 2 && $0.day == 4 })
        let date = SchoolDate.iso("2026-09-18")!
        XCTAssertEqual(lesson.end, BellTimes.time(period: lesson.period + 1, field: "endtime", day: 4, date: date))
    }
    func testShortenedTimesApplyOnlyToChosenDate() throws {
        let schedule = try TimetableParser.schedule(fixture(), week: week)
        let adjusted = schedule.applyingShortenedDates(["2026-09-18"])
        for original in schedule.lessons {
            let changed = try XCTUnwrap(adjusted.lessons.first { $0.id == original.id })
            if original.day != 4 {
                XCTAssertEqual(changed.start, original.start)
                XCTAssertEqual(changed.end, original.end)
            } else {
                let date = SchoolDate.iso("2026-09-18")!
                XCTAssertEqual(changed.start, BellTimes.time(period: original.period, field: "starttime", day: 4, date: date, shortened: true))
                XCTAssertEqual(changed.end, BellTimes.time(period: original.period + original.durationPeriods - 1, field: "endtime", day: 4, date: date, shortened: true))
            }
        }
        // Removing the override returns to the authoritative ordinary weekday table.
        let restored = schedule.applyingShortenedDates([])
        XCTAssertEqual(restored.lessons.first?.end, schedule.lessons.first?.end)
    }

    func testDoublePeriodBreakAndBoundaries() throws {
        let date = SchoolDate.iso("2026-09-18")!
        let lesson = SchoolLesson(id: "double", groupID: "31", day: 4, period: 2, durationPeriods: 2,
            subject: "Programmēšana", teacher: "", room: "", subgroup: "",
            start: SchoolDate.at("09:00", on: date), end: SchoolDate.at("10:25", on: date))
        let slots = lesson.periodTimes(on: date, shortened: false)
        XCTAssertEqual(slots.map(\.time), ["09:00–09:40", "09:45–10:25"])
        XCTAssertTrue(slots[0].contains(SchoolDate.at("09:00", on: date)!))
        XCTAssertFalse(slots.contains { $0.contains(SchoolDate.at("09:42", on: date)!) })
        XCTAssertFalse(slots[0].contains(SchoolDate.at("09:40", on: date)!))
        XCTAssertTrue(slots[1].contains(SchoolDate.at("09:45", on: date)!))
        XCTAssertEqual(slots[1].start!.timeIntervalSince(slots[0].end!), 300)
        XCTAssertEqual(lesson.periodTimes(on: date, shortened: true).map(\.time), ["09:00–09:30", "09:40–10:10"])
    }
    func testUnrelatedShortenedDateDoesNotChangeSchedule() throws {
        let schedule = try TimetableParser.schedule(fixture(), week: week)
        let unchanged = schedule.applyingShortenedDates(["2030-01-01"])
        XCTAssertEqual(unchanged.lessons.map(\.start), schedule.lessons.map(\.start))
        XCTAssertEqual(unchanged.lessons.map(\.end), schedule.lessons.map(\.end))
    }

    func testWidgetKeepsLastPublicationOnWeekend() throws {
        let now = SchoolDate.iso("2026-09-19")!
        XCTAssertEqual(WidgetSelection.week(from: [week], now: now)?.id, "507")
        let schedule = try TimetableParser.schedule(fixture(), week: week)
        let rows = WidgetSelection.rows(schedule: schedule, groupID: "-257", now: now)
        XCTAssertFalse(rows.isEmpty)
        XCTAssertTrue(rows.allSatisfy { $0.day == rows.first?.day })
        XCTAssertTrue(rows.allSatisfy { ($0.start ?? now) < now })
        XCTAssertTrue(WidgetSelection.rows(schedule: schedule, groupID: "missing", now: now).isEmpty)
    }
    func testWidgetPrefersCurrentThenNearestFutureWeek() {
        let future = PublishedWeek(id: "next", title: "next", from: SchoolDate.iso("2026-09-21")!, until: SchoolDate.iso("2026-09-26")!)
        XCTAssertEqual(WidgetSelection.week(from: [future, week], now: SchoolDate.iso("2026-09-16")!)?.id, week.id)
        XCTAssertEqual(WidgetSelection.week(from: [week, future], now: SchoolDate.iso("2026-09-19")!)?.id, future.id)
        XCTAssertNil(WidgetSelection.week(from: [], now: Date()))
    }
    func testSplitCardsKeepEachPeriodAndSubject() throws {
        let schedule = try TimetableParser.schedule(fixture(), week: week)
        let lesson = try XCTUnwrap(schedule.lessons.first { $0.day == 4 && $0.durationPeriods == 2 })
        let parts = lesson.splitPeriods(on: SchoolDate.iso("2026-09-18")!, shortened: false)
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(Set(parts.map(\.id)).count, 2)
        XCTAssertEqual(parts.map(\.durationPeriods), [1, 1])
        XCTAssertTrue(parts.allSatisfy { $0.subject == lesson.subject && $0.teacher == lesson.teacher && $0.room == lesson.room })
        XCTAssertEqual(parts.first?.start, lesson.start)
        XCTAssertEqual(parts.last?.end, lesson.end)
    }

    func testWidgetDayIncludesPastLessons() throws {
        let source = try TimetableParser.schedule(fixture(), week: week)
        let prepared = WidgetSelection.prepare(source, group: "31", shortenedDates: [])
        let now = SchoolDate.at("13:00", on: SchoolDate.iso("2026-09-18")!)!
        let rows = WidgetSelection.rows(schedule: prepared, groupID: "-257", now: now)
        XCTAssertEqual(rows.count, prepared.lessons(for: "-257", day: 4).count)
        XCTAssertTrue(rows.contains { ($0.end ?? .distantFuture) < now })
        XCTAssertTrue(rows.allSatisfy { $0.day == 4 && $0.durationPeriods == 1 })
    }
    func testSmallWidgetSkipsCurrentLesson() throws {
        let source = try TimetableParser.schedule(fixture(), week: week)
        let prepared = WidgetSelection.prepare(source, group: "31", shortenedDates: [])
        let first = try XCTUnwrap(prepared.lessons(for: "-257").first)
        let now = try XCTUnwrap(first.start).addingTimeInterval(60)
        let next = try XCTUnwrap(WidgetSelection.next(schedule: prepared, groupID: "-257", now: now))
        XCTAssertGreaterThan(try XCTUnwrap(next.start), now)
        XCTAssertNotEqual(next.id, first.id)
    }
    func testWidgetPreparationPreservesWholeWeek() throws {
        let source = try TimetableParser.schedule(fixture(), week: week)
        let expected = source.lessons(for: "-257").reduce(0) { $0 + $1.durationPeriods }
        let prepared = WidgetSelection.prepare(source, group: "31", shortenedDates: [])
        XCTAssertEqual(prepared.lessons.count, expected)
        XCTAssertEqual(Set(prepared.lessons.map(\.day)), Set(0..<5))
        XCTAssertEqual(Set(prepared.lessons.map(\.id)).count, expected)
    }

}
