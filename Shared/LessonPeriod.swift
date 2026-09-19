import Foundation

struct LessonPeriod: Identifiable {
    let number: Int
    let start: Date?
    let end: Date?
    var id: Int { number }
    var time: String { "\(start.map(SchoolDate.time) ?? "?")–\(end.map(SchoolDate.time) ?? "?")" }
    func contains(_ date: Date) -> Bool {
        guard let start = start, let end = end else { return false }
        return start <= date && date < end
    }
}

extension SchoolLesson {
    func periodTimes(on date: Date, shortened: Bool) -> [LessonPeriod] {
        (0..<max(1, durationPeriods)).map { offset in
            let number = period + offset
            return LessonPeriod(number: number,
                start: BellTimes.time(period: number, field: "starttime", day: day, date: date, shortened: shortened)
                    ?? (offset == 0 ? start : nil),
                end: BellTimes.time(period: number, field: "endtime", day: day, date: date, shortened: shortened)
                    ?? (offset == durationPeriods - 1 ? end : nil))
        }
    }
}
