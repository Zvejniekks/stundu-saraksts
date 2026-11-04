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
        let name = group.name.lowercased(), short = group.short.lowercased()
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
