import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var updater: UpdaterStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            table
            brewSection
            footer
        }
        .frame(minWidth: 960, minHeight: 600)
        .task {
            await model.bootstrapIfNeeded()
        }
        .alert(item: $model.alertMessage) { message in
            Alert(
                title: Text("Catalog Error"),
                message: Text(message.text),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            TextField("Search apps", text: $model.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)

            Toggle("Only Updates", isOn: $model.showOnlyUpdates)
                .toggleStyle(.switch)

            Spacer()

            if model.isChecking {
                ProgressView()
                    .controlSize(.small)
            }

            Button("Check App Updates") {
                Task { await model.refresh(triggeredByTimer: false) }
            }
            .keyboardShortcut("r", modifiers: [.command])

            Button("Check PatchPilot Updates") {
                updater.checkForUpdates()
            }
            .disabled(!updater.canCheckForUpdates)
        }
        .padding(16)
    }

    private var table: some View {
        Table(model.filteredRows) {
            TableColumn("App") { row in
                HStack(spacing: 10) {
                    AppIconView(app: row.installed)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.installed.name)
                        if let bundleID = row.installed.bundleIdentifier {
                            Text(bundleID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            TableColumn("Installed") { row in
                Text(row.installed.displayVersion)
            }
            TableColumn("Latest") { row in
                Text(row.latestVersionText)
            }
            TableColumn("Status") { row in
                StatusBadge(status: row.status)
            }
            TableColumn("Action") { row in
                if row.status == .updateAvailable, let _ = row.downloadURL {
                    Button("Open Download") {
                        model.openDownload(for: row)
                    }
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 140)
        }
        .padding(.horizontal, 12)
    }

    private var brewSection: some View {
        Group {
            if model.preferences.includeHomebrewUpdates {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Homebrew Updates")
                            .font(.headline)
                        Spacer()
                        if model.isCheckingBrew {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("\(model.brewUpdatesCount) outdated")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    if let message = model.brewAlertMessage?.text {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                    }

                    Table(model.brewUpdates) {
                        TableColumn("Package") { row in
                            Text(row.name)
                        }
                        TableColumn("Installed") { row in
                            Text(row.installedVersion)
                        }
                        TableColumn("Latest") { row in
                            Text(row.latestVersion)
                        }
                        TableColumn("Type") { row in
                            Text(row.kind.rawValue)
                        }
                        TableColumn("Action") { row in
                            Button("Copy upgrade") {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(row.upgradeCommand, forType: .string)
                            }
                        }
                        .width(min: 140)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Updates: \(model.updatesAvailableCount)")
            if model.preferences.includeHomebrewUpdates {
                Text("Homebrew: \(model.brewUpdatesCount)")
            }
            Spacer()
            Text("Auto-update: \(autoUpdateStatus)")
                .foregroundStyle(.secondary)
            Text("Last checked: \(model.lastCheckedText)")
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private var autoUpdateStatus: String {
        guard updater.automaticallyChecksForUpdates else { return "Off" }
        if updater.automaticallyDownloadsUpdates {
            return "On (silent)"
        }
        return "On"
    }
}

private struct AppIconView: View {
    let app: InstalledApp

    var body: some View {
        let image = NSWorkspace.shared.icon(forFile: app.bundleURL.path)
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
            .cornerRadius(5)
    }
}

private struct StatusBadge: View {
    let status: UpdateStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(statusColor.opacity(0.12))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status {
        case .upToDate:
            return .green
        case .updateAvailable:
            return .orange
        case .notTracked:
            return .secondary
        case .unknownVersion:
            return .secondary
        }
    }
}
