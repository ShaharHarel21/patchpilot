import Foundation
import SwiftUI
import AppKit

@MainActor
final class AppModel: ObservableObject {
    @Published var rows: [AppUpdateRow] = []
    @Published var brewUpdates: [BrewUpdateRow] = []
    @Published var isChecking = false
    @Published var isCheckingBrew = false
    @Published var lastChecked: Date?
    @Published var alertMessage: AlertMessage?
    @Published var brewAlertMessage: AlertMessage?
    @Published var searchText = ""
    @Published var showOnlyUpdates = false
    @Published var preferences: Preferences = Preferences.load() {
        didSet {
            preferences.save()
        }
    }

    private let notificationManager = NotificationManager()
    private var timer: Timer?
    private var hasBootstrapped = false

    var updatesAvailableCount: Int {
        rows.filter { $0.status == .updateAvailable }.count
    }

    var brewUpdatesCount: Int {
        brewUpdates.count
    }

    var filteredRows: [AppUpdateRow] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let bySearch: [AppUpdateRow]
        if trimmedQuery.isEmpty {
            bySearch = rows
        } else {
            bySearch = rows.filter { row in
                row.installed.name.localizedCaseInsensitiveContains(trimmedQuery)
                || row.installed.bundleIdentifier?.localizedCaseInsensitiveContains(trimmedQuery) == true
            }
        }

        if showOnlyUpdates {
            return bySearch.filter { $0.status == .updateAvailable }
        }
        return bySearch
    }

    var lastCheckedText: String {
        guard let lastChecked else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastChecked)
    }

    func bootstrapIfNeeded() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        startAutoCheck()
        await refresh(triggeredByTimer: false)
    }

    func refresh(triggeredByTimer: Bool) async {
        guard !isChecking else { return }
        isChecking = true
        alertMessage = nil
        brewAlertMessage = nil
        defer { isChecking = false }

        let installed = AppScanner.scan(
            excludingSystemApps: preferences.excludeSystemApps,
            excludingAppStoreApps: preferences.excludeAppStoreApps
        )
        do {
            let source = try catalogSource()
            async let catalog = UpdateCatalogLoader.load(source: source)
            let brewTask: Task<[BrewUpdateRow], Error>? = preferences.includeHomebrewUpdates
                ? Task { try await BrewService.fetchOutdated() }
                : nil
            let catalogResult = try await catalog
            let appcastEntries: [String: AppcastEntry]
            if preferences.checkSparkleAppcasts {
                appcastEntries = await AppcastService.fetchEntries(for: installed)
            } else {
                appcastEntries = [:]
            }
            let merged = UpdateMerger.merge(
                installed: installed,
                catalogEntries: catalogResult.apps,
                appcastEntries: appcastEntries
            )
            rows = merged.sorted { $0.installed.name.localizedCaseInsensitiveCompare($1.installed.name) == .orderedAscending }

            if let brewTask {
                isCheckingBrew = true
                do {
                    brewUpdates = try await brewTask.value
                } catch {
                    brewUpdates = []
                    brewAlertMessage = AlertMessage(text: error.localizedDescription)
                }
                isCheckingBrew = false
            } else {
                brewUpdates = []
                isCheckingBrew = false
            }
            lastChecked = Date()

            if preferences.notifyOnUpdates {
                await notificationManager.notifyUpdatesFound(count: updatesAvailableCount)
            }
        } catch {
            rows = installed.map { AppUpdateRow(id: $0.id, installed: $0, updateInfo: nil, status: .unknown) }
            brewUpdates = []
            isCheckingBrew = false
            lastChecked = Date()
            alertMessage = AlertMessage(text: error.localizedDescription)
        }
    }

    func openDownload(for row: AppUpdateRow) {
        guard let url = row.downloadURL else { return }
        NSWorkspace.shared.open(url)
    }

    func startAutoCheck() {
        timer?.invalidate()
        let interval = max(1, preferences.checkIntervalHours)
        let seconds = TimeInterval(interval * 3600)
        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.refresh(triggeredByTimer: true) }
        }
    }

    func reloadCatalog() async {
        await refresh(triggeredByTimer: false)
    }

    private func catalogSource() throws -> CatalogSource {
        if preferences.useSampleCatalog {
            return .sample
        }

        let trimmed = preferences.catalogURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), !trimmed.isEmpty else {
            throw CatalogError.invalidURL
        }
        return .url(url)
    }
}

struct Preferences: Codable, Equatable {
    var useSampleCatalog: Bool
    var catalogURLString: String
    var checkIntervalHours: Int
    var notifyOnUpdates: Bool
    var excludeSystemApps: Bool
    var excludeAppStoreApps: Bool
    var checkSparkleAppcasts: Bool
    var includeHomebrewUpdates: Bool

    static func load() -> Preferences {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: StorageKey.preferences),
           let stored = try? JSONDecoder().decode(Preferences.self, from: data) {
            return stored
        }
        return Preferences(
            useSampleCatalog: true,
            catalogURLString: "",
            checkIntervalHours: 6,
            notifyOnUpdates: true,
            excludeSystemApps: true,
            excludeAppStoreApps: false,
            checkSparkleAppcasts: true,
            includeHomebrewUpdates: false
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: StorageKey.preferences)
        }
    }
}

private enum StorageKey {
    static let preferences = "PatchPilot.preferences"
}

struct AlertMessage: Identifiable {
    let id = UUID()
    let text: String
}
