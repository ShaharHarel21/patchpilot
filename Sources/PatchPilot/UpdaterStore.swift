import Combine
import Sparkle
import SwiftUI

@MainActor
final class UpdaterStore: ObservableObject {
    let controller: SPUStandardUpdaterController
    @Published var canCheckForUpdates = false

    private var cancellable: AnyCancellable?

    init() {
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        cancellable = controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: \.canCheckForUpdates, on: self)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
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
