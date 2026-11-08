import Foundation

// Porting di stats()/focusHTML() da index.html: tenere allineate le costanti.
struct Mission: Decodable {
    let id: String
    var title: String?
    var project: String?
    var size: Int?
    var date: String?
    var time: String?
    var done: Bool?
    var doneAt: String?
    var prio: Double?
    var life: Bool?
    var soft: Bool?
    var del: Bool?

    var xp: Int { [1: 10, 2: 25, 3: 50][size ?? 2] ?? 25 }
}

struct Summary {
    var xp = 0, level = 1, cur = 0, next = 40, best = 0, doneToday = 0
    var rank = "Recluta"
    var focus: [Mission] = []
    var upcoming: [Mission] = []
    var filter: String?
    var error: String?

    static let questN = 3, questXP = 20
    // stesso ordine di PROJECTS in index.html
    static let projects: [(id: String, name: String, emoji: String)] = [
        ("aisa", "AISA", "🎓"), ("afk", "AFK", "🕹️"), ("frobby", "Frobby", "🐸"), ("giochi", "Game Dev", "🎮"),
        ("cinic", "Cinic Games", "💀"), ("vgi", "Videogiochitalia.it", "🖥️"), ("personale", "Altro", "🎨"),
    ]
    static let ranks = ["Recluta", "Apprendista", "Pianificatore", "Stratega", "Capomissione", "Veterano", "Leggenda"]

    static func ymd(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func date(_ s: String) -> Date? {
        let p = s.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    init(error: String) { self.error = error }

    init(tasks all: [Mission], filter: String? = nil, now: Date = Date()) {
        self.filter = filter
        let tasks = all.filter { $0.del != true }
        var byDay: [String: Int] = [:]
        for t in tasks where t.done == true {
            xp += t.xp
            if let d = t.doneAt { byDay[d, default: 0] += 1 }
        }
        xp += byDay.values.filter { $0 >= Self.questN }.count * Self.questXP
        level = Int((Double(xp) / 40).squareRoot()) + 1
        cur = 40 * (level - 1) * (level - 1)
        next = 40 * level * level
        rank = Self.ranks[min(level - 1, Self.ranks.count - 1)]

        let cal = Calendar.current
        let td = Self.ymd(now)
        doneToday = byDay[td] ?? 0
        var prev: Date?, run = 0
        for k in byDay.keys.compactMap(Self.date).sorted() {
            run = prev.flatMap { cal.date(byAdding: .day, value: 1, to: $0) } == k ? run + 1 : 1
            best = max(best, run); prev = k
        }

        let open = tasks.filter { $0.life != true && $0.done != true && (filter == nil || $0.project == filter) }
        upcoming = open.filter { ($0.date ?? "") > td }.sorted { ($0.date!, $0.time ?? "99:99") < ($1.date!, $1.time ?? "99:99") }
        focus = open
            .filter { ($0.date ?? "") <= td }
            .sorted {
                ($0.soft == true ? 1 : 0, $0.prio ?? 1e9, $0.date ?? "9999", -$0.xp) < ($1.soft == true ? 1 : 0, $1.prio ?? 1e9, $1.date ?? "9999", -$1.xp)
            }
    }
}

enum Remote {
    static let url = URL(string: "https://api.github.com/repos/Frobby01/centro-missioni-data/contents/tasks.json")!

    static func load(token: String, filter: String?) async -> Summary {
        guard !token.isEmpty else { return Summary(error: "Apri l'app Centro Missioni e incolla il token") }
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github.raw", forHTTPHeaderField: "Accept")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200 else {
                return Summary(error: [401, 403, 404].contains(code) ? "Token non valido o senza accesso" : "GitHub ha risposto \(code)")
            }
            return Summary(tasks: try JSONDecoder().decode([Mission].self, from: data), filter: filter)
        } catch {
            return Summary(error: "Sync non riuscita")
        }
    }
}
