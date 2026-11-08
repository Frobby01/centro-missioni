import SwiftUI
import WidgetKit

struct Entry: TimelineEntry {
    let date: Date
    let summary: Summary
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, summary: Summary(tasks: []))
    }

    func load() async -> Entry {
        Entry(date: .now, summary: await Remote.load(token: Shared.read("token") ?? "", filter: Shared.read("filter")))
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        if context.isPreview { return completion(placeholder(in: context)) }
        Task { completion(await load()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task { completion(Timeline(entries: [await load()], policy: .after(.now.addingTimeInterval(15 * 60)))) }
    }
}

let projectColors: [String: Color] = [
    // stessi --c-* e --accent di index.html
    "aisa": Color(red: 0.42, green: 0.61, blue: 0.94), "afk": Color(red: 0.85, green: 0.64, blue: 0.25),
    "frobby": Color(red: 0.88, green: 0.48, blue: 0.62), "giochi": Color(red: 0.37, green: 0.75, blue: 0.56),
    "cinic": Color(red: 0.31, green: 0.72, blue: 0.80), "vgi": Color(red: 0.88, green: 0.39, blue: 0.39),
    "personale": Color(red: 0.64, green: 0.55, blue: 0.88),
]
let accent = Color(red: 0.29, green: 0.44, blue: 0.82)

struct WidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: Entry

    var rows: Int { family == .systemLarge ? 5 : 2 }
    var today: String { Summary.ymd(entry.date) }
    // Tessere: le task che vengono dopo l'elenco (oggi/in ritardo, poi future), solo nel grande.
    var tiles: [Mission] {
        guard family == .systemLarge else { return [] }
        let s = entry.summary
        return Array((s.focus.dropFirst(rows) + s.upcoming).prefix(3))
    }

    var body: some View {
        let s = entry.summary
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Lv \(s.level)").font(.headline.monospacedDigit()).foregroundStyle(accent)
                if family != .systemSmall { Text(s.rank).font(.subheadline).foregroundStyle(.secondary) }
                Spacer()
                Label("\(s.best)", systemImage: "flame").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary).help("Streak record (giorni)")
            }
            ProgressView(value: Double(s.xp - s.cur), total: Double(max(s.next - s.cur, 1))).tint(accent)
            Text("Missione \(min(s.doneToday, Summary.questN))/\(Summary.questN) · \(s.xp) XP")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            if family != .systemSmall { chips(s.filter) }

            if let err = s.error {
                Spacer()
                Text(err).font(.caption).foregroundStyle(.red)
            } else if s.focus.isEmpty {
                Spacer()
                Text("Tutto fatto per oggi").font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(s.focus.prefix(rows), id: \.id) { t in
                    HStack(spacing: 6) {
                        Circle().fill(projectColors[t.project ?? ""] ?? .gray).frame(width: 8, height: 8)
                        Text(t.title ?? "").font(.callout).lineLimit(1)
                        Spacer(minLength: 0)
                        if let d = t.date, d < today, t.soft != true { Text("ritardo").font(.caption2).foregroundStyle(.red) }
                        else if let tm = t.time, family != .systemSmall { Text(tm).font(.caption2.monospacedDigit()).foregroundStyle(.secondary) }
                    }
                }
                let rest = s.focus.count - min(rows, s.focus.count) - tiles.filter { ($0.date ?? "") <= today }.count
                if rest > 0 { Text("+\(rest) altre").font(.caption2).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
            if s.error == nil, !tiles.isEmpty {
                Text("Prossime").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) { ForEach(tiles, id: \.id, content: card) }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "https://frobby01.github.io/centro-missioni/"))
    }
}

extension WidgetView {
    func chips(_ active: String?) -> some View {
        HStack(spacing: 4) {
            ForEach(Summary.projects, id: \.id) { p in
                let c = projectColors[p.id] ?? .gray
                Link(destination: URL(string: "centromissioni://filter/\(p.id)")!) {
                    Text(p.emoji)
                        .font(.callout)
                        .frame(maxWidth: .infinity, minHeight: 22)
                        .background(active == p.id ? AnyShapeStyle(c.opacity(0.3)) : AnyShapeStyle(.fill.quaternary), in: RoundedRectangle(cornerRadius: 6))
                }
                .help(p.name)
                .accessibilityLabel("Filtra \(p.name)")
            }
        }
    }

    // Tessera quadrata come le card "Per te oggi" del sito.
    func card(_ t: Mission) -> some View {
        let c = projectColors[t.project ?? ""] ?? .gray
        return VStack(alignment: .leading, spacing: 4) {
            Circle().fill(c).frame(width: 8, height: 8).padding(.top, 2)
            Text(t.title ?? "").font(.caption).lineLimit(3)
            Spacer(minLength: 0)
            if let d = t.date, d < today, t.soft != true { Text("ritardo").font(.caption2).foregroundStyle(.red) }
            else { Text(t.date.flatMap { $0 > today ? Summary.date($0) : nil }.map { $0.formatted(.dateTime.weekday(.abbreviated).day().locale(Locale(identifier: "it_IT"))) } ?? "oggi")
                .font(.caption2).foregroundStyle(.secondary) }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 84, maxHeight: 84, alignment: .topLeading)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

@main
struct CentroMissioniWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CentroMissioni", provider: Provider()) { entry in
            WidgetView(entry: entry)
        }
        .configurationDisplayName("Centro Missioni")
        .description("Livello, streak e missioni di oggi.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
