import Foundation

/// Structural fitness checks for the change-017 audit reports (`REQ-001`, `REQ-002`, `REQ-011`, `TEST-005`).
///
/// Report contract (Markdown):
/// - `## Runs` table with one row per run whose first cell is `R1`, `R2`, `R3`, ...;
/// - the six sections `## CPU`, `## Memory`, `## Latency`, `## Functional`, `## Human Metrics`, `## Accessibility`;
/// - `## Findings` table rows `| F-017-NN | P0..P3 | title | repro | measured | status |` where status is `open`,
///   `backlog` or `resolved: <testFunctionName>`;
/// - no line may contain the synthetic fixture marker (document contents must never leak into reports, `SEC-011`).
enum AuditReportFitness {
    static let requiredSections = ["CPU", "Memory", "Latency", "Functional", "Human Metrics", "Accessibility"]
    static let fixtureMarker = "QA-FIXTURE-BODY"

    struct Finding: Equatable {
        let id: String
        let severity: String
        let repro: String
        let measured: String
        let status: String
    }

    static func runCount(_ report: String) -> Int {
        table(after: "## Runs", in: report).filter { $0.first?.hasPrefix("R") == true && Int($0.first!.dropFirst()) != nil }.count
    }

    static func findings(_ report: String) -> [Finding] {
        table(after: "## Findings", in: report).compactMap { cells in
            guard cells.count >= 6, cells[0].hasPrefix("F-017-") else { return nil }
            return Finding(id: cells[0], severity: cells[1], repro: cells[3], measured: cells[4], status: cells[5])
        }
    }

    /// Structural issues of a baseline or verification report (empty when valid).
    static func structuralIssues(_ report: String, minimumRuns: Int = 3) -> [String] {
        var issues: [String] = []
        let runs = runCount(report)
        if runs < minimumRuns { issues.append("runs: expected \(minimumRuns), found \(runs)") }
        for section in requiredSections where !report.components(separatedBy: "\n").contains("## \(section)") {
            issues.append("missing section: \(section)")
        }
        for finding in findings(report) {
            if !["P0", "P1", "P2", "P3"].contains(finding.severity) { issues.append("\(finding.id): invalid severity \(finding.severity)") }
            if finding.repro.isEmpty || finding.measured.isEmpty { issues.append("\(finding.id): missing repro or measured value") }
        }
        for (number, line) in report.components(separatedBy: "\n").enumerated() where line.contains(fixtureMarker) {
            issues.append("leaked fixture content at line \(number + 1)")
        }
        return issues
    }

    /// Remediation issues: P0-P2 findings must be `resolved: <test>` with an existing test function; P3 must be `backlog`.
    static func remediationIssues(_ report: String, testSources: String) -> [String] {
        var issues: [String] = []
        for finding in findings(report) {
            if finding.severity == "P3" {
                if finding.status != "backlog", !finding.status.hasPrefix("resolved:") { issues.append("\(finding.id): P3 must be backlog or resolved") }
                continue
            }
            guard finding.status.hasPrefix("resolved:") else { issues.append("\(finding.id): \(finding.severity) is \(finding.status)"); continue }
            let testName = finding.status.dropFirst("resolved:".count).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            if testName.isEmpty || !testSources.contains("func \(testName)(") { issues.append("\(finding.id): regression test '\(testName)' not found") }
        }
        return issues
    }

    /// Rows of `## Comparison` (`| metric | baseline | final | delta % |`) whose final value is more than 10% worse
    /// (higher) than baseline; lower-is-better metrics only (`REQ-011`, `N12`).
    static func regressions(_ report: String) -> [String] {
        table(after: "## Comparison", in: report).compactMap { cells in
            guard cells.count >= 4, cells[0] != "Metric", let base = Double(cells[1]), let final = Double(cells[2]), base > 0 else { return nil }
            return final > base * 1.10 ? "\(cells[0]): \(cells[1]) -> \(cells[2])" : nil
        }
    }

    /// Findings of severity P0–P2 not marked resolved.
    static func openSevereFindings(_ report: String) -> [String] {
        findings(report).filter { ["P0", "P1", "P2"].contains($0.severity) && !$0.status.hasPrefix("resolved:") }.map(\.id)
    }

    private static func table(after heading: String, in report: String) -> [[String]] {
        let lines = report.components(separatedBy: "\n")
        guard let start = lines.firstIndex(of: heading) else { return [] }
        var rows: [[String]] = []
        for line in lines[(start + 1)...] {
            if line.hasPrefix("## ") { break }
            guard line.hasPrefix("|") else { continue }
            let cells = line.split(separator: "|", omittingEmptySubsequences: false).dropFirst().dropLast().map { $0.trimmingCharacters(in: .whitespaces) }
            if cells.first?.hasPrefix(":---") == true || cells.first == "Run" || cells.first == "ID" || cells.first == "Metric" { continue }
            rows.append(Array(cells))
        }
        return rows
    }

    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    static func read(_ relativePath: String) -> String {
        (try? String(contentsOf: repositoryRoot.appendingPathComponent(relativePath), encoding: .utf8)) ?? ""
    }
}
