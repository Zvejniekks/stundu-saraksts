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
    var lunch: [Int: String] = [:]
}

struct ScheduleProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(date: Date(), group: "31", schedule: nil, message: "Tavas nākamās stundas")
    }
    func snapshot(for configuration: GroupIntent, in context: Context) async -> ScheduleEntry {
        if let cache = ScheduleCache.read() {
            return ScheduleEntry(date: Date(), group: configuration.group, schedule: WidgetSelection.prepare(cache, group: configuration.group, shortenedDates: configuration.shortenedDates, changes: SubstitutionCache.read()), message: nil,
                                 lunch: WidgetSelection.lunchTimes(cache, group: configuration.group, shortenedDates: configuration.shortenedDates))
        }
        let loaded = await timeline(for: configuration, in: context)
        return loaded.entries.first ?? placeholder(in: context)
    }
    func timeline(for configuration: GroupIntent, in context: Context) async -> Timeline<ScheduleEntry> {
        let now = Date()
        var schedule: SchoolSchedule?
        var message: String?
        var changes = SubstitutionCache.read()
        do {
            let client = EduPageClient()
            let weeks = try await client.weeks()
            // Keep the last publication visible until a new one is available.
            if let week = WidgetSelection.week(from: weeks, now: now) {
                schedule = try await client.schedule(week: week)
                if let schedule = schedule { try? ScheduleCache.save(schedule) }
                let fresh = await client.substitutions(for: week)
                changes.merge(fresh) { $1 }
                SubstitutionCache.save(fresh)
            } else {
                message = "Jaunais saraksts vēl nav publicēts"
            }
        } catch {
            let cache = ScheduleCache.read()
            schedule = cache
            message = schedule == nil ? "Neizdevās ielādēt. Atver aplikāciju." : "Bezsaistē · saglabātie dati"
        }
        let lunch = schedule.map { WidgetSelection.lunchTimes($0, group: configuration.group, shortenedDates: configuration.shortenedDates) } ?? [:]
        schedule = schedule.map { WidgetSelection.prepare($0, group: configuration.group, shortenedDates: configuration.shortenedDates, changes: changes) }
        var dates = [now]
        let nextDay = WidgetSelection.nextDaySwitch(after: now)
        if let schedule = schedule, let group = schedule.group(matching: configuration.group) {
            let horizon = now.addingTimeInterval(6 * 3600)
            dates += schedule.lessons(for: group.id).flatMap { [$0.start, $0.end].compactMap { $0 } }
                .filter { $0 > now && $0 < horizon }
            if nextDay < horizon { dates.append(nextDay) }
        }
        let entries = Array(Set(dates)).sorted().map {
            ScheduleEntry(date: $0, group: configuration.group, schedule: schedule, message: message, lunch: lunch)
        }
        // Reload at 17:00 too: on Friday the next day is in another week's data.
        // Changes are published during the day, so check every 30 minutes.
        return Timeline(entries: entries, policy: .after(min(now.addingTimeInterval(1800), nextDay)))
    }
}

struct ScheduleWidgetView: View {
    let entry: ScheduleEntry
    @Environment(\.widgetFamily) private var family
    private var group: SchoolGroup? { entry.schedule?.group(matching: entry.group) }
    private var archived: Bool { entry.schedule.map { $0.week.until <= entry.date } ?? false }
    private var all: [SchoolLesson] { (group.flatMap { entry.schedule?.lessons(for: $0.id) } ?? []).filter { !$0.isLunch } }
    private var next: SchoolLesson? {
        guard let schedule = entry.schedule, let group = group else { return nil }
        return WidgetSelection.next(schedule: schedule, groupID: group.id, now: entry.date)
    }
    private var day: Int {
        guard let schedule = entry.schedule, let group = group else { return 0 }
        return WidgetSelection.day(schedule: schedule, groupID: group.id, now: entry.date)
    }
    private var dayRows: [SchoolLesson] { all.filter { $0.day == day } }
    private let orange = Color(red: 0.95, green: 0.5, blue: 0.1)
    /// Changes on the day the widget is about (today, or the next school day after 17:00).
    private var changeCount: Int { dayRows.filter { $0.change != nil }.count }
    private var changeDayLabel: String {
        guard let monday = entry.schedule.map({ SchoolDate.monday($0.week.from) }),
              let date = SchoolDate.calendar.date(byAdding: .day, value: day, to: monday) else { return "" }
        if SchoolDate.calendar.isDate(date, inSameDayAs: entry.date) { return "Šodien" }
        if SchoolDate.calendar.isDateInTomorrow(date) { return "Rīt" }
        return SchoolDate.dayNames[day]
    }
    private var changeBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("\(changeDayLabel) \(changeCount) \(changeCount == 1 ? "izmaiņa" : "izmaiņas")")
        }.font(.system(size: 9, weight: .semibold)).foregroundStyle(orange).lineLimit(1)
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
            if changeCount > 0 {
                changeBadge
            } else {
                Text(publication)
            }
            if entry.message != nil { Image(systemName: "wifi.slash") }
        }.font(.system(size: 9)).foregroundStyle(archived ? Color.orange : Color.secondary).lineLimit(1)
    }
    private var small: some View {
        VStack(alignment: .leading, spacing: 7) {
            header(archived ? "Pārskats" : "Nākamā")
            if let lesson = next {
                Text(lesson.start.map(SchoolDate.time) ?? "—")
                    .font(.system(size: 29, weight: .bold)).tracking(-1)
                    .foregroundStyle(lesson.change != nil ? orange : Color.blue)
                Text(lesson.subject).font(.system(size: 15, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.85)
                HStack(spacing: 4) {
                    Text(String(SchoolDate.dayNames[lesson.day].prefix(2)) + ".")
                    if !lesson.room.isEmpty {
                        Text("· " + lesson.room)
                            .foregroundStyle(lesson.change?.previousRoom != nil ? orange : Color.secondary)
                    }
                    if lesson.change != nil { Text("· mainīta").foregroundStyle(orange) }
                }.font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            } else {
                Text("Nav nākamo stundu").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            publicationView
        }
    }
    private var medium: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(SchoolDate.dayNames[day]).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                if let lunch = entry.lunch[day], !dayRows.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "fork.knife")
                        Text("Pusdienas \(lunch)").monospacedDigit()
                    }.font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
                        .accessibilityLabel("Pusdienas \(lunch)")
                }
                Spacer(minLength: 2)
                Text(group?.short ?? "\(entry.group). grupa")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.blue).lineLimit(1)
            }
            if dayRows.isEmpty {
                Text("Šai dienai nav stundu").font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                let columns = WidgetSelection.columns(dayRows)
                HStack(alignment: .top, spacing: 10) {
                    dayColumn(columns.left, slots: columns.left.count)
                    Rectangle().fill(Color.secondary.opacity(0.15)).frame(width: 1)
                    dayColumn(columns.right, slots: columns.left.count)
                }.frame(maxHeight: .infinity)
            }
            publicationView
        }
    }
    private func dayColumn(_ rows: [SchoolLesson], slots: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { lesson in
                VStack(alignment: .leading, spacing: 0) {
                    Text(SubjectDisplay.name(lesson.subject))
                        .font(.system(size: slots > 4 ? 10 : 12, weight: .semibold))
                        .strikethrough(lesson.change?.cancelled == true)
                        .foregroundStyle(lesson.change == nil ? Color.primary : orange).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 4) {
                        Text(lesson.start.map(SchoolDate.time) ?? "—")
                            .monospacedDigit().foregroundStyle(lesson.change == nil ? Color.blue : orange)
                        Spacer(minLength: 2)
                        if lesson.change?.cancelled == true {
                            Text("nenotiek").foregroundStyle(orange).lineLimit(1)
                        } else if !lesson.room.isEmpty {
                            Text(lesson.room).foregroundStyle(lesson.change?.previousRoom != nil ? orange : Color.secondary).lineLimit(1)
                        }
                    }.font(.system(size: slots > 4 ? 8 : 9, weight: .medium))
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(lesson.time), \(lesson.subject)"
                        + (lesson.change?.cancelled == true ? ", nenotiek" : (lesson.change != nil ? ", mainīta" : ""))
                        + (lesson.room.isEmpty ? "" : ", kabinets \(lesson.room)"))
            }
            ForEach(0..<max(0, slots - rows.count), id: \.self) { _ in
                Color.clear.frame(maxHeight: .infinity)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var large: some View {
        let lessons = all
        let numbers = WidgetSelection.periodNumbers(lessons)
        return VStack(alignment: .leading, spacing: 6) {
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
                ForEach(numbers, id: \.self) { period in
                    HStack(spacing: 3) {
                        Text("\(period)").font(.system(size: 9)).foregroundStyle(.secondary).frame(width: 14)
                        ForEach(0..<5) { day in
                            weekCell(lessons.filter { $0.day == day && $0.period == period })
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
                        .strikethrough(lesson.change?.cancelled == true)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("\(lesson.period). stunda, \(lesson.subject), \(lesson.room)")
                }
            }
        }.padding(.horizontal, 2).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(lessons.isEmpty ? Color.secondary.opacity(0.04)
                        : (lessons.contains { $0.change != nil } ? orange.opacity(0.22) : Color.blue.opacity(0.10)),
                        in: RoundedRectangle(cornerRadius: 5))
    }
    private func compact(_ subject: String) -> String {
        SubjectDisplay.name(subject)
    }
}

@main
struct StunduWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "StunduWidget", intent: GroupIntent.self, provider: ScheduleProvider()) { entry in
            ScheduleWidgetView(entry: entry)
        }
        .configurationDisplayName("Stundu Saraksts")
        .description("Mazais: nākamā stunda. Vidējais: visa diena, no 17:00 nākamā. Lielais: visa nedēļa.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
