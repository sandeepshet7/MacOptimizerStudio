import Foundation
import MacOptimizerStudioCore

enum SelfCheckFailure: Error, CustomStringConvertible {
    case assertion(String)

    var description: String {
        switch self {
        case .assertion(let message):
            return message
        }
    }
}

@inline(__always)
func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw SelfCheckFailure.assertion(message)
    }
}

func runChecks() throws {
    let json = """
    {
      "generated_at": "2026-02-27T18:30:00Z",
      "roots": ["/Users/test/work"],
      "folder_totals": [
        {"path": "/Users/test/work/proj", "size_bytes": 12345}
      ],
      "targets": [
        {
          "kind": "node_modules",
          "path": "/Users/test/work/proj/node_modules",
          "size_bytes": 999,
          "project_root": "/Users/test/work/proj"
        }
      ],
      "errors": [
        {"path": "/Users/test/work/blocked", "message": "Permission denied"}
      ]
    }
    """

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let report = try decoder.decode(ScanReport.self, from: Data(json.utf8))
    try check(report.folderTotals.count == 1, "ScanReport decode failed")
    try check(report.targets.first?.kind == .nodeModules, "Target kind mapping failed")

    let gitEntry = TargetEntry(
        kind: .git,
        path: "/Users/test/repo/.git",
        sizeBytes: 100,
        projectRoot: "/Users/test/repo"
    )
    let gitCommands = CleanupCommandFactory().commands(for: gitEntry)
    let delete = gitCommands.first { $0.title.contains("Delete .git") }
    try check(delete?.riskLevel == .danger, "Git delete risk level is incorrect")
    try check(delete?.requiresWarning == true, "Git delete should be warning-gated")

    let escaped = ShellEscaper.quote("/Users/test/O'Reilly/repo")
    try check(escaped == "'/Users/test/O'\"'\"'Reilly/repo'", "Shell escaping failed")
}

do {
    try runChecks()
    print("MacOptimizerStudioCore self-check passed")
} catch {
    fputs("Self-check failed: \(error)\n", stderr)
    exit(1)
}
