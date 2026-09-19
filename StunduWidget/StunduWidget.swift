import WidgetKit
import SwiftUI
import AppIntents

struct GroupIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Stundu saraksts"
    static var description = IntentDescription("Izvēlies grupu, piemēram, 31. Logrīka grupa tiek saglabāta atsevišķi no aplikācijas.")
    @Parameter(title: "Grupas numurs", default: "31") var group: String
    @Parameter(title: "Pirmssvētku datums (GGGG-MM-DD)", default: "") var shortenedDate: String
    var shortenedDates: Set<String> {
        let value = shortenedDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let date = SchoolDate.iso(value), BellTimes.dateKey(date) == value else { return [] }
        return [value]
    }
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
        if let cache = ScheduleCache.read() {
            return ScheduleEntry(date: Date(), group: configuration.group, schedule: cache.applyingShortenedDates(configuration.shortenedDates), message: nil)
        }
        let loaded = await timeline(for: configuration, in: context)
        return loaded.entries.first ?? placeholder(in: context)
    }
    func timeline(for configuration: GroupIntent, in context: Context) async -> Timeline<ScheduleEntry> {
        let now = Date()
        var schedule: SchoolSchedule?
        var message: String?
        do {
            let client = EduPageClient()
            let weeks = try await client.weeks()
            // Keep the last publication visible until a new one is available.
            if let week = WidgetSelection.week(from: weeks, now: now) {
                schedule = try await client.schedule(week: week)
                if let schedule = schedule { try? ScheduleCache.save(schedule) }
            } else {
                message = "Jaunais saraksts vēl nav publicēts"
            }
        } catch {
            let cache = ScheduleCache.read()
            schedule = cache
            message = schedule == nil ? "Neizdevās ielādēt. Atver aplikāciju." : "Bezsaistē · saglabātie dati"
        }
        schedule = schedule?.applyingShortenedDates(configuration.shortenedDates)
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
    private var archived: Bool { entry.schedule.map { $0.week.until <= entry.date } ?? false }
    private var upcoming: [SchoolLesson] {
        guard let schedule = entry.schedule, let group = group else { return [] }
        return WidgetSelection.rows(schedule: schedule, groupID: group.id, now: entry.date)
    }
    private var publicationLabel: String {
        guard let week = entry.schedule?.week else { return "" }
        let dates = "\(SchoolDate.short(week.from))–\(SchoolDate.short(week.until.addingTimeInterval(-1)))"
        return archived ? "Pēdējais saraksts · \(dates)" : dates
    }
    private var status: String {
        if let message = entry.message, entry.schedule == nil { return message }
        if entry.schedule != nil && group == nil { return "Grupa nav atrasta. Rediģē logrīku." }
        return "Nav nākamo stundu. Atver sarakstu."
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(group?.short ?? "\(entry.group). grupa").font(.caption.weight(.semibold))
                Spacer()
                Image(systemName: "calendar").foregroundStyle(.blue)
            }
            if entry.schedule != nil {
                Text(publicationLabel).font(.system(size: 10, weight: .medium))
                    .foregroundStyle(archived ? Color.orange : Color.secondary).lineLimit(2)
            }
            if let first = upcoming.first {
                Text("\(SchoolDate.dayNames[first.day]) · \(first.time)")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Text(first.subject).font(.system(size: family == .systemSmall ? 17 : 19, weight: .semibold)).tracking(-0.4).lineLimit(family == .systemSmall ? 2 : 1)
                if family != .systemSmall {
                    Text([first.room, first.subgroup].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption).lineLimit(1)
                }
                if family != .systemSmall {
                    ForEach(Array(upcoming.dropFirst().prefix(family == .systemLarge ? 4 : 1))) { lesson in
                        HStack(alignment: .top) {
                            Text(lesson.start.map(SchoolDate.time) ?? "?").monospacedDigit().foregroundStyle(.blue)
                            Text(lesson.subject).lineLimit(1)
                        }.font(.caption)
                    }
                }
            } else {
                Text(status).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if archived {
                Text(entry.message ?? "Jaunais vēl nav publicēts")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            } else if let message = entry.message, entry.schedule != nil {
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
