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
            return ScheduleEntry(date: Date(), group: configuration.group, schedule: WidgetSelection.prepare(cache, group: configuration.group, shortenedDates: configuration.shortenedDates), message: nil)
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
        schedule = schedule.map { WidgetSelection.prepare($0, group: configuration.group, shortenedDates: configuration.shortenedDates) }
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
    private var all: [SchoolLesson] { group.flatMap { entry.schedule?.lessons(for: $0.id) } ?? [] }
    private var next: SchoolLesson? {
        guard let schedule = entry.schedule, let group = group else { return nil }
        return WidgetSelection.next(schedule: schedule, groupID: group.id, now: entry.date)
    }
    private var day: Int {
        guard let schedule = entry.schedule, let group = group else { return 0 }
        return WidgetSelection.day(schedule: schedule, groupID: group.id, now: entry.date)
    }
    private var dayRows: [SchoolLesson] { all.filter { $0.day == day } }
    private var periodNumbers: [Int] {
        guard let last = all.map(\.period).max(), last > 0 else { return Array(1...10) }
        return Array(1...last)
    }
    private var publication: String {
        guard let week = entry.schedule?.week else { return "" }
        let range = "\(SchoolDate.short(week.from))–\(SchoolDate.short(week.until.addingTimeInterval(-1)))"
        return archived ? "Pēdējais · \(range)" : range
    }
    private var status: String {
        if entry.schedule == nil { return entry.message ?? "Ielādē sarakstu…" }
        if group == nil { return "Grupa nav atrasta. Rediģē logrīku." }
        return "Nav nākamo stundu"
    }
    var body: some View {
        Group {
            if entry.schedule == nil || group == nil {
                VStack(alignment: .leading, spacing: 12) {
                    header("Stundu saraksts")
                    Text(status).font(.subheadline).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            } else {
                switch family {
                case .systemSmall: small
                case .systemMedium: medium
                default: large
                }
            }
        }.containerBackground(.background, for: .widget)
    }
    private func header(_ title: String) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
            Spacer(minLength: 2)
            Text(group?.short ?? "\(entry.group). grupa")
                .font(.system(size: 10, weight: .medium)).foregroundStyle(.blue).lineLimit(1)
        }
    }
    private var publicationView: some View {
        HStack(spacing: 3) {
            Text(publication)
            if entry.message != nil { Image(systemName: "wifi.slash") }
        }.font(.system(size: 9)).foregroundStyle(archived ? Color.orange : Color.secondary).lineLimit(1)
    }
    private var small: some View {
        VStack(alignment: .leading, spacing: 7) {
            header(archived ? "Pārskats" : "Nākamā")
            if let lesson = next {
                Text(lesson.start.map(SchoolDate.time) ?? "—")
                    .font(.system(size: 29, weight: .bold)).tracking(-1).foregroundStyle(.blue)
                Text(lesson.subject).font(.system(size: 15, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.85)
                HStack(spacing: 4) {
                    Text(String(SchoolDate.dayNames[lesson.day].prefix(2)) + ".")
                    if !lesson.room.isEmpty { Text("· " + lesson.room) }
                }.font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            } else {
                Text("Nav nākamo stundu").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            publicationView
        }
    }
    private var medium: some View {
        VStack(alignment: .leading, spacing: 6) {
            header(SchoolDate.dayNames[day])
            if dayRows.isEmpty {
                Text("Šai dienai nav stundu").font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                let half = (dayRows.count + 1) / 2
                HStack(alignment: .top, spacing: 12) {
                    dayColumn(Array(dayRows.prefix(half)))
                    Rectangle().fill(Color.secondary.opacity(0.15)).frame(width: 1)
                    dayColumn(Array(dayRows.dropFirst(half)))
                }.frame(maxHeight: .infinity)
            }
            publicationView
        }
    }
    private func dayColumn(_ rows: [SchoolLesson]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(rows) { lesson in
                HStack(spacing: 4) {
                    Text(lesson.start.map(SchoolDate.time) ?? "—")
                        .font(.system(size: 9, weight: .medium)).monospacedDigit().foregroundStyle(.blue)
                    Text(compact(lesson.subject)).font(.system(size: 10, weight: .medium))
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    if !lesson.room.isEmpty {
                        Text(lesson.room).font(.system(size: 8)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }.frame(maxHeight: .infinity, alignment: .center)
                    .accessibilityLabel("\(lesson.time), \(lesson.subject), \(lesson.room)")
            }
            if rows.isEmpty { Spacer(minLength: 0) }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var large: some View {
        VStack(alignment: .leading, spacing: 6) {
            header("Visa nedēļa")
            HStack(spacing: 3) {
                Color.clear.frame(width: 14, height: 15)
                ForEach(0..<5) { day in
                    Text(["Pr", "Ot", "Tr", "Ce", "Pk"][day])
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            VStack(spacing: 3) {
                ForEach(periodNumbers, id: \.self) { period in
                    HStack(spacing: 3) {
                        Text("\(period)").font(.system(size: 9)).foregroundStyle(.secondary).frame(width: 14)
                        ForEach(0..<5) { day in
                            weekCell(all.filter { $0.day == day && $0.period == period })
                        }
                    }.frame(maxHeight: .infinity)
                }
            }.frame(maxHeight: .infinity)
            publicationView
        }
    }
    private func weekCell(_ lessons: [SchoolLesson]) -> some View {
        VStack(spacing: 1) {
            if lessons.isEmpty {
                Text("·").foregroundStyle(.quaternary)
            } else {
                ForEach(lessons) { lesson in
                    Text(compact(lesson.subject))
                        .font(.system(size: 9, weight: .medium)).lineLimit(2).minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("\(lesson.period). stunda, \(lesson.subject), \(lesson.room)")
                }
            }
        }.padding(.horizontal, 2).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(lessons.isEmpty ? Color.secondary.opacity(0.04) : Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 5))
    }
    private func compact(_ subject: String) -> String {
        let words = subject.split(whereSeparator: { $0.isWhitespace })
        if subject.count <= 13 { return subject }
        return words.map { $0.count > 5 ? String($0.prefix(4)) + "." : String($0) }.joined(separator: " ")
    }
}

@main
struct StunduWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "StunduWidget", intent: GroupIntent.self, provider: ScheduleProvider()) { entry in
            ScheduleWidgetView(entry: entry)
        }
        .configurationDisplayName("Stundu Saraksts")
        .description("Mazais: nākamā stunda. Vidējais: visa diena. Lielais: visa nedēļa.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
