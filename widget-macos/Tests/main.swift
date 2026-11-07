// Self-check di Summary: swiftc Widget/Model.swift Tests/main.swift -o /tmp/t && /tmp/t
import Foundation
let today = Summary.ymd(Date())
let yest = Summary.ymd(Date().addingTimeInterval(-86400))
let json = """
[{"id":"a","title":"A","size":3,"done":true,"doneAt":"\(today)"},
 {"id":"b","title":"B","size":1,"done":true,"doneAt":"\(today)"},
 {"id":"c","title":"C","done":true,"doneAt":"\(today)"},
 {"id":"d","title":"D","done":true,"doneAt":"\(yest)"},
 {"id":"x","del":true,"upd":1},
 {"id":"e","title":"in ritardo","date":"2000-01-01"},
 {"id":"f","title":"prio","prio":0,"date":"2999-01-01"},
 {"id":"g","title":"senza data","prio":1},
 {"id":"m","title":"senza scadenza","soft":true,"prio":0,"date":"2000-01-01"},
 {"id":"h","title":"vita","life":true},
 {"id":"i","title":"dopo","project":"afk","date":"2999-01-02"},
 {"id":"j","done":true,"doneAt":"2020-01-01"},{"id":"k","done":true,"doneAt":"2020-01-02"},{"id":"l","done":true,"doneAt":"2020-01-03"}]
""".data(using: .utf8)!
let s = Summary(tasks: try! JSONDecoder().decode([Mission].self, from: json))
assert(s.xp == 50 + 10 + 25 + 25 + 20 + 75, "xp \(s.xp)")  // 3 oggi = missione +20
assert(s.level == 3 && s.rank == "Pianificatore")
assert(s.best == 3 && s.doneToday == 3)
assert(s.focus.map(\.id) == ["g", "e", "m"], "\(s.focus.map(\.id))")  // f è futura, h è vita, m (soft) in fondo
assert(s.upcoming.map(\.id) == ["f", "i"])
let fa = Summary(tasks: try! JSONDecoder().decode([Mission].self, from: json), filter: "afk")
assert(fa.focus.isEmpty && fa.upcoming.map(\.id) == ["i"])
print("ok")
