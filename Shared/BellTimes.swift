import Foundation

/// Source: the school's bell-time table supplied by the user, September 2026.
/// Applies to periods 1–10; later periods keep their EduPage times.
enum BellTimes {
    static let monday = ["08:10–08:50", "09:20–10:00", "10:10–10:50", "11:00–11:40", "11:50–12:30", "12:40–13:20", "13:30–14:10", "14:20–15:00", "15:10–15:50", "16:00–16:40"]
    static let regular = ["08:10–08:50", "09:10–09:50", "10:00–10:40", "10:50–11:30", "11:40–12:20", "12:30–13:10", "13:20–14:00", "14:10–14:50", "15:00–15:40", "15:50–16:30"]
    static let friday = ["08:10–08:50", "09:00–09:40", "09:45–10:25", "10:30–11:10", "11:15–11:55", "12:00–12:40", "12:45–13:25", "13:30–14:10", "14:15–14:55", "15:00–15:40"]
    static let beforeHoliday = ["08:10–08:40", "09:00–09:30", "09:40–10:10", "10:20–10:50", "11:00–11:30", "11:40–12:10", "12:20–12:50", "13:00–13:30", "13:40–14:10", "14:20–14:50"]

    static func time(period: Int, field: String, day: Int, date: Date, shortened: Bool = false) -> Date? {
        guard (1...10).contains(period), (0...4).contains(day) else { return nil }
        let rows = shortened ? beforeHoliday : (day == 0 ? monday : (day == 4 ? friday : regular))
        let pair = rows[period - 1].split(separator: "–").map(String.init)
        return SchoolDate.at(pair[field == "starttime" ? 0 : 1], on: date)
    }
    static func dateKey(_ date: Date) -> String { SchoolDate.dateKey(date) }
}

extension SchoolSchedule {
    func applyingShortenedDates(_ dates: Set<String>) -> SchoolSchedule {
        guard !dates.isEmpty else { return self }
        let monday = SchoolDate.monday(week.from)
        var changedDays: [Int: Date] = [:]
        for day in 0..<7 {
            let date = SchoolDate.calendar.date(byAdding: .day, value: day, to: monday)!
            if dates.contains(BellTimes.dateKey(date)) { changedDays[day] = date }
        }
        guard !changedDays.isEmpty else { return self }
        let adjusted = lessons.map { lesson -> SchoolLesson in
            guard let date = changedDays[lesson.day] else { return lesson }
            let last = lesson.period + lesson.durationPeriods - 1
            return SchoolLesson(id: lesson.id, groupID: lesson.groupID, day: lesson.day,
                period: lesson.period, durationPeriods: lesson.durationPeriods, subject: lesson.subject,
                teacher: lesson.teacher, room: lesson.room, subgroup: lesson.subgroup,
                start: BellTimes.time(period: lesson.period, field: "starttime", day: lesson.day, date: date, shortened: true) ?? lesson.start,
                end: BellTimes.time(period: last, field: "endtime", day: lesson.day, date: date, shortened: true) ?? lesson.end)
        }
        return SchoolSchedule(week: week, groups: groups, lessons: adjusted, fetchedAt: fetchedAt)
    }
}
