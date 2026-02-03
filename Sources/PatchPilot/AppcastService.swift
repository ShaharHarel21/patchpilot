import Foundation

struct AppcastEntry {
    let latestVersion: String
    let downloadURL: String?
    let notes: String?
}

struct AppcastService {
    static func fetchEntries(for apps: [InstalledApp]) async -> [String: AppcastEntry] {
        let candidates = apps.compactMap { app -> (String, URL)? in
            guard let url = app.appcastURL else { return nil }
            return (app.id, url)
        }

        guard !candidates.isEmpty else { return [:] }

        var results: [String: AppcastEntry] = [:]
        await withTaskGroup(of: (String, AppcastEntry?).self) { group in
            for (appID, url) in candidates {
                group.addTask {
                    let entry = await fetchEntry(from: url)
                    return (appID, entry)
                }
            }

            for await (appID, entry) in group {
                if let entry {
                    results[appID] = entry
                }
            }
        }

        return results
    }

    private static func fetchEntry(from url: URL) async -> AppcastEntry? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let items = AppcastParser.parse(data: data)
            guard let best = AppcastParser.selectLatest(from: items) else { return nil }
            return AppcastEntry(
                latestVersion: best.displayVersion,
                downloadURL: best.downloadURL,
                notes: best.notes
            )
        } catch {
            return nil
        }
    }
}

struct AppcastItem {
    let version: String
    let shortVersion: String?
    let downloadURL: String?
    let notes: String?

    var displayVersion: String {
        shortVersion ?? version
    }

    var compareVersion: String {
        shortVersion ?? version
    }
}

enum AppcastParser {
    static func parse(data: Data) -> [AppcastItem] {
        let parser = XMLParser(data: data)
        let delegate = AppcastXMLParser()
        parser.delegate = delegate
        parser.parse()
        return delegate.items
    }

    static func selectLatest(from items: [AppcastItem]) -> AppcastItem? {
        guard var best = items.first else { return nil }
        for item in items.dropFirst() {
            if Version.isNewer(available: item.compareVersion, than: best.compareVersion) {
                best = item
            }
        }
        return best
    }
}

private final class AppcastXMLParser: NSObject, XMLParserDelegate {
    private(set) var items: [AppcastItem] = []

    private var inItem = false
    private var currentVersion: String?
    private var currentShortVersion: String?
    private var currentDownloadURL: String?
    private var currentNotes: String?

    private var currentElement: String?
    private var currentText: String = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        currentElement = elementName
        currentText = ""

        if elementName == "item" {
            inItem = true
            currentVersion = nil
            currentShortVersion = nil
            currentDownloadURL = nil
            currentNotes = nil
        }

        guard inItem else { return }

        if elementName == "enclosure" {
            currentDownloadURL = attributeDict["url"]
            if let version = attributeDict["sparkle:version"] ?? attributeDict["version"] {
                currentVersion = version
            }
            if let shortVersion = attributeDict["sparkle:shortVersionString"] {
                currentShortVersion = shortVersion
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard inItem else { return }

        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "sparkle:version":
            if !trimmed.isEmpty {
                currentVersion = trimmed
            }
        case "sparkle:shortVersionString":
            if !trimmed.isEmpty {
                currentShortVersion = trimmed
            }
        case "description", "sparkle:releaseNotesLink", "sparkle:releaseNotes":
            if !trimmed.isEmpty {
                currentNotes = trimmed
            }
        case "item":
            if let version = currentVersion ?? currentShortVersion {
                let item = AppcastItem(
                    version: version,
                    shortVersion: currentShortVersion,
                    downloadURL: currentDownloadURL,
                    notes: currentNotes
                )
                items.append(item)
            }
            inItem = false
        default:
            break
        }

        currentElement = nil
        currentText = ""
    }
}
