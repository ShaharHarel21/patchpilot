import Foundation

struct BrewUpdateRow: Identifiable {
    enum Kind: String {
        case formula = "Formula"
        case cask = "Cask"
    }

    let id: String
    let name: String
    let installedVersion: String
    let latestVersion: String
    let kind: Kind

    var upgradeCommand: String {
        switch kind {
        case .formula:
            return "brew upgrade \(name)"
        case .cask:
            return "brew upgrade --cask \(name)"
        }
    }
}

enum BrewServiceError: Error, LocalizedError {
    case brewNotFound
    case commandFailed(String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .brewNotFound:
            return "Homebrew was not found on this Mac."
        case .commandFailed(let message):
            return "Homebrew error: \(message)"
        case .decodingFailed:
            return "Homebrew output could not be decoded."
        }
    }
}

struct BrewService {
    static func fetchOutdated() async throws -> [BrewUpdateRow] {
        guard let brewURL = locateBrew() else {
            throw BrewServiceError.brewNotFound
        }

        let output = try await run(command: brewURL.path, arguments: ["outdated", "--json=v2"])
        guard let data = output.data(using: .utf8) else {
            throw BrewServiceError.decodingFailed
        }

        let decoder = JSONDecoder()
        guard let response = try? decoder.decode(BrewOutdatedResponse.self, from: data) else {
            throw BrewServiceError.decodingFailed
        }

        var results: [BrewUpdateRow] = []

        for formula in response.formulae {
            let installed = formula.installedVersions.joined(separator: ", ")
            let latest = formula.currentVersion
            results.append(
                BrewUpdateRow(
                    id: "formula-\(formula.name)",
                    name: formula.name,
                    installedVersion: installed,
                    latestVersion: latest,
                    kind: .formula
                )
            )
        }

        for cask in response.casks {
            let installed = cask.installedVersions.joined(separator: ", ")
            let latest = cask.currentVersion
            results.append(
                BrewUpdateRow(
                    id: "cask-\(cask.name)",
                    name: cask.name,
                    installedVersion: installed,
                    latestVersion: latest,
                    kind: .cask
                )
            )
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func locateBrew() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
            "/usr/bin/brew"
        ]

        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private static func run(command: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: command)
                process.arguments = arguments

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                if process.terminationStatus != 0 {
                    let message = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: BrewServiceError.commandFailed(message))
                    return
                }

                let output = String(data: outputData, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            }
        }
    }
}

private struct BrewOutdatedResponse: Codable {
    let formulae: [BrewFormula]
    let casks: [BrewCask]
}

private struct BrewFormula: Codable {
    let name: String
    let installedVersions: [String]
    let currentVersion: String

    enum CodingKeys: String, CodingKey {
        case name
        case installedVersions = "installed_versions"
        case currentVersion = "current_version"
    }
}

private struct BrewCask: Codable {
    let name: String
    let installedVersions: [String]
    let currentVersion: String

    enum CodingKeys: String, CodingKey {
        case name
        case installedVersions = "installed_versions"
        case currentVersion = "current_version"
    }
}
