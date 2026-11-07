import Foundation

// Token e filtro stanno in una cartella che l'app scrive e il widget legge tramite un'eccezione del sandbox.
// Serve perché con la firma locale macOS 27 non accetta gli App Intents (né App Group) per il widget.
enum Shared {
    static let dir: URL = {
        let home = String(cString: getpwuid(getuid())!.pointee.pw_dir)  // la home vera, non il container
        return URL(fileURLWithPath: home).appendingPathComponent("Library/Application Support/CentroMissioni")
    }()

    static func read(_ name: String) -> String? {
        let s = (try? String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return s?.isEmpty == false ? s : nil
    }

    static func write(_ name: String, _ value: String?) {
        let url = dir.appendingPathComponent(name)
        guard let value, !value.isEmpty else { try? FileManager.default.removeItem(at: url); return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: Data(value.utf8), attributes: [.posixPermissions: 0o600])
    }
}
