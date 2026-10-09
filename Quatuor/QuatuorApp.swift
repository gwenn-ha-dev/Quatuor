import AppKit
import SwiftUI

@main
struct QuatuorApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(delegate.state)
                .frame(minWidth: 720, minHeight: 480)
        }
        // Tall enough for the four stems of the result without scrolling.
        .defaultSize(width: 900, height: 680)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

/// Owns the app state so that a file handed over at launch (`open -a Quatuor
/// song.mp3`, which `outils/captures.sh` relies on) lands in the one window.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        state.reset()
        Task { await state.open(url) }
    }

    /// Leaving the result screen deletes its temporary stems; quitting must too,
    /// or each separation leaves four uncompressed WAV files behind.
    func applicationWillTerminate(_ notification: Notification) {
        state.reset()
    }
}
