import Foundation

struct SchoolGroup: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let short: String
}

struct PublishedWeek: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let from: Date
    let until: Date
    func contains(_ date: Date) -> Bool { date >= from && date < until }
}

struct SchoolLesson: Codable, Identifiable {
    let id: String
    let groupID: String
    let day: Int
    let period: Int
    let durationPeriods: Int
    let subject: String
    let teacher: String
    let room: String
    let subgroup: String
    let start: Date?
    let end: Date?
    var time: String {
        "\(start.map(SchoolDate.time) ?? "?")–\(end.map(SchoolDate.time) ?? "?")"
    }
}

struct SchoolSchedule: Codable {
    let week: PublishedWeek
    let groups: [SchoolGroup]
    let lessons: [SchoolLesson]
    let fetchedAt: Date
    func lessons(for groupID: String, day: Int? = nil) -> [SchoolLesson] {
        lessons.filter { $0.groupID == groupID && (day == nil || $0.day == day) }
            .sorted { ($0.day, $0.period, $0.subject, $0.id) < ($1.day, $1.period, $1.subject, $1.id) }
    }
    func group(matching value: String) -> SchoolGroup? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return groups.first { $0.id == value || $0.short.lowercased() == value || $0.name.lowercased() == value || $0.short.lowercased() == "\(value).grupa" }
    }
}

enum SchoolDate {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Riga")!
        c.firstWeekday = 2
        return c
    }
    static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = calendar.timeZone; f.dateFormat = format; f.isLenient = false
        return f
    }
    static func iso(_ string: String) -> Date? { formatter("yyyy-MM-dd").date(from: string) }
    static func time(_ date: Date) -> String { formatter("HH:mm").string(from: date) }
    static func short(_ date: Date) -> String { formatter("dd.MM.").string(from: date) }
    static func day(_ date: Date) -> Int { (calendar.component(.weekday, from: date) + 5) % 7 }
    static func monday(_ date: Date) -> Date {
        calendar.date(byAdding: .day, value: -day(date), to: calendar.startOfDay(for: date))!
    }
    static func at(_ time: String, on date: Date) -> Date? {
        let p = time.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2, (0...23).contains(p[0]), (0...59).contains(p[1]) else { return nil }
        return calendar.date(bySettingHour: p[0], minute: p[1], second: 0, of: date)
    }
    static let dayNames = ["Pirmdiena", "Otrdiena", "Trešdiena", "Ceturtdiena", "Piektdiena", "Sestdiena", "Svētdiena"]
}

enum ScheduleError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let s) = self { return s }; return nil }
}

enum TimetableParser {
    typealias Row = [String: Any]
    static func string(_ value: Any?) -> String {
        if let s = value as? String { return s }
        if let n = value as? NSNumber { return n.stringValue }
        return ""
    }
    static func weeks(_ result: Row) throws -> [PublishedWeek] {
        guard let regular = result["regular"] as? Row,
              let rows = regular["timetables"] as? [Row] else {
            throw ScheduleError.message("EduPage neatgrieza nedēļu sarakstu.")
        }
        let regex = try NSRegularExpression(pattern: #"\d{2}\.\d{2}\.\d{4}"#)
        let weeks: [PublishedWeek] = rows.compactMap { row in
            guard row["hidden"] as? Bool != true else { return nil }
            let title = string(row["text"])
            let dates = regex.matches(in: title, range: NSRange(title.startIndex..., in: title)).compactMap {
                Range($0.range, in: title).flatMap { SchoolDate.formatter("dd.MM.yyyy").date(from: String(title[$0])) }
            }
            // This school publishes one dated timetable per week. Never repeat an old week forever.
            guard let from = dates.first ?? SchoolDate.iso(string(row["datefrom"])) else { return nil }
            let until = dates.count > 1
                ? SchoolDate.calendar.date(byAdding: .day, value: 1, to: dates[1])!
                : SchoolDate.calendar.date(byAdding: .day, value: 7, to: SchoolDate.monday(from))!
            return PublishedWeek(id: string(row["tt_num"]), title: title, from: from, until: until)
        }
        guard !weeks.isEmpty else { throw ScheduleError.message("Nav publicēta neviena nedēļa.") }
        return weeks.sorted { $0.from > $1.from }
    }
    static func schedule(_ result: Row, week: PublishedWeek) throws -> SchoolSchedule {
        guard let accessor = result["dbiAccessorRes"] as? Row,
              let tables = accessor["tables"] as? [Row] else {
            throw ScheduleError.message("Stundu dati nav pieejami. Mēģini vēlreiz vai atver EduPage.")
        }
        var db: [String: [Row]] = [:]
        for table in tables { db[string(table["id"])] = table["data_rows"] as? [Row] ?? [] }
        guard db["classes"] != nil, db["lessons"] != nil, db["cards"] != nil else {
            throw ScheduleError.message("EduPage datu formāts ir mainījies.")
        }
        // Multi-week rotations need a separate mapping; do not show a guessed schedule.
        guard (db["weeks"] ?? []).count <= 1, (db["terms"] ?? []).count <= 1 else {
            throw ScheduleError.message("Šis vairāku nedēļu saraksta formāts vēl nav atbalstīts.")
        }
        func index(_ key: String) -> [String: Row] {
            var result: [String: Row] = [:]
            for row in db[key] ?? [] { result[string(row["id"])] = row }
            return result
        }
        let subjects = index("subjects"), teachers = index("teachers"), rooms = index("classrooms")
        let sourceLessons = index("lessons"), sourceGroups = index("groups"), classes = index("classes")
        var periods: [String: Row] = [:]
        for row in db["periods"] ?? [] { periods[string(row["period"])] = row }
        let groups = (db["classes"] ?? []).map { SchoolGroup(id: string($0["id"]), name: string($0["name"]), short: string($0["short"])) }
            .sorted { $0.short.localizedStandardCompare($1.short) == .orderedAscending }
        func names(_ ids: Any?, in rows: [String: Row]) -> String {
            (ids as? [String] ?? []).compactMap { rows[$0] }.map {
                let name = string($0["name"]); return name.isEmpty ? string($0["short"]) : name
            }.joined(separator: ", ")
        }
        func time(_ period: Row?, field: String, day: Int, date: Date) -> Date? {
            guard let period = period else { return nil }
            if let number = Int(string(period["period"])),
               let official = BellTimes.time(period: number, field: field, day: day, date: date) {
                return official
            }
            let overrides = period["daydata"] as? [String: Row]
            let text = string(overrides?[String(day)]?[field] ?? period[field])
            return SchoolDate.at(text, on: date)
        }
        var lessons: [SchoolLesson] = []
        for card in db["cards"] ?? [] {
            guard let lesson = sourceLessons[string(card["lessonid"])],
                  let period = Int(string(card["period"])) else { continue }
            let duration = max(1, Int(string(lesson["durationperiods"])) ?? 1)
            for (day, bit) in string(card["days"]).enumerated() where bit == "1" && day < 7 {
                let date = SchoolDate.calendar.date(byAdding: .day, value: day, to: SchoolDate.monday(week.from))!
                guard week.contains(date) else { continue }
                for groupID in lesson["classids"] as? [String] ?? [] {
                    // Custom bell schedules are not silently replaced by standard bells.
                    let bell = string(lesson["bell"]).isEmpty ? string(classes[groupID]?["bell"]) : string(lesson["bell"])
                    let bellRows = (db["bells"] ?? []).first { string($0["id"]) == bell }
                    let customBell = !(bellRows?["perioddata"] as? Row ?? [:]).isEmpty
                    let start = customBell ? nil : time(periods[String(period)], field: "starttime", day: day, date: date)
                    var end = customBell ? nil : time(periods[String(period + duration - 1)], field: "endtime", day: day, date: date)
                    if let a = start, let b = end, b <= a || b.timeIntervalSince(a) > Double(duration * 120 * 60) { end = nil }
                    let subgroup = (lesson["groupids"] as? [String] ?? []).compactMap { sourceGroups[$0] }
                        .filter { string($0["classid"]) == groupID && $0["entireclass"] as? Bool != true }
                        .map { string($0["name"]) }.joined(separator: ", ")
                    lessons.append(SchoolLesson(id: "\(card["id"] ?? "")-\(groupID)-\(day)", groupID: groupID,
                        day: day, period: period, durationPeriods: duration, subject: names([string(lesson["subjectid"])], in: subjects),
                        teacher: names(lesson["teacherids"], in: teachers), room: names(card["classroomids"], in: rooms),
                        subgroup: subgroup, start: start, end: end))
                }
            }
        }
        return SchoolSchedule(week: week, groups: groups, lessons: lessons, fetchedAt: Date())
    }
}

final class EduPageClient {
    private let base = "https://valteh.edupage.org"
    private let session: URLSession
    private var token = ""
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        session = URLSession(configuration: config)
    }
    private func data(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
            throw ScheduleError.message("EduPage serveris neatbild. Mēģini vēlreiz.")
        }
        return data
    }
    private func bootstrap() async throws {
        guard token.isEmpty else { return }
        let bytes = try await data(URLRequest(url: URL(string: base + "/timetable/view.php")!))
        let html = String(decoding: bytes, as: UTF8.self)
        let regex = try NSRegularExpression(pattern: #"gsechash\s*[:=]\s*["']([^"']+)"#)
        guard let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            throw ScheduleError.message("Neizdevās atvērt publisko EduPage sarakstu.")
        }
        token = String(html[range])
    }
    private func rpc(_ path: String, args: [Any]) async throws -> [String: Any] {
        try await bootstrap()
        var request = URLRequest(url: URL(string: base + path)!)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["__args": args, "__gsh": token])
        let root = try JSONSerialization.jsonObject(with: await data(request)) as? [String: Any]
        guard let result = root?["r"] as? [String: Any] else {
            throw ScheduleError.message("EduPage noraidīja datu pieprasījumu. Atsvaidzini sarakstu.")
        }
        return result
    }
    func weeks() async throws -> [PublishedWeek] {
        let now = Date(), c = SchoolDate.calendar
        let year = c.component(.year, from: now) - (c.component(.month, from: now) < 8 ? 1 : 0)
        return try TimetableParser.weeks(await rpc("/timetable/server/ttviewer.js?__func=getTTViewerData", args: [NSNull(), year]))
    }
    func schedule(week: PublishedWeek) async throws -> SchoolSchedule {
        try TimetableParser.schedule(await rpc("/timetable/server/regulartt.js?__func=regularttGetData", args: [NSNull(), week.id]), week: week)
    }
}

enum ScheduleCache {
    // Each process has its own cache; no App Groups entitlement needed for sideloading.
    private static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("schedule-v2.json")
    }
    static func read() -> SchoolSchedule? {
        guard let bytes = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SchoolSchedule.self, from: bytes)
    }
    static func save(_ schedule: SchoolSchedule) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(schedule).write(to: url, options: .atomic)
    }
}
