import XCTest
@testable import TimetableCore

/// Broken, partial or unexpected data from EduPage must never crash the app or show wrong lessons.
final class SubstitutionParsingRobustnessTests: XCTestCase {
    private func row(_ period: String?, _ info: String, kind: String = "change") -> String {
        let periodDiv = period.map { #"<div class="period"><span>\#($0)</span></div>"# } ?? ""
        return #"<div class="row \#(kind)">\#(periodDiv)<div class="info"><span>\#(info)</span></div></div>"#
    }
    private func section(_ header: String?, _ rows: [String]) -> String {
        let head = header.map { #"<div class="header"><span>\#($0)</span></div>"# } ?? ""
        return #"<div class="section print-nobreak">\#(head)<div class="rows">\#(rows.joined())</div></div>"#
    }

    func testEmptyAndGarbageInput() {
        XCTAssertTrue(SubstitutionParser.parse(html: "", date: "2026-11-09").entries.isEmpty)
        XCTAssertTrue(SubstitutionParser.parse(html: "<html><body>Nav izmaiņu</body></html>", date: "2026-11-09").entries.isEmpty)
        XCTAssertTrue(SubstitutionParser.parse(html: "class=\"section class=\"row", date: "2026-11-09").entries.isEmpty)
    }

    func testSectionWithoutHeaderIsSkipped() {
        let html = section(nil, [row("1", "Matemātika - (Ozola Anna), stunda nenotiek")])
        XCTAssertTrue(SubstitutionParser.parse(html: html, date: "d").entries.isEmpty)
    }

    func testRowsWithoutPeriodOrText() {
        let html = section("2.k. 31.grupa", [row(nil, "Ekskursija visai grupai"), row("3", "   "), row("V", "Kaut kas")])
        let entries = SubstitutionParser.parse(html: html, date: "d").entries
        XCTAssertEqual(entries.count, 2)
        XCTAssertNil(entries[0].firstPeriod)
        XCTAssertEqual(entries[0].periodText, "Visa diena")
        XCTAssertNil(entries[1].firstPeriod, "a period without numbers is not a lesson number")
    }

    func testHTMLEntitiesAndWhitespaceAreCleaned() {
        let html = section("2.k.&nbsp;31.grupa", [row(" 2 ", "Fizika &amp; ķīmija -  &quot;lab.&quot;\n  (&#039;A&#039;)")])
        let entry = SubstitutionParser.parse(html: html, date: "d").entries[0]
        XCTAssertEqual(entry.group, "2.k. 31.grupa")
        XCTAssertEqual(entry.text, "Fizika & ķīmija - \"lab.\" ('A')")
        XCTAssertEqual(entry.firstPeriod, 2)
    }

    func testUnknownRowKindStillParses() {
        let html = section("2.k. 31.grupa", [row("4", "Jauna stunda", kind: "add")])
        let entry = SubstitutionParser.parse(html: html, date: "d").entries[0]
        XCTAssertEqual(entry.kind, "add")
        XCTAssertFalse(entry.isCancelled)
    }

    func testOnlyMatchingGroupIsReturned() {
        let html = section("2.k. 31.grupa", [row("1", "A")]) + section("2.k. 131.grupa", [row("1", "B")])
            + section("2.k. 3.grupa", [row("1", "C")])
        let day = SubstitutionParser.parse(html: html, date: "d")
        XCTAssertEqual(day.entries(for: SchoolGroup(id: "x", name: "2.k. 31.grupa", short: "31.grupa")).map(\.text), ["A"])
        XCTAssertEqual(day.entries(for: SchoolGroup(id: "y", name: "2.k. 3.grupa", short: "3.grupa")).map(\.text), ["C"])
        XCTAssertTrue(day.entries(for: nil).isEmpty)
    }

    func testCorrectionWithoutDetailsOrArrows() {
        let plain = SubstitutionEntry(group: "g", firstPeriod: 1, lastPeriod: 1, text: "Matemātika", kind: "change").correction
        XCTAssertEqual(plain, SubstitutionCorrection())
        let onlySubject = SubstitutionEntry(group: "g", firstPeriod: 1, lastPeriod: 1, text: "(Fizika) ➔ Ķīmija", kind: "change").correction
        XCTAssertEqual(onlySubject.subject, "Ķīmija")
        XCTAssertNil(onlySubject.teacher)
    }

    func testUnbalancedBracketsDoNotCrash() {
        for text in ["((((", "))) - x", "(a - b", "a) - (b", " - ", "➔", "Aizvietošana:", "Mainīt kabinetu: ➔"] {
            let entry = SubstitutionEntry(group: "g", firstPeriod: 1, lastPeriod: 1, text: text, kind: "change")
            _ = entry.correction
            _ = SchoolLesson(id: "l", groupID: "g", day: 0, period: 1, durationPeriods: 1, subject: "S",
                             teacher: "T", room: "R", subgroup: "", start: nil, end: nil).applying([entry])
        }
    }

    func testWholeDayEntryDoesNotChangeLessons() {
        let entry = SubstitutionEntry(group: "g", firstPeriod: nil, lastPeriod: nil, text: "(A) ➔ B", kind: "change")
        let lesson = SchoolLesson(id: "l", groupID: "g", day: 0, period: 2, durationPeriods: 1, subject: "A",
                                  teacher: "", room: "", subgroup: "", start: nil, end: nil)
        XCTAssertNil(lesson.applying([entry]).change)
    }
}

final class TimetableParsingRobustnessTests: XCTestCase {
    func testMissingTablesThrowReadableErrors() {
        let week = PublishedWeek(id: "1", title: "t", from: SchoolDate.iso("2026-11-09")!, until: SchoolDate.iso("2026-11-14")!)
        XCTAssertThrowsError(try TimetableParser.schedule([:], week: week)) { error in
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
        let noCards: [String: Any] = ["dbiAccessorRes": ["tables": [["id": "classes", "data_rows": []], ["id": "lessons", "data_rows": []]]]]
        XCTAssertThrowsError(try TimetableParser.schedule(noCards, week: week))
        let wrongTypes: [String: Any] = ["dbiAccessorRes": ["tables": "nav saraksts"]]
        XCTAssertThrowsError(try TimetableParser.schedule(wrongTypes, week: week))
    }

    func testWeeksWithBadRowsAreSkipped() throws {
        XCTAssertThrowsError(try TimetableParser.weeks([:]))
        XCTAssertThrowsError(try TimetableParser.weeks(["regular": ["timetables": []]]))
        let rows: [[String: Any]] = [
            ["tt_num": "1", "text": "bez datuma", "hidden": false],
            ["tt_num": "2", "text": "09.11.2026.-13.11.2026.", "hidden": false],
            ["tt_num": 3, "text": "16.11.2026.-20.11.2026.", "hidden": false]
        ]
        let weeks = try TimetableParser.weeks(["regular": ["timetables": rows]])
        XCTAssertEqual(weeks.map(\.id), ["3", "2"], "numeric ids are read and the newest week comes first")
    }

    func testCardsPointingToMissingLessonsAreIgnored() throws {
        let week = PublishedWeek(id: "1", title: "t", from: SchoolDate.iso("2026-11-09")!, until: SchoolDate.iso("2026-11-14")!)
        let data: [String: Any] = ["dbiAccessorRes": ["tables": [
            ["id": "classes", "data_rows": [["id": "c1", "name": "2.k. 31.grupa", "short": "31.grupa"]]],
            ["id": "lessons", "data_rows": []],
            ["id": "cards", "data_rows": [["id": "x", "lessonid": "missing", "period": "1", "days": "10000"],
                                          ["id": "y", "lessonid": "missing", "period": "nav", "days": "10000"]]]
        ]]]
        let schedule = try TimetableParser.schedule(data, week: week)
        XCTAssertTrue(schedule.lessons.isEmpty)
        XCTAssertEqual(schedule.groups.first?.short, "31.grupa")
    }
}

final class NetworkPolicyTests: XCTestCase {
    func testTransientErrorsAreRetriedButOfflineIsNot() {
        XCTAssertTrue(EduPageClient.isTransient(URLError(.timedOut)))
        XCTAssertTrue(EduPageClient.isTransient(URLError(.networkConnectionLost)))
        XCTAssertTrue(EduPageClient.isTransient(ScheduleError.server(503)))
        XCTAssertFalse(EduPageClient.isTransient(URLError(.notConnectedToInternet)))
        XCTAssertFalse(EduPageClient.isTransient(URLError(.cancelled)))
        XCTAssertFalse(EduPageClient.isTransient(ScheduleError.server(404)))
        XCTAssertFalse(EduPageClient.isTransient(ScheduleError.message("x")))
    }
    func testServerErrorHasReadableText() {
        XCTAssertEqual(ScheduleError.server(502).localizedDescription, "EduPage serveris neatbild (kods 502). Mēģini vēlreiz.")
    }
}

final class OfflineStoreTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("offline-\(UUID().uuidString)")
        OfflineStore.rootOverride = folder
    }
    override func tearDownWithError() throws {
        OfflineStore.rootOverride = nil
        try? FileManager.default.removeItem(at: folder)
    }

    private func schedule(_ id: String, from: String) -> SchoolSchedule {
        let start = SchoolDate.iso(from)!
        var lesson = SchoolLesson(id: "l-\(id)", groupID: "g", day: 0, period: 1, durationPeriods: 1, subject: "Matemātika",
                                  teacher: "A", room: "212.", subgroup: "", start: start, end: start.addingTimeInterval(2400))
        lesson.change = LessonChange(text: "t", cancelled: false, previousSubject: "Fizika", previousTeacher: nil, previousRoom: nil)
        let week = PublishedWeek(id: id, title: id, from: start, until: start.addingTimeInterval(5 * 86400))
        return SchoolSchedule(week: week, groups: [SchoolGroup(id: "g", name: "G", short: "G")], lessons: [lesson], fetchedAt: start)
    }

    func testWeekRoundTripKeepsChanges() throws {
        OfflineStore.save(schedule("507", from: "2026-11-09"))
        let loaded = try XCTUnwrap(OfflineStore.schedule(weekID: "507"))
        XCTAssertEqual(loaded.lessons.first?.change?.previousSubject, "Fizika")
        XCTAssertEqual(loaded.week.from, SchoolDate.iso("2026-11-09"))
        XCTAssertEqual(OfflineStore.savedWeekIDs(), ["507"])
        XCTAssertNil(OfflineStore.schedule(weekID: "999"))
    }

    func testOnlyNewestWeeksAreKept() {
        for i in 0..<(OfflineStore.keptWeeks + 3) {
            let date = SchoolDate.calendar.date(byAdding: .day, value: 7 * i, to: SchoolDate.iso("2026-09-07")!)!
            OfflineStore.save(schedule("w\(i)", from: SchoolDate.dateKey(date)))
        }
        let kept = OfflineStore.savedWeekIDs()
        XCTAssertEqual(kept.count, OfflineStore.keptWeeks)
        XCTAssertFalse(kept.contains("w0"))
        XCTAssertTrue(kept.contains("w\(OfflineStore.keptWeeks + 2)"))
    }

    func testCorruptFileIsRemovedInsteadOfCrashing() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("schedule-v2.json")
        try Data("{ nav json".utf8).write(to: url)
        XCTAssertNil(ScheduleCache.read())
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testCurrentWeekIsAlsoKeptForBrowsing() throws {
        try ScheduleCache.save(schedule("510", from: "2026-11-16"))
        XCTAssertNotNil(ScheduleCache.read())
        XCTAssertNotNil(OfflineStore.schedule(weekID: "510"))
    }

    func testWeeksListAndChangesSurviveRestart() {
        let week = PublishedWeek(id: "1", title: "t", from: SchoolDate.iso("2026-11-09")!, until: SchoolDate.iso("2026-11-14")!)
        OfflineStore.saveWeeks([week])
        XCTAssertEqual(OfflineStore.readWeeks(), [week])
        let now = SchoolDate.iso("2026-11-10")!
        let fresh = SubstitutionDay(date: "2026-11-10", entries: [], fetchedAt: now)
        let old = SubstitutionDay(date: "2026-10-01", entries: [], fetchedAt: now)
        SubstitutionCache.save(["2026-11-10": fresh, "2026-10-01": old], now: now)
        XCTAssertEqual(Set(SubstitutionCache.read().keys), ["2026-11-10"], "days older than two weeks are dropped")
    }
}
