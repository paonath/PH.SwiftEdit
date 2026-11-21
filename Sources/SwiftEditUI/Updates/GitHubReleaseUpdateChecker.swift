import Foundation

/// Minimal network transport seam enabling headless unit testing without live sockets (`TEST-004`, `SEC-004`).
public protocol HTTPDataFetching: Sendable {
    func fetch(request: URLRequest) async throws -> (Data, Int)
}

/// Ephemeral `URLSession` transport used exclusively for user-initiated HTTPS GET requests to GitHub Releases (`SEC-001`, `SEC-004`).
public struct URLSessionHTTPFetcher: HTTPDataFetching {
    public init() {}

    public func fetch(request: URLRequest) async throws -> (Data, Int) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http.statusCode)
    }
}

/// SemVer 2.0.0 comparator supporting leading `v` prefixes and alphanumeric prerelease tags (e.g. `0.0.1-alpha5 < 0.0.1-alpha6 < 0.0.1`).
public struct SemanticVersion: Comparable, Equatable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prereleaseIdentifiers: [String]
    public let canonicalString: String

    public init?(parsing raw: String) {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            trimmed.removeFirst()
        }
        let noBuild = trimmed.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? ""
        guard !noBuild.isEmpty else { return nil }

        let parts = noBuild.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let coreParts = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        guard coreParts.count == 3,
              let maj = Int(coreParts[0]), maj >= 0,
              let min = Int(coreParts[1]), min >= 0,
              let pat = Int(coreParts[2]), pat >= 0 else {
            return nil
        }

        let prerelease: [String]
        if parts.count == 2 {
            let rawPre = String(parts[1])
            guard !rawPre.isEmpty else { return nil }
            prerelease = rawPre.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            guard !prerelease.contains(where: \.isEmpty) else { return nil }
        } else {
            prerelease = []
        }

        self.major = maj
        self.minor = min
        self.patch = pat
        self.prereleaseIdentifiers = prerelease
        self.canonicalString = noBuild
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }

        // Absence of prerelease has higher precedence than any prerelease (`0.0.1-alpha5 < 0.0.1`).
        switch (lhs.prereleaseIdentifiers.isEmpty, rhs.prereleaseIdentifiers.isEmpty) {
        case (true, true): return false
        case (true, false): return false
        case (false, true): return true
        case (false, false):
            let count = max(lhs.prereleaseIdentifiers.count, rhs.prereleaseIdentifiers.count)
            for idx in 0..<count {
                if idx >= lhs.prereleaseIdentifiers.count { return true }
                if idx >= rhs.prereleaseIdentifiers.count { return false }
                let a = lhs.prereleaseIdentifiers[idx]
                let b = rhs.prereleaseIdentifiers[idx]
                if a == b { continue }
                return comparePrereleaseIdentifier(a, b) == .orderedAscending
            }
            return false
        }
    }

    private static func comparePrereleaseIdentifier(_ lhs: String, _ rhs: String) -> ComparisonResult {
        if let li = Int(lhs), let ri = Int(rhs) {
            return li < ri ? .orderedAscending : (li > ri ? .orderedDescending : .orderedSame)
        }
        if Int(lhs) != nil { return .orderedAscending }
        if Int(rhs) != nil { return .orderedDescending }

        // Compare `alpha5` vs `alpha10` naturally while keeping lexical precedence between different prefixes (`alpha` < `beta`).
        return lhs.localizedStandardCompare(rhs)
    }
}

/// Outcome returned by checking `paonath/PH.SwiftEdit` GitHub Releases against the running app version.
public enum UpdateCheckOutcome: Equatable, Sendable {
    case upToDate(currentVersion: String)
    case noReleasesFound(currentVersion: String)
    case updateAvailable(currentVersion: String, latestVersion: String, releaseURL: URL, downloadURL: URL?)
    case error(message: String)
}

/// Checks GitHub Releases (`paonath/PH.SwiftEdit`) via user-initiated HTTPS GET requests (`SEC-001`, `SEC-004`).
public struct GitHubReleaseUpdateChecker: Sendable {
    public static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/paonath/PH.SwiftEdit/releases/latest")!
    public static let releaseListAPIURL = URL(string: "https://api.github.com/repos/paonath/PH.SwiftEdit/releases?per_page=10")!
    public static let releasesPageURL = URL(string: "https://github.com/paonath/PH.SwiftEdit/releases")!

    private struct GitHubRelease: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: String

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadUrl = "browser_download_url"
            }
        }

        let tagName: String
        let htmlUrl: String
        let draft: Bool?
        let prerelease: Bool?
        let assets: [Asset]?

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlUrl = "html_url"
            case draft
            case prerelease
            case assets
        }
    }

    private let fetcher: any HTTPDataFetching

    public init(fetcher: any HTTPDataFetching = URLSessionHTTPFetcher()) {
        self.fetcher = fetcher
    }

    /// Queries GitHub Releases and compares the newest release tag against `currentVersion`.
    public func checkForUpdates(currentVersion: String) async -> UpdateCheckOutcome {
        do {
            let (latestData, latestStatus) = try await fetcher.fetch(request: Self.makeAPIRequest(url: Self.latestReleaseAPIURL))
            if latestStatus == 200 {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: latestData)
                return evaluate(releases: [release], currentVersion: currentVersion)
            }
            if latestStatus == 404 {
                // `/releases/latest` omits prereleases (e.g. alpha builds); fall back once to `/releases?per_page=10`.
                let (listData, listStatus) = try await fetcher.fetch(request: Self.makeAPIRequest(url: Self.releaseListAPIURL))
                if listStatus == 404 {
                    return .noReleasesFound(currentVersion: currentVersion)
                }
                guard listStatus == 200 else {
                    return .error(message: "GitHub Releases returned HTTP \(listStatus).")
                }
                let list = try JSONDecoder().decode([GitHubRelease].self, from: listData)
                return evaluate(releases: list, currentVersion: currentVersion)
            }
            return .error(message: "GitHub Releases returned HTTP \(latestStatus).")
        } catch {
            return .error(message: "Unable to check for updates: \(error.localizedDescription)")
        }
    }

    /// Validates that `rawURL` uses `https` targeting a canonical `github.com` or `githubusercontent.com` host (fail-closed `SEC-004`).
    public static func verifiedGitHubHTTPSURL(_ rawURL: String) -> URL? {
        guard let url = URL(string: rawURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              !host.isEmpty else {
            return nil
        }
        let trustedHosts: Set<String> = [
            "github.com",
            "www.github.com",
            "api.github.com",
            "objects.githubusercontent.com",
            "release-assets.githubusercontent.com",
        ]
        if trustedHosts.contains(host) {
            return url
        }
        return nil
    }

    private func evaluate(releases: [GitHubRelease], currentVersion: String) -> UpdateCheckOutcome {
        let candidates = releases.filter { ($0.draft ?? false) == false }
        guard !candidates.isEmpty else {
            return .noReleasesFound(currentVersion: currentVersion)
        }

        let currentSemVer = SemanticVersion(parsing: currentVersion)
        var bestRelease: (release: GitHubRelease, version: SemanticVersion)?
        for item in candidates {
            guard let parsed = SemanticVersion(parsing: item.tagName) else { continue }
            if let currentBest = bestRelease {
                if parsed > currentBest.version {
                    bestRelease = (item, parsed)
                }
            } else {
                bestRelease = (item, parsed)
            }
        }

        guard let best = bestRelease else {
            return .noReleasesFound(currentVersion: currentVersion)
        }

        guard let currentSemVer else {
            return .error(message: "Invalid local version string '\(currentVersion)'.")
        }

        guard best.version > currentSemVer else {
            return .upToDate(currentVersion: currentVersion)
        }

        guard let safeReleaseURL = Self.verifiedGitHubHTTPSURL(best.release.htmlUrl) else {
            return .error(message: "Rejected untrusted release URL in GitHub payload.")
        }

        let preferredZipAsset = best.release.assets?
            .first(where: { $0.name.lowercased().hasSuffix(".zip") })
            .flatMap { Self.verifiedGitHubHTTPSURL($0.browserDownloadUrl) }

        return .updateAvailable(
            currentVersion: currentVersion,
            latestVersion: best.version.canonicalString,
            releaseURL: safeReleaseURL,
            downloadURL: preferredZipAsset
        )
    }

    private static func makeAPIRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("SwiftEdit", forHTTPHeaderField: "User-Agent")
        return request
    }
}
