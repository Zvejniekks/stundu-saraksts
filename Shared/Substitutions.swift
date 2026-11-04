import Foundation

/// One line from EduPage's daily "Aizvietošanas" (substitutions) page.
struct SubstitutionEntry: Codable, Hashable, Identifiable {
    let group: String
    let firstPeriod: Int?
    let lastPeriod: Int?
    let text: String
    let kind: String
    var id: String { "\(group)|\(firstPeriod ?? 0)-\(lastPeriod ?? 0)|\(text)" }
    var isCancelled: Bool { text.localizedCaseInsensitiveContains("nenotiek") || kind == "remove" }
    var periodText: String {
        guard let a = firstPeriod else { return "Visa diena" }
        guard let b = lastPeriod, b != a else { return "\(a)." }
        return "\(a).–\(b)."
    }
    func covers(_ lesson: SchoolLesson) -> Bool {
        guard let a = firstPeriod else { return true }
        let b = lastPeriod ?? a
        let lessonEnd = lesson.period + max(1, lesson.durationPeriods) - 1
        return lesson.period <= b && lessonEnd >= a
    }
}

struct SubstitutionDay: Codable {
    let date: String
    let entries: [SubstitutionEntry]
    let fetchedAt: Date
    func entries(for group: SchoolGroup?) -> [SubstitutionEntry] {
        guard let group = group else { return [] }
        return entries.filter { SubstitutionParser.matches($0.group, group: group) }
    }
}

enum SubstitutionParser {
    static func matches(_ header: String, group: SchoolGroup) -> Bool {
        let h = header.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // EduPage names are not always tidy ("2.k. 17.grupa ", "2.k.12.grupa").
        let name = group.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let short = group.short.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return h == name || h == short || (!short.isEmpty && h.hasSuffix(" " + short))
    }

    static func parse(html: String, date: String) -> SubstitutionDay {
        var entries: [SubstitutionEntry] = []
        let sections = html.components(separatedBy: "class=\"section").dropFirst()
        let headerRegex = try! NSRegularExpression(pattern: #"class="header"[^>]*>(.*?)</div>"#, options: [.dotMatchesLineSeparators])
        let rowRegex = try! NSRegularExpression(
            pattern: #"class="row([^"]*)"[^>]*>(?:<div class="period"[^>]*>(.*?)</div>)?<div class="info"[^>]*>(.*?)</div>"#,
            options: [.dotMatchesLineSeparators])
        for section in sections {
            let ns = section as NSString
            guard let h = headerRegex.firstMatch(in: section, range: NSRange(location: 0, length: ns.length)) else { continue }
            let group = clean(ns.substring(with: h.range(at: 1)))
            for m in rowRegex.matches(in: section, range: NSRange(location: 0, length: ns.length)) {
                let kind = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
                let period = m.range(at: 2).location == NSNotFound ? "" : clean(ns.substring(with: m.range(at: 2)))
                let text = clean(ns.substring(with: m.range(at: 3)))
                guard !text.isEmpty else { continue }
                let numbers = period.split { !$0.isNumber }.compactMap { Int($0) }
                entries.append(SubstitutionEntry(group: group, firstPeriod: numbers.first, lastPeriod: numbers.last,
                                                 text: text, kind: kind))
            }
        }
        return SubstitutionDay(date: date, entries: entries, fetchedAt: Date())
    }

    static func clean(_ html: String) -> String {
        var s = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (from, to) in [("&nbsp;", " "), ("&quot;", "\""), ("&#039;", "'"), ("&#39;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&amp;", "&")] {
            s = s.replacingOccurrences(of: from, with: to)
        }
        return s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension EduPageClient {
    func substitutions(on date: Date) async throws -> SubstitutionDay {
        let key = SchoolDate.dateKey(date)
        let result = try await rawRPC("/substitution/server/viewer.js?__func=getSubstViewerDayDataHtml",
                                      args: [NSNull(), ["date": key, "mode": "classes"]])
        guard let html = result as? String else {
            throw ScheduleError.message("EduPage neatgrieza stundu izmaiņas.")
        }
        return SubstitutionParser.parse(html: html, date: key)
    }
}

/// Remembers which changes the user has already been told about.
enum SubstitutionAlerts {
    private static let key = "notifiedSubstitutions"
    static func unseen(_ entries: [SubstitutionEntry], date: String, defaults: UserDefaults = .standard) -> [SubstitutionEntry] {
        let seen = Set(defaults.stringArray(forKey: key) ?? [])
        return entries.filter { !seen.contains(date + "|" + $0.id) }
    }
    static func markSeen(_ entries: [SubstitutionEntry], date: String, defaults: UserDefaults = .standard) {
        var seen = defaults.stringArray(forKey: key) ?? []
        seen += entries.map { date + "|" + $0.id }
        // Keep only recent days so the list does not grow forever.
        let cutoff = SchoolDate.dateKey(Date().addingTimeInterval(-14 * 86400))
        seen = Array(Set(seen.filter { String($0.prefix(10)) >= cutoff })).sorted()
        defaults.set(seen, forKey: key)
    }
}

/// What a substitution did to one lesson, with the values it replaced.
struct LessonChange: Codable, Hashable {
    let text: String
    let cancelled: Bool
    let previousSubject: String?
    let previousTeacher: String?
    let previousRoom: String?
}

/// The new values EduPage writes as "(old) ➔ new" inside a change line.
struct SubstitutionCorrection: Equatable {
    var subgroup: String?
    var subject: String?
    var teacher: String?
    var room: String?
    var cancelled = false
}

extension SubstitutionEntry {
    var correction: SubstitutionCorrection {
        var result = SubstitutionCorrection(cancelled: isCancelled)
        var head = text, detail = ""
        if let r = text.range(of: " - ") { head = String(text[..<r.lowerBound]); detail = String(text[r.upperBound...]) }
        // "2.grupa: Subject" means only that subgroup is affected.
        if let r = head.range(of: #"^\s*\d+\.\s*grupa:\s*"#, options: .regularExpression) {
            result.subgroup = head[r].replacingOccurrences(of: ":", with: "").trimmingCharacters(in: .whitespaces)
            head = String(head[r.upperBound...])
        }
        if let arrow = head.range(of: "➔") {
            result.subject = clean(String(head[arrow.upperBound...]))
        }
        func value(after label: String) -> String? {
            guard let r = detail.range(of: label) else { return nil }
            var rest = String(detail[r.upperBound...])
            if let arrow = rest.range(of: "➔") , !rest[..<arrow.lowerBound].contains(",") {
                rest = String(rest[arrow.upperBound...])
            }
            let v = rest.components(separatedBy: ", ").first.map(clean) ?? ""
            return v.isEmpty ? nil : v
        }
        result.teacher = value(after: "Aizvietošana:") ?? value(after: "Skolotājs:")
        result.room = value(after: "Mainīt kabinetu:") ?? value(after: "Kabinets:")
        return result
    }
    private func clean(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "()")))
    }
}

extension SchoolLesson {
    /// The lesson as it actually happens on its day, after that day's substitutions.
    func applying(_ entries: [SubstitutionEntry]) -> SchoolLesson {
        guard let entry = entries.first(where: { $0.firstPeriod != nil && $0.covers(self) && applies($0) }) else { return self }
        let fix = entry.correction
        var copy = SchoolLesson(id: id, groupID: groupID, day: day, period: period, durationPeriods: durationPeriods,
                                subject: fix.subject ?? subject, teacher: fix.teacher ?? teacher, room: fix.room ?? room,
                                subgroup: subgroup, start: start, end: end)
        copy.change = LessonChange(text: entry.text, cancelled: fix.cancelled,
                                   previousSubject: fix.subject.flatMap { $0 == subject ? nil : subject },
                                   previousTeacher: fix.teacher.flatMap { $0 == teacher || teacher.isEmpty ? nil : teacher },
                                   previousRoom: fix.room.flatMap { $0 == room || room.isEmpty ? nil : room })
        return copy
    }
    private func applies(_ entry: SubstitutionEntry) -> Bool {
        guard let only = entry.correction.subgroup, !subgroup.isEmpty else { return true }
        let a = only.replacingOccurrences(of: " ", with: "").lowercased()
        return subgroup.replacingOccurrences(of: " ", with: "").lowercased().contains(a)
    }
}

extension SchoolSchedule {
    /// Replaces lessons with their changed versions; `changes` is keyed by yyyy-MM-dd.
    func applyingChanges(_ changes: [String: SubstitutionDay], group: SchoolGroup?) -> SchoolSchedule {
        guard !changes.isEmpty, let group = group else { return self }
        let monday = SchoolDate.monday(week.from)
        let updated = lessons.map { lesson -> SchoolLesson in
            guard lesson.groupID == group.id else { return lesson }
            let date = SchoolDate.calendar.date(byAdding: .day, value: lesson.day, to: monday)!
            return lesson.applying(changes[SchoolDate.dateKey(date)]?.entries(for: group) ?? [])
        }
        return SchoolSchedule(week: week, groups: groups, lessons: updated, fetchedAt: fetchedAt)
    }
}

extension EduPageClient {
    /// Changes for the school days of `week` from today on. Missing days failed to load.
    func substitutions(for week: PublishedWeek, now: Date = Date()) async -> [String: SubstitutionDay] {
        let c = SchoolDate.calendar, today = c.startOfDay(for: now)
        var result: [String: SubstitutionDay] = [:]
        for offset in 0..<5 {
            guard let date = c.date(byAdding: .day, value: offset, to: SchoolDate.monday(week.from)), date >= today else { continue }
            if let day = try? await substitutions(on: date) { result[day.date] = day }
        }
        return result
    }
}

enum SubstitutionCache {
    private static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("substitutions-v1.json")
    }
    static func read() -> [String: SubstitutionDay] {
        guard let bytes = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: SubstitutionDay].self, from: bytes)) ?? [:]
    }
    static func save(_ days: [String: SubstitutionDay]) {
        let cutoff = SchoolDate.dateKey(Date().addingTimeInterval(-7 * 86400))
        let merged = read().merging(days) { $1 }.filter { $0.key >= cutoff }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(merged).write(to: url, options: .atomic)
    }
}
