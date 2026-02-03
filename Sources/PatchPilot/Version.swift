import Foundation

struct Version: Comparable {
    let components: [Int]
    let original: String

    init?(_ string: String) {
        let numbers = string
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }

        guard !numbers.isEmpty else { return nil }
        self.components = numbers
        self.original = string
    }

    static func < (lhs: Version, rhs: Version) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)
        for index in 0..<maxCount {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }

    static func isNewer(available: String, than installed: String) -> Bool {
        guard let availableVersion = Version(available), let installedVersion = Version(installed) else {
            return false
        }
        return availableVersion > installedVersion
    }
}
