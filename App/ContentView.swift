import AppKit
import SwiftUI

struct ContentView: View {
    @State private var status: ExtensionStatus?

    /// General › Login Items & Extensions, which lists Quick Look extensions under Extensions.
    private static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MarkdownQuicklook").font(.title.bold())
            Text("Select a .md or .markdown file in Finder and press Space to see it rendered the way GitHub shows it.")
                .fixedSize(horizontal: false, vertical: true)

            GroupBox {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: symbol).font(.title).foregroundStyle(color)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(headline).font(.headline)
                        Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(8)
            }

            HStack {
                Button("Open Login Items & Extensions") { NSWorkspace.shared.open(Self.settingsURL) }
                Button("Check Again") { refresh() }
                Spacer()
            }
        }
        .padding(24)
        .frame(width: 520)
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
    }

    private func refresh() {
        Task { status = await ExtensionStatus.checkInBackground() }
    }

    private var symbol: String {
        switch status {
        case .enabled: "checkmark.circle.fill"
        case .none: "hourglass"
        default: "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch status {
        case .enabled: .green
        case .none: .secondary
        default: .orange
        }
    }

    private var headline: String {
        switch status {
        case .enabled: "The preview extension is enabled."
        case .disabled: "The preview extension is turned off."
        case .superseded: "Another copy of the extension is in use."
        case .notRegistered: "macOS hasn't registered the preview extension yet."
        case .unknown: "Couldn't check the preview extension."
        case .none: "Checking…"
        }
    }

    private var detail: String {
        let place = "System Settings › General › Login Items & Extensions, in the Extensions list"
        let path = "\(place): find this app and turn its Quick Look extension on."
        switch status {
        case .enabled: return "If another markdown previewer still appears instead, turn that one off in \(place)."
        case .disabled: return "Turn it on in \(path)"
        case .superseded: return "Delete other copies of this app, keep the one in /Applications, then open it again."
        case .notRegistered: return "Move the app to /Applications and open it again. If it still isn't listed, turn it on in \(path)"
        case let .unknown(reason): return "\(reason) Check it in \(path)"
        case .none: return ""
        }
    }
}

#Preview {
    ContentView()
}
