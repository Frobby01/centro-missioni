import AppKit
import SwiftUI
import WidgetKit

let site = URL(string: "https://frobby01.github.io/centro-missioni/")!

// Su macOS i clic sul widget aprono quest'app con un URL:
// centromissioni://filter/<id> attiva/disattiva il filtro, qualsiasi altro apre il sito.
// In entrambi i casi l'app esce subito senza mostrare finestre.
final class Delegate: NSObject, NSApplicationDelegate {
    var openedByURL = false
    var window: NSWindow?

    // Arriva prima di applicationDidFinishLaunching quando l'app è lanciata da un URL.
    func application(_ app: NSApplication, open urls: [URL]) {
        openedByURL = true
        for url in urls {
            if url.scheme == "centromissioni", url.host == "filter" {
                let id = url.lastPathComponent
                Shared.write("filter", Shared.read("filter") == id ? nil : id)
                WidgetCenter.shared.reloadAllTimelines()
            } else {
                NSWorkspace.shared.open(site)
            }
        }
        // lascia il tempo alla richiesta di reload di arrivare al sistema
        if window == nil { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { app.terminate(nil) } }
    }

    func applicationDidFinishLaunching(_ note: Notification) {
        guard !openedByURL else { return }
        let w = NSWindow(contentViewController: NSHostingController(rootView: Guide()))
        w.title = "Centro Missioni"
        w.styleMask.remove(.resizable)
        w.center()
        w.makeKeyAndOrderFront(nil)
        window = w
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }
}

struct Guide: View {
    @State private var token = Shared.read("token") ?? ""
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Centro Missioni").font(.title2.bold())
            Text("1. Incolla qui il token GitHub (lo stesso del sito, permesso Contents: Read su centro-missioni-data) e premi Salva.")
            HStack {
                SecureField("github_pat_…", text: $token).textFieldStyle(.roundedBorder)
                Button("Salva") {
                    Shared.write("token", token.trimmingCharacters(in: .whitespacesAndNewlines))
                    WidgetCenter.shared.reloadAllTimelines()
                    saved = true
                }
                .keyboardShortcut(.defaultAction)
            }
            if saved { Text("Salvato ✓ Il widget si aggiorna tra pochi secondi.").foregroundStyle(.green) }
            Text("2. Clic destro sul desktop → Modifica widget → cerca \"Centro Missioni\".")
            Text("Il widget si aggiorna ogni 15 minuti; un clic apre il sito.").foregroundStyle(.secondary)
            Link("Apri il sito", destination: site)
        }
        .padding(24)
        .frame(width: 460)
    }
}

@main
enum Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = Delegate()
        app.delegate = delegate
        app.run()
    }
}
