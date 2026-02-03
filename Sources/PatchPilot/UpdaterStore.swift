import Combine
import Sparkle
import SwiftUI

@MainActor
final class UpdaterStore: ObservableObject {
    let controller: SPUStandardUpdaterController
    @Published var canCheckForUpdates = false
    @Published var automaticallyChecksForUpdates = false
    @Published var automaticallyDownloadsUpdates = false

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
