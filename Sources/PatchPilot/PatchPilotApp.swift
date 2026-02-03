import SwiftUI

@main
struct PatchPilotApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var updater = UpdaterStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .environmentObject(updater)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesCommand(updater: updater)
            }
        }
        Settings {
            SettingsView()
                .environmentObject(model)
                .environmentObject(updater)
        }
    }
}
