import SwiftUI
import WidgetKit

@MainActor
final class ScheduleModel: ObservableObject {
    @Published var schedule = ScheduleCache.read()
    @Published var weeks: [PublishedWeek] = []
    @Published var busy = false
    @Published var error: String?
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
    @State private var day = min(SchoolDate.day(Date()), 4)
    @State private var showGroups = false
    @State private var search = ""
    private var selected: SchoolGroup? { model.schedule?.group(matching: group) }
    private let accent = Color(red: 0.44, green: 0.39, blue: 0.94)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if let error = model.error {
                        Label(error, systemImage: "wifi.exclamationmark")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                    if let schedule = model.schedule {
                        weekMenu(schedule)
                        dayPicker
                        let lessons = selected.map { schedule.lessons(for: $0.id, day: day) } ?? []
                        if selected == nil {
                            ContentUnavailableView("Izvēlies grupu", systemImage: "person.2", description: Text("Saglabātā grupa šajā sarakstā nav atrasta."))
                        } else if lessons.isEmpty {
                            ContentUnavailableView("Nav stundu", systemImage: "sun.max", description: Text("Šai dienai izvēlētajā sarakstā nav stundu."))
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(lessons) { lesson in lessonCard(lesson) }
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ielādēts \(SchoolDate.short(schedule.fetchedAt)) \(SchoolDate.time(schedule.fetchedAt))")
                            Text("Visi laiki pēc Latvijas laika. Apakšgrupas ir norādītas pie stundām.")
                            Text("Logrīks: turi nospiestu sākuma ekrānu → pievieno “Stundu Saraksts”. Grupu vari mainīt logrīka iestatījumos.")
                            Link("Atvērt skolas sarakstu", destination: URL(string: "https://valteh.edupage.org/timetable/view.php")!)
                        }.font(.caption).foregroundStyle(.secondary)
                    } else if model.busy {
                        ProgressView("Ielādē stundu sarakstu…").frame(maxWidth: .infinity).padding(40)
                    } else {
                        ContentUnavailableView("Saraksts vēl nav ielādēts", systemImage: "calendar", description: Text("Pārbaudi internetu un nospied atjaunošanas pogu."))
                    }
                }.padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Mans saraksts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await model.refresh() } } label: {
                        if model.busy { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                    }.disabled(model.busy).accessibilityLabel("Atjaunot sarakstu")
                }
            }
            .refreshable { await model.refresh() }
            .task { await model.refresh() }
            .sheet(isPresented: $showGroups) { groupPicker }
        }.tint(accent)
    }
    private var header: some View {
        Button { showGroups = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 7) {
                    Text("VALMIERAS TEHNIKUMS").font(.caption2.weight(.bold)).tracking(2)
                    Text(selected?.short ?? "\(group). grupa").font(.largeTitle.bold())
                    Text("Saglabāta grupa · pieskaries, lai mainītu").font(.caption)
                }
                Spacer()
                Image(systemName: "pin.fill").font(.title2)
            }.foregroundStyle(.white).padding(22)
                .background(LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
        }.buttonStyle(.plain)
    }
    private func weekMenu(_ schedule: SchoolSchedule) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                ForEach(model.weeks) { week in
                    Button(week.title) { Task { await model.refresh(week: week) } }
                }
            } label: {
                HStack {
                    Image(systemName: "calendar")
                    Text("\(SchoolDate.short(schedule.week.from))–\(SchoolDate.short(schedule.week.until.addingTimeInterval(-1)))").bold()
                    Spacer()
                    Image(systemName: "chevron.down")
                }
            }.disabled(model.busy || model.weeks.isEmpty)
            if !schedule.week.contains(Date()) {
                Text("Skaties citu nedēļu. Tās stundas nav šodienas saraksts.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var dayPicker: some View {
        HStack(spacing: 8) {
            ForEach(0..<5) { index in
                Button { day = index } label: {
                    Text(["Pr", "Ot", "Tr", "Ce", "Pk"][index])
                        .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(day == index ? accent : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(day == index ? Color.white : Color.primary)
                }.accessibilityLabel(SchoolDate.dayNames[index])
            }
        }
    }
    private func lessonCard(_ lesson: SchoolLesson) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(lesson.period)").font(.title3.bold()).foregroundStyle(accent)
                .frame(width: 34, height: 36).background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 7) {
                Text(lesson.subject).font(.headline)
                Text(lesson.time).font(.subheadline.monospacedDigit()).foregroundStyle(accent)
                if !lesson.teacher.isEmpty { Text(lesson.teacher).font(.subheadline).foregroundStyle(.secondary) }
                if !lesson.room.isEmpty { Label(lesson.room, systemImage: "door.left.hand.open").font(.caption) }
                if !lesson.subgroup.isEmpty { Text("Apakšgrupa: \(lesson.subgroup)").font(.caption).foregroundStyle(.secondary) }
                if lesson.start == nil || lesson.end == nil {
                    Text("Laiks avotā nav precīzs — pārbaudi EduPage.").font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 0)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
    private var groupPicker: some View {
        NavigationStack {
            List {
                ForEach((model.schedule?.groups ?? []).filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { item in
                    Button {
                        group = item.short; showGroups = false
                    } label: {
                        HStack {
                            Text(item.name).foregroundStyle(.primary)
                            Spacer()
                            if selected?.id == item.id { Image(systemName: "checkmark.circle.fill") }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Grupas numurs")
            .navigationTitle("Izvēlies grupu")
            .toolbar { Button("Gatavs") { showGroups = false } }
        }
    }
}
