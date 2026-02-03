import Combine
import Sparkle
import SwiftUI

@MainActor
final class UpdaterStore: ObservableObject {
    let controller: SPUStandardUpdaterController
    @Published var canCheckForUpdates = false
    @Published var automaticallyChecksForUpdates = false
    @Published var automaticallyDownloadsUpdates = false
    @Published var updateCheckIntervalHours: Int = 6

    private var cancellables: Set<AnyCancellable> = []

    init() {
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: \.canCheckForUpdates, on: self)
            .store(in: &cancellables)

        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: \.automaticallyChecksForUpdates, on: self)
            .store(in: &cancellables)

        controller.updater.publisher(for: \.automaticallyDownloadsUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: \.automaticallyDownloadsUpdates, on: self)
            .store(in: &cancellables)

        let intervalSeconds = controller.updater.updateCheckInterval
        if intervalSeconds > 0 {
            updateCheckIntervalHours = max(1, Int(intervalSeconds / 3600))
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
        if !enabled {
            controller.updater.automaticallyDownloadsUpdates = false
        }
    }

    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        controller.updater.automaticallyDownloadsUpdates = enabled
        if enabled && !controller.updater.automaticallyChecksForUpdates {
            controller.updater.automaticallyChecksForUpdates = true
        }
    }

    func setUpdateCheckIntervalHours(_ hours: Int) {
        let clamped = max(1, min(hours, 24))
        updateCheckIntervalHours = clamped
        controller.updater.updateCheckInterval = TimeInterval(clamped * 3600)
    }
}

struct CheckForUpdatesCommand: View {
    @ObservedObject var updater: UpdaterStore

    var body: some View {
        Button("Check for PatchPilot Updates…") {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates)
    }
}
