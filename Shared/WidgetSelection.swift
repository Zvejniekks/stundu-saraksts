import Foundation

enum WidgetSelection {
    static let nextDayHour = 17
    // Weekends count as the coming Monday.
    static func schoolDay(_ date: Date) -> Date {
        let start = SchoolDate.calendar.startOfDay(for: date)
        guard SchoolDate.day(start) >= 5 else { return start }
        return SchoolDate.calendar.date(byAdding: .day, value: 7, to: SchoolDate.monday(start))!
    }
    // The day the day widget shows: from 17:00 it is already the next school day.
    static func displayDate(_ now: Date) -> Date {
        let c = SchoolDate.calendar
        guard c.component(.hour, from: now) >= nextDayHour else { return schoolDay(now) }
        return schoolDay(c.date(byAdding: .day, value: 1, to: now)!)
    }
    static func nextDaySwitch(after now: Date) -> Date {
        let c = SchoolDate.calendar
        let today = c.date(bySettingHour: nextDayHour, minute: 0, second: 0, of: now)!
        return today > now ? today : c.date(byAdding: .day, value: 1, to: today)!
    }
    static func week(from weeks: [PublishedWeek], now: Date) -> PublishedWeek? {
        week(from: weeks, on: displayDate(now))
    }
    static func week(from weeks: [PublishedWeek], on date: Date) -> PublishedWeek? {
        weeks.filter { $0.contains(date) }.max { $0.from < $1.from }
            ?? weeks.filter { $0.from > date }.min { $0.from < $1.from }
            ?? weeks.max { $0.from < $1.from }
    }
    static func prepare(_ schedule: SchoolSchedule, group: String, shortenedDates: Set<String>,
                        changes: [String: SubstitutionDay] = [:]) -> SchoolSchedule {
        let own = (schedule.group(matching: group).map { schedule.lessons(for: $0.id) } ?? []).filter { !$0.isLunch }
        let monday = SchoolDate.monday(schedule.week.from)
        let parts = own.flatMap { lesson -> [SchoolLesson] in
            let date = SchoolDate.calendar.date(byAdding: .day, value: lesson.day, to: monday)!
            return lesson.splitPeriods(on: date, shortened: shortenedDates.contains(BellTimes.dateKey(date)))
        }
        return SchoolSchedule(week: schedule.week, groups: schedule.groups, lessons: parts, fetchedAt: schedule.fetchedAt)
            .applyingShortenedDates(shortenedDates)
            .applyingChanges(changes, group: schedule.group(matching: group))
    }
    static func next(schedule: SchoolSchedule, groupID: String, now: Date) -> SchoolLesson? {
        let all = schedule.lessons(for: groupID).filter { !$0.isLunch && $0.change?.cancelled != true }
        if schedule.week.until <= now { return all.first }
        return all.filter { ($0.start ?? .distantPast) > now }
            .min { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
    }
    static func day(schedule: SchoolSchedule, groupID: String, now: Date) -> Int {
        let target = displayDate(now)
        if schedule.week.contains(target) { return SchoolDate.day(target) }
        // Next week is not published or loaded yet: stay on today.
        if schedule.week.contains(now), SchoolDate.day(now) < 5 { return SchoolDate.day(now) }
        return next(schedule: schedule, groupID: groupID, now: now)?.day
            ?? schedule.lessons(for: groupID).first(where: { !$0.isLunch })?.day ?? 0
    }
    static func rows(schedule: SchoolSchedule, groupID: String, now: Date) -> [SchoolLesson] {
        schedule.lessons(for: groupID, day: day(schedule: schedule, groupID: groupID, now: now)).filter { !$0.isLunch }
    }
    static func columns(_ rows: [SchoolLesson]) -> (left: [SchoolLesson], right: [SchoolLesson]) {
        let half = (rows.count + 1) / 2
        return (Array(rows.prefix(half)), Array(rows.dropFirst(half)))
    }
    static func periodNumbers(_ rows: [SchoolLesson]) -> [Int] {
        guard let last = rows.filter({ !$0.isLunch }).map(\.period).max(), last > 0 else { return [] }
        return Array(1...last)
    }

}

extension SchoolLesson {
    var isLunch: Bool {
        let name = subject.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "lv_LV"))
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return ["pusdienas", "pusd", "pusdienu partraukums"].contains(name)
    }
}
