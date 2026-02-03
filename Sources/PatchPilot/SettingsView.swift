import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var updater: UpdaterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            catalogSection
            Divider()
            scheduleSection
            Divider()
            scanSection
            Divider()
            notificationSection
            Divider()
            updaterSection
            Spacer()
        }
        .padding(20)
        .frame(width: 480)
        .onChange(of: model.preferences.checkIntervalHours) { _ in
            model.startAutoCheck()
        }
        .onChange(of: model.preferences.excludeSystemApps) { _ in
            Task { await model.refresh(triggeredByTimer: false) }
        }
        .onChange(of: model.preferences.excludeAppStoreApps) { _ in
            Task { await model.refresh(triggeredByTimer: false) }
        }
        .onChange(of: model.preferences.checkSparkleAppcasts) { _ in
            Task { await model.refresh(triggeredByTimer: false) }
        }
        .onChange(of: model.preferences.includeHomebrewUpdates) { _ in
            Task { await model.refresh(triggeredByTimer: false) }
        }
    }

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Catalog Source")
                .font(.headline)

            Picker("", selection: $model.preferences.useSampleCatalog) {
                Text("Use built-in sample").tag(true)
                Text("Use custom URL").tag(false)
            }
            .pickerStyle(.radioGroup)

            if !model.preferences.useSampleCatalog {
                TextField("https://example.com/catalog.json", text: $model.preferences.catalogURLString)
                    .textFieldStyle(.roundedBorder)
                Text("Tip: use file:///path/to/catalog.json for local files.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Reload Catalog") {
                    Task { await model.reloadCatalog() }
                }
                Spacer()
            }
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Check Schedule")
                .font(.headline)

            Stepper(value: $model.preferences.checkIntervalHours, in: 1...24, step: 1) {
                Text("Check every \(model.preferences.checkIntervalHours) hours")
            }
        }
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notifications")
                .font(.headline)

            Toggle("Notify when updates are found", isOn: $model.preferences.notifyOnUpdates)
        }
    }

    private var scanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scan Options")
                .font(.headline)

            Toggle("Check Sparkle appcasts (auto-detect)", isOn: $model.preferences.checkSparkleAppcasts)
            Toggle("Hide macOS system apps", isOn: $model.preferences.excludeSystemApps)
            Toggle("Hide Mac App Store apps", isOn: $model.preferences.excludeAppStoreApps)
            Toggle("Include Homebrew updates", isOn: $model.preferences.includeHomebrewUpdates)
        }
    }

    private var updaterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PatchPilot Updates")
                .font(.headline)

            Button("Check for PatchPilot Updates…") {
                updater.checkForUpdates()
            }
            .disabled(!updater.canCheckForUpdates)

            Toggle(
                "Automatically check for PatchPilot updates",
                isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: { updater.setAutomaticallyChecksForUpdates($0) }
                )
            )

            Toggle(
                "Download and install updates automatically",
                isOn: Binding(
                    get: { updater.automaticallyDownloadsUpdates },
                    set: { updater.setAutomaticallyDownloadsUpdates($0) }
                )
            )
            .disabled(!updater.automaticallyChecksForUpdates)

            Stepper(
                value: Binding(
                    get: { updater.updateCheckIntervalHours },
                    set: { updater.setUpdateCheckIntervalHours($0) }
                ),
                in: 1...24,
                step: 1
            ) {
                Text("Check every \(updater.updateCheckIntervalHours) hours")
            }
            .disabled(!updater.automaticallyChecksForUpdates)
        }
    }
}
