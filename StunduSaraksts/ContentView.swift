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
    @Published private(set) var changes: [String: SubstitutionDay] = [:]
    @Published private(set) var changesFailed = false
    var pickedWeekID: String?

    /// Changes are published per day; load the visible week's school days from today on.
    func loadChanges(for week: PublishedWeek) async {
        let c = SchoolDate.calendar, today = c.startOfDay(for: Date())
        let dates = (0..<5).compactMap { c.date(byAdding: .day, value: $0, to: SchoolDate.monday(week.from)) }
            .filter { $0 >= today }
        guard !dates.isEmpty else { return }
        let client = EduPageClient()
        var failed = false
        for date in dates {
            if let day = try? await client.substitutions(on: date) { changes[day.date] = day } else { failed = true }
        }
        changesFailed = failed
    }

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
        var cards: [SchoolLesson] = []
        for lesson in filtered.lessons {
            let date = SchoolDate.calendar.date(byAdding: .day, value: lesson.day, to: SchoolDate.monday(source.week.from))!
            let shortened = shortenedDates.contains(BellTimes.dateKey(date))
            let parts = lesson.splitPeriods(on: date, shortened: shortened)
            for part in parts {
                cards.append(part)
                slots[part.id] = part.periodTimes(on: date, shortened: shortened)

            }
        }
        currentGroup = selected
        displayed = filtered
        days = Dictionary(grouping: cards.sorted { ($0.day, $0.period, $0.id) < ($1.day, $1.period, $1.id) }, by: \.day)
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
            let current = WidgetSelection.week(from: available, on: WidgetSelection.schoolDay(Date()))
            guard let selected = week ?? available.first(where: { $0.id == pickedWeekID }) ?? current else { return }
            let loaded = try await client.schedule(week: selected)
            schedule = loaded
            if week != nil { pickedWeekID = selected.id }
            // Offline data stays the current week, even after browsing another one.
            if selected.id == current?.id {
                do { try ScheduleCache.save(loaded) }
                catch { self.error = "Dati ielādēti, bet tos neizdevās saglabāt bezsaistē." }
            }
            WidgetCenter.shared.reloadAllTimelines()
            await loadChanges(for: selected)
            await ChangeNotifier.check()
            ChangeNotifier.scheduleBackgroundRefresh()
        } catch {
            self.error = "Neizdevās atjaunot sarakstu. \(error.localizedDescription)"
        }
    }
}

struct ContentView: View {
    @StateObject private var model = ScheduleModel()
    @AppStorage("selectedGroup") private var group = "31"
    @AppStorage("shortenedDates") private var shortenedDates = ""
    @AppStorage(ChangeNotifier.enabledKey) private var notifyChanges = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var day = SchoolDate.day(WidgetSelection.schoolDay(Date()))
    @State private var openedOn = SchoolDate.dateKey(Date())
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
    private let orange = Color(red: 0.95, green: 0.5, blue: 0.1)
    private func date(ofDay index: Int) -> Date {
        SchoolDate.calendar.date(byAdding: .day, value: index, to: SchoolDate.monday(selectedDate))!
    }
    private func changes(ofDay index: Int) -> [SubstitutionEntry] {
        model.changes[SchoolDate.dateKey(date(ofDay: index))]?.entries(for: selected) ?? []
    }
    private var dayChanges: [SubstitutionEntry] { changes(ofDay: day) }
    private func change(for lesson: SchoolLesson) -> SubstitutionEntry? {
        dayChanges.first { $0.covers(lesson) && $0.firstPeriod != nil }
    }
    private func move(by offset: Int) {
        let target = day + offset
        guard (0..<5).contains(target) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { day = target }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let error = model.error {
                        Label(error, systemImage: "wifi.exclamationmark")
                            .font(.footnote).foregroundStyle(.orange).padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(surface, in: RoundedRectangle(cornerRadius: 20))
                    }
                    if let schedule = schedule {
                        weekPicker(schedule)
                        dayPicker
                        if !dayChanges.isEmpty { changesCard }
                        if selected == nil {
                            ContentUnavailableView("Izvēlies grupu", systemImage: "person.2", description: Text("Šajā nedēļā saglabātā grupa nav atrasta."))
                        } else if lessons.isEmpty {
                            ContentUnavailableView("Brīva diena.", systemImage: "sun.max", description: Text("Šajā sarakstā šai dienai nav stundu."))
                        } else {
                            daySummary
                            TimelineView(.periodic(from: .now, by: 30)) { context in
                                LazyVStack(spacing: 8) {
                                    nowBanner(now: context.date)
                                    ForEach(lessons) { lesson in
                                        lessonCard(lesson, now: context.date)
                                    }
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
                }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 20)
                    .contentShape(Rectangle())
                    .simultaneousGesture(DragGesture(minimumDistance: 40).onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                        move(by: value.translation.width < 0 ? 1 : -1)
                    })
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
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                let today = SchoolDate.dateKey(Date())
                if today != openedOn {
                    openedOn = today
                    model.pickedWeekID = nil
                    day = SchoolDate.day(WidgetSelection.schoolDay(Date()))
                }
                Task { await model.refresh() }
            }
            .onChange(of: model.schedule?.fetchedAt, initial: true) { _, _ in prepareDays() }
            .onChange(of: group) { _, _ in prepareDays() }
            .onChange(of: shortenedDates) { _, _ in prepareDays() }
            .sheet(isPresented: $showGroups) { groupPicker }
            .sheet(isPresented: $showSettings) { settings }
        }.tint(blue)
    }

    private func prepareDays() { model.prepare(group: group, shortenedDates: shortenedSet) }

    private func weekPicker(_ schedule: SchoolSchedule) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(fullDate).font(.subheadline.weight(.semibold))
                if SchoolDate.calendar.isDate(selectedDate, inSameDayAs: Date()) {
                    Text("Šodien").font(.caption2).foregroundStyle(blue)
                }
            }
            Spacer(minLength: 4)
            Menu {
                ForEach(model.weeks) { week in
                    Button(week.title) { Task { await model.refresh(week: week) } }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("\(SchoolDate.short(schedule.week.from))–\(SchoolDate.short(schedule.week.until.addingTimeInterval(-1)))")
                    Image(systemName: "chevron.down").font(.caption2)
                }.font(.caption.weight(.medium)).padding(.vertical, 10)
            }.disabled(model.busy || model.weeks.isEmpty)
                .accessibilityLabel("Izvēlēties nedēļu")
        }
    }

    private var dayPicker: some View {
        HStack(spacing: 6) {
            ForEach(0..<5) { index in
                let date = SchoolDate.calendar.date(byAdding: .day, value: index, to: SchoolDate.monday(selectedDate))!
                Button { withAnimation(.easeInOut(duration: 0.18)) { day = index } } label: {
                    VStack(spacing: 5) {
                        Text(["Pr", "Ot", "Tr", "Ce", "Pk"][index]).font(.caption.weight(.medium))
                        Text("\(SchoolDate.calendar.component(.day, from: date))").font(.title3.weight(.semibold))
                        Circle().fill(changes(ofDay: index).isEmpty ? Color.clear : orange).frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 10).padding(.bottom, 6)
                    .background(day == index ? Color.primary : surface, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(day == index ? Color(.systemBackground) : Color.primary)
                }.buttonStyle(.plain).accessibilityLabel("\(SchoolDate.dayNames[index]), \(SchoolDate.short(date))\(changes(ofDay: index).isEmpty ? "" : ", ir izmaiņas")")
                    .accessibilityAddTraits(day == index ? .isSelected : [])
            }
        }
    }

    private var daySummary: some View {
        HStack {
            Text(dayTitle).font(.headline)
            if isShortened { Text("Saīsinātā diena").font(.caption2).foregroundStyle(blue) }
            Spacer()
            if let end = lessons.compactMap(\.end).max() {
                Text("Līdz \(SchoolDate.time(end))").font(.caption).monospacedDigit().foregroundStyle(.secondary)
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
        let changed = change(for: lesson)
        let accent = changed != nil ? orange : SubjectColor.color(for: lesson.subject)
        return HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(lesson.start.map(SchoolDate.time) ?? "—")
                    .font(.system(size: 18, weight: .semibold)).monospacedDigit()
                Text(lesson.end.map(SchoolDate.time) ?? "—")
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                if active { Circle().fill(blue).frame(width: 6, height: 6).padding(.top, 8) }
            }.frame(width: 56, alignment: .leading)
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 6) {
                    Text(active ? "TAGAD · \(periodText). STUNDA" : (inBreak ? "STARPBRĪDIS" : "\(periodText). STUNDA"))
                        .font(.system(size: 9, weight: .semibold)).tracking(1.2)
                        .foregroundStyle(active ? blue : Color.secondary)
                    if let changed = changed {
                        Text(changed.isCancelled ? "NENOTIEK" : "IZMAIŅA")
                            .font(.system(size: 9, weight: .bold)).tracking(1)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(orange.opacity(0.16), in: Capsule()).foregroundStyle(orange)
                    }
                }
                Text(lesson.subject).font(.system(size: 18, weight: .semibold)).tracking(-0.3)
                    .strikethrough(changed?.isCancelled == true)
                    .foregroundStyle(changed?.isCancelled == true ? Color.secondary : Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
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
                if let changed = changed {
                    Text(changed.text).font(.caption).foregroundStyle(orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if lesson.start == nil || lesson.end == nil {
                    Text("Precizē laiku skolas sarakstā.").font(.caption).foregroundStyle(.orange)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14).padding(.leading, 20).padding(.trailing, 16)
        .background(surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 4).padding(.vertical, 14).padding(.leading, 8)
        }
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(active ? blue.opacity(0.5) : Color.clear, lineWidth: 1))
        .opacity(lesson.end.map { $0 < now } == true && SchoolDate.calendar.isDateInToday(selectedDate) ? 0.55 : 1)
    }

    private var changesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Stundu izmaiņas · \(dayChanges.count)", systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.semibold)).foregroundStyle(orange)
            ForEach(dayChanges) { entry in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(entry.periodText).font(.caption.weight(.bold)).monospacedDigit()
                        .frame(width: 44, alignment: .leading)
                    Text(entry.text).font(.caption).fixedSize(horizontal: false, vertical: true)

                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(orange.opacity(0.35), lineWidth: 1))
    }

    /// "Now" or "next" summary for today, with progress through the current lesson.
    @ViewBuilder private func nowBanner(now: Date) -> some View {
        if SchoolDate.calendar.isDate(selectedDate, inSameDayAs: now) {
            let timed = lessons.filter { $0.start != nil && $0.end != nil && !$0.isLunch }
            if let current = timed.first(where: { $0.start! <= now && now < $0.end! }) {
                let total = current.end!.timeIntervalSince(current.start!)
                let left = Int(ceil(current.end!.timeIntervalSince(now) / 60))
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Tagad").font(.caption.weight(.semibold)).foregroundStyle(blue)
                        Spacer()
                        Text("vēl \(left) min").font(.caption.weight(.medium)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    Text(current.subject).font(.headline).lineLimit(1)
                    ProgressView(value: min(1, max(0, now.timeIntervalSince(current.start!) / total))).tint(blue)
                }
                .padding(14).background(blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
            } else if let next = timed.first(where: { $0.start! > now }) {
                let mins = Int(ceil(next.start!.timeIntervalSince(now) / 60))
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Nākamā").font(.caption.weight(.semibold)).foregroundStyle(blue)
                        Text(next.subject).font(.headline).lineLimit(1)
                    }
                    Spacer()
                    Text(mins < 60 ? "pēc \(mins) min" : "plkst. \(SchoolDate.time(next.start!))")
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                }
                .padding(14).background(blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
            } else if let end = timed.compactMap(\.end).max(), end <= now {
                Label("Šodienas stundas beigušās", systemImage: "checkmark.circle")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                    .background(surface, in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private func footer(_ schedule: SchoolSchedule) -> some View {
        VStack(spacing: 8) {
            Text("Atjaunots \(SchoolDate.short(schedule.fetchedAt)) plkst. \(SchoolDate.time(schedule.fetchedAt))")
                .font(.caption2).foregroundStyle(.secondary)
            if model.changesFailed {
                Text("Stundu izmaiņas neizdevās ielādēt.").font(.caption2).foregroundStyle(orange)
            }
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
                Section {
                    Toggle("Paziņot par stundu izmaiņām", isOn: Binding(get: { notifyChanges }, set: { on in
                        if !on { notifyChanges = false; return }
                        Task {
                            let allowed = await ChangeNotifier.requestPermission()
                            notifyChanges = allowed
                            if allowed {
                                ChangeNotifier.scheduleBackgroundRefresh()
                                await ChangeNotifier.check()
                            }
                        }
                    }))
                } header: { Text("Paziņojumi") } footer: {
                    Text("Paziņo par jaunām izmaiņām tavai grupai šodien un nākamajā mācību dienā. iOS pats izvēlas, cik bieži pārbaudīt fonā; aplikāciju atverot, pārbaude notiek uzreiz. Ja paziņojumi nenāk, Iestatījumos ieslēdz “Fona atjaunināšana”.")
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
