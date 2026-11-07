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
    "aisa": Color(red: 0.36, green: 0.62, blue: 1.00), "afk": Color(red: 0.96, green: 0.65, blue: 0.14),
    "frobby": Color(red: 1.00, green: 0.37, blue: 0.60), "giochi": Color(red: 0.24, green: 0.81, blue: 0.56),
    "cinic": Color(red: 0.18, green: 0.77, blue: 0.88), "vgi": Color(red: 1.00, green: 0.32, blue: 0.32),
    "personale": Color(red: 0.69, green: 0.55, blue: 1.00),
]
let accent = Color(red: 1.00, green: 0.48, blue: 0.18)

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
                Text("🔥\(s.best)").font(.subheadline.monospacedDigit()).help("Streak record (giorni)")
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
                VStack(spacing: 4) {
                    Text("🎉").font(.system(size: family == .systemSmall ? 28 : 40))
                    Text("Tutto fatto per oggi").font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            } else {
                ForEach(s.focus.prefix(rows), id: \.id) { t in
                    HStack(spacing: 6) {
                        Circle().fill(projectColors[t.project ?? ""] ?? .gray).frame(width: 7, height: 7)
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
                Text("Prossime").font(.caption.bold()).foregroundStyle(.secondary)
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
                        .background(c.opacity(active == p.id ? 0.55 : 0.15), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(c, lineWidth: active == p.id ? 1.5 : 0))
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
            Text(Summary.emoji(t.project)).font(.callout)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(c.opacity(0.2), in: RoundedRectangle(cornerRadius: 5))
            Text(t.title ?? "").font(.caption).lineLimit(3)
            Spacer(minLength: 0)
            if let d = t.date, d < today, t.soft != true { Text("ritardo").font(.caption2).foregroundStyle(.red) }
            else { Text(t.date.flatMap { $0 > today ? Summary.date($0) : nil }.map { $0.formatted(.dateTime.weekday(.abbreviated).day().locale(Locale(identifier: "it_IT"))) } ?? "oggi")
                .font(.caption2).foregroundStyle(.secondary) }
        }
        .padding(6)
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
