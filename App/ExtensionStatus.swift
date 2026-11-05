import Foundation

/// Whether macOS will use the embedded Quick Look extension, read from `pluginkit`'s election tag.
/// macOS has no public API for this, and `pluginkit` refuses the query from inside App Sandbox
/// ("unauthorized discovery flag (PKDiscoverAll)", 2026-11-05), so the host app is not sandboxed.
enum ExtensionStatus: Equatable {
    case enabled
    case disabled
    /// Another copy of the extension (for example an older build) is registered instead.
    case superseded
    case notRegistered
    case unknown(String)

    /// The embedded extension's bundle identifier, from the app's own PlugIns folder.
    static var extensionIdentifier: String? {
        guard let plugins = Bundle.main.builtInPlugInsURL,
              let appex = try? FileManager.default.contentsOfDirectory(at: plugins, includingPropertiesForKeys: nil)
                .first(where: { $0.pathExtension == "appex" }) else { return nil }
        return Bundle(url: appex)?.bundleIdentifier
    }

    /// Runs `check()` off the main thread so the window never waits on `pluginkit`.
    static func checkInBackground() async -> ExtensionStatus {
        await Task.detached(priority: .userInitiated) { check() }.value
    }

    static func check() -> ExtensionStatus {
        guard let id = extensionIdentifier else { return .unknown("The app has no embedded extension.") }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = ["-m", "-i", id]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return .unknown(error.localizedDescription)
        }
        // Read to end of file before waiting, so a full pipe buffer can't deadlock the two processes.
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        return parse(output, identifier: id)
    }

    /// `pluginkit -m` prints one line per match, prefixed by `+` (use), `-` (ignore), `!` (debug),
    /// `=` (superseded) or nothing (the default election, which for Quick Look is "use").
    static func parse(_ output: String, identifier: String) -> ExtensionStatus {
        guard let line = output.split(separator: "\n").first(where: { $0.contains(identifier) }) else { return .notRegistered }
        switch line.trimmingCharacters(in: .whitespaces).first {
        case "-": return .disabled
        case "=": return .superseded
        default: return .enabled
        }
    }
}
