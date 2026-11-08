import Foundation

/// Files that keep the app usable on a weak or missing school network.
/// Plain Codable JSON in Application Support: the app and the widget run in separate
/// processes without a shared App Group (sideloaded), so each keeps its own copy.
/// Writes are atomic, and a file that no longer decodes is deleted instead of breaking the app.
enum OfflineStore {
    /// Tests point this at a temporary folder.
    static var rootOverride: URL?
    static var root: URL {
        rootOverride ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
    static let keptWeeks = 6

    static func read<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        let url = root.appendingPathComponent(name)
        guard let bytes = try? Data(contentsOf: url) else { return nil }
        do { return try JSONDecoder().decode(type, from: bytes) }
        catch {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }
    static func write<T: Encodable>(_ value: T, to name: String) throws {
        let url = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }

    // MARK: Published weeks
    static func readWeeks() -> [PublishedWeek] { read([PublishedWeek].self, from: "weeks-v1.json") ?? [] }
    static func saveWeeks(_ weeks: [PublishedWeek]) { try? write(weeks, to: "weeks-v1.json") }

    // MARK: Every week that was opened, so browsing still works offline
    private static func weekFile(_ id: String) -> String {
        "weeks/" + id.addingPercentEncoding(withAllowedCharacters: .alphanumerics)! + ".json"
    }
    static func schedule(weekID: String) -> SchoolSchedule? { read(SchoolSchedule.self, from: weekFile(weekID)) }
    static func save(_ schedule: SchoolSchedule) {
        try? write(schedule, to: weekFile(schedule.week.id))
        prune()
    }
    static func savedWeekIDs() -> Set<String> {
        let folder = root.appendingPathComponent("weeks")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return Set(files.compactMap { $0.hasSuffix(".json") ? String($0.dropLast(5)).removingPercentEncoding : nil })
    }
    /// Keeps only the newest weeks so storage does not grow all year.
    private static func prune() {
        let saved = savedWeekIDs().compactMap { schedule(weekID: $0) }.sorted { $0.week.from > $1.week.from }
        for old in saved.dropFirst(keptWeeks) {
            try? FileManager.default.removeItem(at: root.appendingPathComponent(weekFile(old.week.id)))
        }
    }
}

/// The current week, also read by the widget.
enum ScheduleCache {
    static func read() -> SchoolSchedule? { OfflineStore.read(SchoolSchedule.self, from: "schedule-v2.json") }
    static func save(_ schedule: SchoolSchedule) throws {
        try OfflineStore.write(schedule, to: "schedule-v2.json")
        OfflineStore.save(schedule)
    }
}

/// Timetable changes per day (yyyy-MM-dd), kept for two weeks.
enum SubstitutionCache {
    static func read() -> [String: SubstitutionDay] {
        OfflineStore.read([String: SubstitutionDay].self, from: "substitutions-v1.json") ?? [:]
    }
    static func save(_ days: [String: SubstitutionDay], now: Date = Date()) {
        let cutoff = SchoolDate.dateKey(now.addingTimeInterval(-14 * 86400))
        let merged = read().merging(days) { $1 }.filter { $0.key >= cutoff }
        try? OfflineStore.write(merged, to: "substitutions-v1.json")
    }
}
