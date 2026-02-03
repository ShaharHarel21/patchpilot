import Foundation

struct AppScanner {
    static let searchPaths: [String] = [
        "/Applications",
        "/System/Applications",
        (NSHomeDirectory() as NSString).appendingPathComponent("Applications")
    ]

    static func scan(excludingSystemApps: Bool, excludingAppStoreApps: Bool) -> [InstalledApp] {
        var found: [InstalledApp] = []
        let fileManager = FileManager.default

        for path in searchPaths {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "app" else { continue }
                if let app = InstalledApp.fromBundle(url: fileURL) {
                    if excludingSystemApps, app.isSystemManaged { continue }
                    if excludingAppStoreApps, app.isAppStoreManaged { continue }
                    found.append(app)
                }
            }
        }

        var unique: [String: InstalledApp] = [:]
        for app in found {
            let key = app.bundleIdentifier ?? app.bundleURL.path
            if unique[key] == nil {
                unique[key] = app
            }
        }

        return unique.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

private extension InstalledApp {
    static func fromBundle(url: URL) -> InstalledApp? {
        guard let bundle = Bundle(url: url) else { return nil }

        let name = (
            bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ) ?? (
            bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        ) ?? url.deletingPathExtension().lastPathComponent

        let version = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
        let build = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? ""
        let bundleID = bundle.bundleIdentifier
        let appcastString = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String
        let appcastURL = appcastString.flatMap { URL(string: $0) }

        let isSystemManaged = AppScanner.isSystemManagedApp(bundleURL: url, bundleIdentifier: bundleID)
        let isAppStoreManaged = AppScanner.isAppStoreApp(bundleURL: url)

        let id = bundleID ?? url.path
        return InstalledApp(
            id: id,
            name: name,
            bundleIdentifier: bundleID,
            bundleURL: url,
            versionString: version,
            buildString: build,
            appcastURL: appcastURL,
            isSystemManaged: isSystemManaged,
            isAppStoreManaged: isAppStoreManaged
        )
    }
}

private extension AppScanner {
    static func isSystemManagedApp(bundleURL: URL, bundleIdentifier: String?) -> Bool {
        let path = bundleURL.path
        let systemPrefixes = [
            "/System/Applications",
            "/System/Library/CoreServices/Applications",
            "/System/Library"
        ]
        if systemPrefixes.contains(where: { path.hasPrefix($0) }) {
            return true
        }
        if let bundleIdentifier, bundleIdentifier.hasPrefix("com.apple.") {
            return true
        }
        return false
    }

    static func isAppStoreApp(bundleURL: URL) -> Bool {
        let receiptURL = bundleURL.appendingPathComponent("Contents/_MASReceipt/receipt")
        return FileManager.default.fileExists(atPath: receiptURL.path)
    }
}
