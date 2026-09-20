import Foundation

enum WidgetSelection {
    static func week(from weeks: [PublishedWeek], now: Date) -> PublishedWeek? {
        weeks.filter { $0.contains(now) }.max { $0.from < $1.from }
            ?? weeks.filter { $0.from > now }.min { $0.from < $1.from }
            ?? weeks.max { $0.from < $1.from }
    }
    static func prepare(_ schedule: SchoolSchedule, group: String, shortenedDates: Set<String>) -> SchoolSchedule {
        let own = schedule.group(matching: group).map { schedule.lessons(for: $0.id) } ?? []
        let monday = SchoolDate.monday(schedule.week.from)
        let parts = own.flatMap { lesson -> [SchoolLesson] in
            let date = SchoolDate.calendar.date(byAdding: .day, value: lesson.day, to: monday)!
            return lesson.splitPeriods(on: date, shortened: shortenedDates.contains(BellTimes.dateKey(date)))
        }
        return SchoolSchedule(week: schedule.week, groups: schedule.groups, lessons: parts, fetchedAt: schedule.fetchedAt)
            .applyingShortenedDates(shortenedDates)
    }
    static func next(schedule: SchoolSchedule, groupID: String, now: Date) -> SchoolLesson? {
        let all = schedule.lessons(for: groupID)
        if schedule.week.until <= now { return all.first }
        return all.filter { ($0.start ?? .distantPast) > now }
            .min { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
    }
    static func day(schedule: SchoolSchedule, groupID: String, now: Date) -> Int {
        if schedule.week.contains(now), SchoolDate.day(now) < 5 { return SchoolDate.day(now) }
        return next(schedule: schedule, groupID: groupID, now: now)?.day
            ?? schedule.lessons(for: groupID).first?.day ?? 0
    }
    static func rows(schedule: SchoolSchedule, groupID: String, now: Date) -> [SchoolLesson] {
        schedule.lessons(for: groupID, day: day(schedule: schedule, groupID: groupID, now: now))
    }
}
