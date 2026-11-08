import Foundation

/// Fixed data for UI tests (launch argument `-uiTesting`), so they never depend on EduPage.
enum SampleData {
    static var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }

    static let group = SchoolGroup(id: "-257", name: "2.k. 31.grupa", short: "31.grupa")

    static func schedule(now: Date = Date()) -> SchoolSchedule {
        let monday = SchoolDate.monday(WidgetSelection.schoolDay(now))
        let week = PublishedWeek(id: "sample", title: "Paraugs", from: monday,
                                 until: SchoolDate.calendar.date(byAdding: .day, value: 5, to: monday)!)
        let plan: [(Int, String, String, String, String, String)] = [
            (1, "08:30", "09:10", "Matemātika", "Ozola Anna", "212."),
            (2, "09:20", "10:00", "Latviešu valoda", "Bērziņš Jānis", "305."),
            (3, "10:10", "10:50", "Programmēšana", "Uškāns Kaspars", "V115."),
            (4, "11:00", "11:40", "Pusdienas", "", ""),
            (5, "11:50", "12:30", "Angļu valoda", "Krastiņa Sanita", "213.")
        ]
        var lessons: [SchoolLesson] = []
        for day in 0..<5 {
            let date = SchoolDate.calendar.date(byAdding: .day, value: day, to: monday)!
            for (period, start, end, subject, teacher, room) in plan {
                lessons.append(SchoolLesson(id: "s-\(day)-\(period)", groupID: group.id, day: day, period: period,
                    durationPeriods: 1, subject: subject, teacher: teacher, room: room, subgroup: "",
                    start: SchoolDate.at(start, on: date), end: SchoolDate.at(end, on: date)))
            }
        }
        return SchoolSchedule(week: week, groups: [group], lessons: lessons, fetchedAt: now)
    }

    /// One change on every day: the 5th lesson moves to another room with another teacher.
    static func changes(for schedule: SchoolSchedule) -> [String: SubstitutionDay] {
        var result: [String: SubstitutionDay] = [:]
        for day in 0..<5 {
            let key = SchoolDate.dateKey(SchoolDate.calendar.date(byAdding: .day, value: day, to: schedule.week.from)!)
            let entry = SubstitutionEntry(group: group.name, firstPeriod: 5, lastPeriod: 5,
                text: "(Angļu valoda) ➔ Programmēšana - Aizvietošana: (Krastiņa Sanita) ➔ Uškāns Kaspars, Mainīt kabinetu: (213.) ➔ V115.",
                kind: "change")
            result[key] = SubstitutionDay(date: key, entries: [entry], fetchedAt: schedule.fetchedAt)
        }
        return result
    }
}
