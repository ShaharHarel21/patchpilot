import Foundation

struct UpdateCatalog: Codable {
    let lastUpdated: String?
    let apps: [CatalogEntry]
}

struct CatalogEntry: Codable {
    let name: String
    let bundleIdentifier: String?
    let latestVersion: String
    let downloadURL: String
    let notes: String?

    var matchKey: String {
        if let bundleIdentifier {
            return bundleIdentifier.lowercased()
        }
        return name.lowercased()
    }
}

enum CatalogSource {
    case sample
    case url(URL)
}

enum CatalogError: Error, LocalizedError {
    case invalidURL
    case missingSample
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The catalog URL is invalid."
        case .missingSample:
            return "The built-in sample catalog could not be found."
        case .decodingFailed:
            return "The catalog JSON could not be decoded."
        }
    }
}

struct UpdateCatalogLoader {
    static func load(source: CatalogSource) async throws -> UpdateCatalog {
        let data: Data
        switch source {
        case .sample:
            guard let url = Bundle.module.url(forResource: "catalog.sample", withExtension: "json") else {
                throw CatalogError.missingSample
            }
            data = try Data(contentsOf: url)
        case .url(let url):
            if url.isFileURL {
                data = try Data(contentsOf: url)
            } else {
                let (remoteData, _) = try await URLSession.shared.data(from: url)
                data = remoteData
            }
        }

        let decoder = JSONDecoder()
        guard let catalog = try? decoder.decode(UpdateCatalog.self, from: data) else {
            throw CatalogError.decodingFailed
        }
        return catalog
    }
}

struct UpdateMerger {
    static func merge(
        installed: [InstalledApp],
        catalogEntries: [CatalogEntry],
        appcastEntries: [String: AppcastEntry]
    ) -> [AppUpdateRow] {
        var byBundleID: [String: CatalogEntry] = [:]
        var byName: [String: CatalogEntry] = [:]

        for entry in catalogEntries {
            if let bundleID = entry.bundleIdentifier?.lowercased(), byBundleID[bundleID] == nil {
                byBundleID[bundleID] = entry
            }
            let nameKey = entry.name.lowercased()
            if byName[nameKey] == nil {
                byName[nameKey] = entry
            }
        }

        return installed.map { app in
            let updateInfo = matchUpdate(for: app, byBundleID: byBundleID, byName: byName, appcastEntries: appcastEntries)
            let status = status(for: app, update: updateInfo)
            return AppUpdateRow(
                id: app.id,
                installed: app,
                updateInfo: updateInfo,
                status: status
            )
        }
    }

    private static func matchUpdate(
        for app: InstalledApp,
        byBundleID: [String: CatalogEntry],
        byName: [String: CatalogEntry],
        appcastEntries: [String: AppcastEntry]
    ) -> UpdateInfo? {
        if let appcast = appcastEntries[app.id] {
            return UpdateInfo(
                latestVersion: appcast.latestVersion,
                downloadURL: appcast.downloadURL,
                notes: appcast.notes,
                source: .appcast
            )
        }

        if let bundleID = app.bundleIdentifier?.lowercased(), let entry = byBundleID[bundleID] {
            return UpdateInfo(
                latestVersion: entry.latestVersion,
                downloadURL: entry.downloadURL,
                notes: entry.notes,
                source: .catalog
            )
        }

        if let entry = byName[app.name.lowercased()] {
            return UpdateInfo(
                latestVersion: entry.latestVersion,
                downloadURL: entry.downloadURL,
                notes: entry.notes,
                source: .catalog
            )
        }

        return nil
    }

    private static func status(for app: InstalledApp, update: UpdateInfo?) -> UpdateStatus {
        guard let update else { return .unknown }
        guard let installedVersion = app.comparisonVersion else { return .unknown }
        if Version.isNewer(available: update.latestVersion, than: installedVersion) {
            return .updateAvailable
        }
        return .upToDate
    }
}
