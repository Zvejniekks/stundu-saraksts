import SwiftUI
import WidgetKit

@MainActor
final class ScheduleModel: ObservableObject {
    @Published var schedule = ScheduleCache.read()
    @Published var weeks: [PublishedWeek] = []
    @Published var busy = false
    @Published var error: String?
    @Published private(set) var displayed: SchoolSchedule?
    @Published private(set) var currentGroup: SchoolGroup?
    @Published private(set) var days: [Int: [SchoolLesson]] = [:]
    @Published private(set) var periods: [String: [LessonPeriod]] = [:]

    // Rebuild on data/group/settings changes only, never when a day button is tapped.
    func prepare(group: String, shortenedDates: Set<String>) {
        guard let source = schedule else {
            displayed = nil; currentGroup = nil; days = [:]; periods = [:]; return
        }
        let selected = source.group(matching: group)
        let own = selected.map { source.lessons(for: $0.id) } ?? []
        let filtered = SchoolSchedule(week: source.week, groups: source.groups, lessons: own, fetchedAt: source.fetchedAt)
            .applyingShortenedDates(shortenedDates)
        var slots: [String: [LessonPeriod]] = [:]
        for lesson in filtered.lessons {
            let date = SchoolDate.calendar.date(byAdding: .day, value: lesson.day, to: SchoolDate.monday(source.week.from))!
            slots[lesson.id] = lesson.periodTimes(on: date, shortened: shortenedDates.contains(BellTimes.dateKey(date)))
        }
        currentGroup = selected
        displayed = filtered
        days = Dictionary(grouping: filtered.lessons, by: \.day)
        periods = slots
    }
    func refresh(week: PublishedWeek? = nil) async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            let client = EduPageClient()
            let available = try await client.weeks()
            weeks = available
            guard let selected = week ?? available.first(where: { $0.contains(Date()) }) ?? available.first else { return }
            let loaded = try await client.schedule(week: selected)
            schedule = loaded
            do { try ScheduleCache.save(loaded) }
            catch { self.error = "Dati ielādēti, bet tos neizdevās saglabāt bezsaistē." }
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            self.error = "Neizdevās atjaunot sarakstu. \(error.localizedDescription)"
        }
    }
}

struct ContentView: View {
    @StateObject private var model = ScheduleModel()
    @AppStorage("selectedGroup") private var group = "31"
    @AppStorage("shortenedDates") private var shortenedDates = ""
    @State private var day = min(SchoolDate.day(Date()), 4)
    @State private var showGroups = false
    @State private var showSettings = false
    @State private var search = ""
    private let blue = Color(red: 0, green: 0.44, blue: 0.9)
    private var surface: Color { Color(.secondarySystemGroupedBackground) }
    private var selected: SchoolGroup? { model.currentGroup }
    private var shortenedSet: Set<String> { Set(shortenedDates.split(separator: ",").map(String.init)) }
    private var schedule: SchoolSchedule? { model.displayed }
    private var selectedDate: Date {
        let monday = SchoolDate.monday(model.schedule?.week.from ?? Date())
        return SchoolDate.calendar.date(byAdding: .day, value: day, to: monday)!
    }
    private var isShortened: Bool { shortenedSet.contains(BellTimes.dateKey(selectedDate)) }
    private var lessons: [SchoolLesson] { model.days[day] ?? [] }
    private var fullDate: String {
        SchoolDate.full(selectedDate)
    }
    private var dayTitle: String { SchoolDate.dayNames[day] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hero
                    if let error = model.error {
                        Label(error, systemImage: "wifi.exclamationmark")
                            .font(.footnote).foregroundStyle(.orange).padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(surface, in: RoundedRectangle(cornerRadius: 20))
                    }
                    if let schedule = schedule {
                        weekPicker(schedule)
                        dayPicker
                        if selected == nil {
                            ContentUnavailableView("Izvēlies grupu", systemImage: "person.2", description: Text("Šajā nedēļā saglabātā grupa nav atrasta."))
                        } else if lessons.isEmpty {
                            ContentUnavailableView("Brīva diena.", systemImage: "sun.max", description: Text("Šajā sarakstā šai dienai nav stundu."))
                        } else {
                            daySummary
                            TimelineView(.periodic(from: .now, by: 60)) { context in
                                LazyVStack(spacing: 12) {
                                    ForEach(lessons) { lesson in lessonCard(lesson, now: context.date) }
                                }
                            }
                        }
                        footer(schedule)
                    } else {
                        if model.busy {
                            ProgressView("Ielādē sarakstu…").frame(maxWidth: .infinity).padding(.vertical, 48)
                        } else {
                            ContentUnavailableView("Saraksts vēl nav ielādēts", systemImage: "calendar", description: Text("Pārbaudi internetu un atjauno sarakstu."))
                        }
                    }
                }.padding(.horizontal, 22).padding(.top, 28).padding(.bottom, 36)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Stundas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showGroups = true } label: {
                        HStack(spacing: 5) {
                            Text(selected?.short ?? "\(group). grupa").font(.subheadline.weight(.semibold))
                            Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                        }
                    }.disabled(model.schedule == nil).accessibilityLabel("Mainīt grupu")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { Task { await model.refresh() } } label: {
                        if model.busy { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                    }.disabled(model.busy).accessibilityLabel("Atjaunot sarakstu")
                    Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("Dienas iestatījumi")
                }
            }
            .refreshable { await model.refresh() }
            .task { await model.refresh() }
            .onChange(of: model.schedule?.fetchedAt, initial: true) { _, _ in prepareDays() }
            .onChange(of: group) { _, _ in prepareDays() }
            .onChange(of: shortenedDates) { _, _ in prepareDays() }
            .sheet(isPresented: $showGroups) { groupPicker }
            .sheet(isPresented: $showSettings) { settings }
        }.tint(blue)
    }

    private func prepareDays() { model.prepare(group: group, shortenedDates: shortenedSet) }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VALMIERAS TEHNIKUMS")
                .font(.system(size: 10, weight: .semibold)).tracking(2.2).foregroundStyle(.secondary)
            Text(dayTitle + ".")
                .font(.system(size: 43, weight: .bold, design: .default)).tracking(-1.8)
                .lineLimit(1).minimumScaleFactor(0.65)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                Text(fullDate).foregroundStyle(.secondary)
                if SchoolDate.calendar.isDate(selectedDate, inSameDayAs: Date()) {
                    Text("Šodien").foregroundStyle(blue)
                }
            }.font(.title3)
        }.padding(.top, 4)
    }

    private func weekPicker(_ schedule: SchoolSchedule) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tava nedēļa").font(.subheadline.weight(.semibold))
                Spacer()
                Menu {
                    ForEach(model.weeks) { week in
                        Button(week.title) { Task { await model.refresh(week: week) } }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("\(SchoolDate.short(schedule.week.from))–\(SchoolDate.short(schedule.week.until.addingTimeInterval(-1)))")
                        Image(systemName: "chevron.down").font(.caption2)
                    }.font(.subheadline)
                }.disabled(model.busy || model.weeks.isEmpty)
            }
            if !schedule.week.contains(Date()) {
                Text("Apskati publicēto nedēļu. Šis nav šodienas saraksts.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var dayPicker: some View {
        HStack(spacing: 6) {
            ForEach(0..<5) { index in
                let date = SchoolDate.calendar.date(byAdding: .day, value: index, to: SchoolDate.monday(selectedDate))!
                Button { withAnimation(.easeInOut(duration: 0.18)) { day = index } } label: {
                    VStack(spacing: 10) {
                        Text(["Pr", "Ot", "Tr", "Ce", "Pk"][index]).font(.caption.weight(.medium))
                        Text("\(SchoolDate.calendar.component(.day, from: date))").font(.title3.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(day == index ? Color.primary : surface, in: RoundedRectangle(cornerRadius: 22))
                    .foregroundStyle(day == index ? Color(.systemBackground) : Color.primary)
                }.buttonStyle(.plain).accessibilityLabel("\(SchoolDate.dayNames[index]), \(SchoolDate.short(date))")
                    .accessibilityAddTraits(day == index ? .isSelected : [])
            }
        }
    }

    private var daySummary: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dienas plāns").font(.title2.bold()).tracking(-0.6)
                Text(isShortened ? "Pirmssvētku dienas laiki" : (day == 4 ? "Piektdienas laiki" : (day == 0 ? "Pirmdienas laiki" : "Parastie stundu laiki")))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let end = lessons.compactMap(\.end).max() {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(SchoolDate.time(end)).font(.title3.weight(.semibold)).monospacedDigit()
                    Text("dienas beigas").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func lessonCard(_ lesson: SchoolLesson, now: Date) -> some View {
        let slots = model.periods[lesson.id] ?? []
        let active = slots.isEmpty
            ? (lesson.start.map { $0 <= now } == true && lesson.end.map { $0 > now } == true)
            : slots.contains { $0.contains(now) }
        let inBreak = !active && lesson.start.map { $0 <= now } == true && lesson.end.map { $0 > now } == true
        let periodText = lesson.durationPeriods > 1 ? "\(lesson.period)–\(lesson.period + lesson.durationPeriods - 1)" : "\(lesson.period)"
        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(lesson.start.map(SchoolDate.time) ?? "—")
                    .font(.system(size: 18, weight: .semibold)).monospacedDigit()
                Text(lesson.end.map(SchoolDate.time) ?? "—")
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                if active { Circle().fill(blue).frame(width: 6, height: 6).padding(.top, 8) }
            }.frame(width: 56, alignment: .leading)
            VStack(alignment: .leading, spacing: 9) {
                Text(active ? "TAGAD · \(periodText). STUNDA" : (inBreak ? "STARPBRĪDIS" : "\(periodText). STUNDA"))
                    .font(.system(size: 9, weight: .semibold)).tracking(1.2)
                    .foregroundStyle(active ? blue : Color.secondary)
                Text(lesson.subject).font(.system(size: 18, weight: .semibold)).tracking(-0.3)
                    .fixedSize(horizontal: false, vertical: true)
                if slots.count > 1 {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                            HStack {
                                Text("\(slot.number). stunda")
                                Spacer(minLength: 6)
                                Text(slot.time).monospacedDigit()
                            }.font(.caption).foregroundStyle(slot.contains(now) ? blue : Color.secondary)
                            if index + 1 < slots.count, let end = slot.end, let next = slots[index + 1].start, next > end {
                                Text("Starpbrīdis · \(Int(next.timeIntervalSince(end) / 60)) min")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }.padding(.vertical, 4)
                }
                if !lesson.teacher.isEmpty { Text(lesson.teacher).font(.caption).foregroundStyle(.secondary) }
                HStack(spacing: 8) {
                    if !lesson.room.isEmpty {
                        Label(lesson.room, systemImage: "door.left.hand.open")
                            .font(.caption.weight(.medium)).foregroundStyle(blue)
                    }
                    if !lesson.subgroup.isEmpty {
                        Text(lesson.subgroup).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if lesson.start == nil || lesson.end == nil {
                    Text("Precizē laiku skolas sarakstā.").font(.caption).foregroundStyle(.orange)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(surface, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(active ? blue.opacity(0.5) : Color.clear, lineWidth: 1))
    }

    private func footer(_ schedule: SchoolSchedule) -> some View {
        VStack(spacing: 8) {
            Text("Atjaunots \(SchoolDate.short(schedule.fetchedAt)) plkst. \(SchoolDate.time(schedule.fetchedAt))")
                .font(.caption2).foregroundStyle(.secondary)
            Link("Skatīt EduPage ↗", destination: URL(string: "https://valteh.edupage.org/timetable/view.php")!)
                .font(.caption)
        }.frame(maxWidth: .infinity).padding(.top, 8)
    }

    private var groupPicker: some View {
        NavigationStack {
            List {
                ForEach((model.schedule?.groups ?? []).filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { item in
                    Button { group = item.short; showGroups = false } label: {
                        HStack {
                            Text(item.name).foregroundStyle(.primary)
                            Spacer()
                            if selected?.id == item.id { Image(systemName: "checkmark.circle.fill") }
                        }.padding(.vertical, 6)
                    }
                }
            }
            .searchable(text: $search, prompt: "Grupas numurs")
            .navigationTitle("Tava grupa")
            .toolbar { Button("Gatavs") { showGroups = false } }
        }.tint(blue)
    }

    private var settings: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Pirmssvētku diena", isOn: Binding(get: { isShortened }, set: { enabled in
                        var dates = shortenedSet
                        let key = BellTimes.dateKey(selectedDate)
                        if enabled { dates.insert(key) } else { dates.remove(key) }
                        shortenedDates = dates.sorted().joined(separator: ",")
                    }))
                } header: { Text("\(dayTitle), \(fullDate)") } footer: {
                    Text("Saīsinātie laiki attiecas tikai uz izvēlēto datumu. Ieslēdz, ja skola šai dienai ir noteikusi pirmssvētku sarakstu.")
                }
                Section("Sākuma ekrāna logrīks") {
                    Text("Turi nospiestu sākuma ekrānu un pievieno “Stundu Saraksts”. Grupu izvēlies logrīka iestatījumos.")
                    Text("Ja izmanto pirmssvētku laikus, arī logrīka iestatījumos norādi datumu formātā GGGG-MM-DD. Aplikācijas izvēle uz logrīku automātiski nepāriet.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Stundu laiki") {
                    Text("Pirmdienām, otrdienām–ceturtdienām un piektdienām ir atsevišķi laiki pēc skolas tabulas. Visi laiki ir pēc Latvijas laika.")
                    Link("Skolas laiku tabula ↗", destination: URL(string: "https://valmierastehnikums.lv/wp-content/uploads/2024/10/MACIBU_STUNDU_LAIKI.pdf-2.pdf")!)
                }
            }
            .navigationTitle("Iestatījumi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Gatavs") { showSettings = false } }
        }.tint(blue)
    }
}
