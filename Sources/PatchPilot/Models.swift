import Foundation

struct InstalledApp: Identifiable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let bundleURL: URL
    let versionString: String
    let buildString: String
    let appcastURL: URL?
    let isSystemManaged: Bool
    let isAppStoreManaged: Bool

    var displayVersion: String {
        if !versionString.isEmpty {
            return versionString
        }
        if !buildString.isEmpty {
            return buildString
        }
        return "—"
    }

    var comparisonVersion: String? {
        if !versionString.isEmpty {
            return versionString
        }
        if !buildString.isEmpty {
            return buildString
        }
        return nil
    }
}

enum UpdateStatus: String {
    case upToDate = "Up to date"
    case updateAvailable = "Update available"
    case unknown = "Unknown"
}

enum UpdateSource: String {
    case appcast = "Appcast"
    case catalog = "Catalog"
}

struct UpdateInfo {
    let latestVersion: String
    let downloadURL: String?
    let notes: String?
    let source: UpdateSource
}

struct AppUpdateRow: Identifiable {
    let id: String
    let installed: InstalledApp
    let updateInfo: UpdateInfo?
    let status: UpdateStatus

    var latestVersionText: String {
        updateInfo?.latestVersion ?? "—"
    }

    var downloadURL: URL? {
        guard let raw = updateInfo?.downloadURL else { return nil }
        return URL(string: raw)
    }
}
