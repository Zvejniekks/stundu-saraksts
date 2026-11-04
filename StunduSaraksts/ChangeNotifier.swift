import Foundation
import UserNotifications
import BackgroundTasks

/// Local notifications about new timetable changes for the saved group.
/// Runs when the app opens and in iOS background refresh (no server needed).
enum ChangeNotifier {
    static let taskID = "com.toms.stundusaraksts.changes"
    static let enabledKey = "notifyChanges"
    static var enabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Today (until school ends) and the next school day.
    static func datesToCheck(now: Date = Date()) -> [Date] {
        let c = SchoolDate.calendar
        var dates: [Date] = []
        let today = c.startOfDay(for: now)
        if SchoolDate.day(today) < 5, c.component(.hour, from: now) < 17 { dates.append(today) }
        let next = WidgetSelection.schoolDay(c.date(byAdding: .day, value: 1, to: today)!)
        if !dates.contains(next) { dates.append(next) }
        return dates
    }

    static func check() async {
        guard enabled else { return }
        let saved = UserDefaults.standard.string(forKey: "selectedGroup") ?? "31"
        guard let group = ScheduleCache.read()?.group(matching: saved) else { return }
        let client = EduPageClient()
        for date in datesToCheck() {
            guard let day = try? await client.substitutions(on: date) else { continue }
            let fresh = SubstitutionAlerts.unseen(day.entries(for: group), date: day.date)
            guard !fresh.isEmpty else { continue }
            await post(fresh, date: date, key: day.date)
            SubstitutionAlerts.markSeen(fresh, date: day.date)
        }
    }

    private static func post(_ entries: [SubstitutionEntry], date: Date, key: String) async {
        let c = SchoolDate.calendar
        let when = c.isDateInToday(date) ? "Šodien" : (c.isDateInTomorrow(date) ? "Rīt" : SchoolDate.dayNames[SchoolDate.day(date)])
        let content = UNMutableNotificationContent()
        content.title = "Stundu izmaiņas · \(when)"
        content.body = entries.prefix(4).map { "\($0.periodText) st.: \($0.text)" }.joined(separator: "\n")
            + (entries.count > 4 ? "\n+ vēl \(entries.count - 4)" : "")
        content.sound = .default
        let request = UNNotificationRequest(identifier: "changes-\(key)-\(entries.count)-\(abs(entries.map(\.id).joined().hashValue))",
                                            content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func scheduleBackgroundRefresh() {
        guard enabled else { return }
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date().addingTimeInterval(30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
