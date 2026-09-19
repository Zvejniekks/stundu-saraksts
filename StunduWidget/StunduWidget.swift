import WidgetKit
import SwiftUI
import AppIntents

struct GroupIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Stundu saraksts"
    static var description = IntentDescription("Izvēlies grupu, piemēram, 31. Logrīka grupa tiek saglabāta atsevišķi no aplikācijas.")
    @Parameter(title: "Grupas numurs", default: "31") var group: String
}

struct ScheduleEntry: TimelineEntry {
    let date: Date
    let group: String
    let schedule: SchoolSchedule?
    let message: String?
}

struct ScheduleProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(date: Date(), group: "31", schedule: nil, message: "Tavas nākamās stundas")
    }
    func snapshot(for configuration: GroupIntent, in context: Context) async -> ScheduleEntry {
        ScheduleEntry(date: Date(), group: configuration.group, schedule: ScheduleCache.read(), message: nil)
    }
    func timeline(for configuration: GroupIntent, in context: Context) async -> Timeline<ScheduleEntry> {
        let now = Date()
        var schedule: SchoolSchedule?
        var message: String?
        do {
            let client = EduPageClient()
            let weeks = try await client.weeks()
            // Choose today's publication or the nearest future publication. Old weeks are not reused.
            if let week = weeks.first(where: { $0.contains(now) }) ?? weeks.filter({ $0.from > now }).min(by: { $0.from < $1.from }) {
                schedule = try await client.schedule(week: week)
                if let schedule = schedule { try? ScheduleCache.save(schedule) }
            } else {
                message = "Jaunais saraksts vēl nav publicēts"
            }
        } catch {
            let cache = ScheduleCache.read()
            if let cache = cache, cache.week.until > now { schedule = cache }
            message = schedule == nil ? "Neizdevās ielādēt. Atver aplikāciju." : "Bezsaistē · saglabātie dati"
        }
        var dates = [now]
        if let schedule = schedule, let group = schedule.group(matching: configuration.group) {
            let horizon = now.addingTimeInterval(6 * 3600)
            dates += schedule.lessons(for: group.id).flatMap { [$0.start, $0.end].compactMap { $0 } }
                .filter { $0 > now && $0 < horizon }
        }
        let entries = Array(Set(dates)).sorted().map {
            ScheduleEntry(date: $0, group: configuration.group, schedule: schedule, message: message)
        }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(3600)))
    }
}

struct ScheduleWidgetView: View {
    let entry: ScheduleEntry
    @Environment(\.widgetFamily) private var family
    private var group: SchoolGroup? { entry.schedule?.group(matching: entry.group) }
    private var upcoming: [SchoolLesson] {
        guard let schedule = entry.schedule, let group = group, schedule.week.until > entry.date else { return [] }
        return schedule.lessons(for: group.id).filter {
            if let end = $0.end { return end > entry.date }
            if let start = $0.start { return start > entry.date }
            return false
        }.sorted { ($0.day, $0.period, $0.id) < ($1.day, $1.period, $1.id) }
    }
    private var status: String {
        if let message = entry.message, entry.schedule == nil { return message }
        if entry.schedule != nil && group == nil { return "Grupa nav atrasta. Rediģē logrīku." }
        return "Nav nākamo stundu. Atver sarakstu."
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(group?.short ?? "\(entry.group). grupa").font(.caption.bold())
                Spacer()
                Image(systemName: "calendar").foregroundStyle(.indigo)
            }
            if let first = upcoming.first {
                Text("\(SchoolDate.dayNames[first.day]) · \(first.time)")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Text(first.subject).font(.headline).lineLimit(family == .systemSmall ? 2 : 1)
                Text([first.room, first.subgroup].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).lineLimit(1)
                if family != .systemSmall {
                    ForEach(Array(upcoming.dropFirst().prefix(family == .systemLarge ? 4 : 1))) { lesson in
                        HStack(alignment: .top) {
                            Text(lesson.start.map(SchoolDate.time) ?? "?").monospacedDigit()
                            Text(lesson.subject).lineLimit(1)
                        }.font(.caption)
                    }
                }
            } else {
                Text(status).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let message = entry.message, entry.schedule != nil {
                Text(message).font(.caption2).foregroundStyle(.orange).lineLimit(1)
            } else if let schedule = entry.schedule {
                Text("Dati \(SchoolDate.short(schedule.fetchedAt)) \(SchoolDate.time(schedule.fetchedAt))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }.containerBackground(.background, for: .widget)
    }
}

@main
struct StunduWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "StunduWidget", intent: GroupIntent.self, provider: ScheduleProvider()) { entry in
            ScheduleWidgetView(entry: entry)
        }
        .configurationDisplayName("Stundu Saraksts")
        .description("Nākamās stundas, laiki un kabineti. Grupu maini logrīka iestatījumos.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
