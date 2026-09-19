import Foundation

enum WidgetSelection {
    static func week(from weeks: [PublishedWeek], now: Date) -> PublishedWeek? {
        weeks.filter { $0.contains(now) }.max { $0.from < $1.from }
            ?? weeks.filter { $0.from > now }.min { $0.from < $1.from }
            ?? weeks.max { $0.from < $1.from }
    }
    static func rows(schedule: SchoolSchedule, groupID: String, now: Date) -> [SchoolLesson] {
        let all = schedule.lessons(for: groupID)
        let upcoming = all.filter { ($0.end ?? $0.start ?? .distantPast) > now }
        if let first = upcoming.first {
            return upcoming.filter { $0.day == first.day }
        }
        // A dated overview, not old lessons relabelled as upcoming lessons.
        let today = all.filter { $0.day == SchoolDate.day(now) }
        if schedule.week.contains(now), !today.isEmpty { return today }
        guard let first = all.first else { return [] }
        return all.filter { $0.day == first.day }
    }
}
