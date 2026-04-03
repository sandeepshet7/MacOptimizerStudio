import Foundation

public struct CleanupCommandFactory {
    public init() {}

    private var trashDir: String {
        "~/.Trash/MacOptimizerStudio-$(date +%Y%m%d-%H%M%S)"
    }

    public func commands(for entry: TargetEntry) -> [CleanupCommand] {
        var cmds: [CleanupCommand] = []

        switch entry.kind {
        case .git:
            cmds.append(contentsOf: [
                CleanupCommand(
                    title: "Optimize Repository (git gc)",
                    riskLevel: .safe,
                    command: "git -C \(ShellEscaper.quote(entry.projectRoot)) gc --aggressive --prune=now",
                    requiresWarning: false
                ),
                CleanupCommand(
                    title: "Optimize Repository (git repack)",
                    riskLevel: .safe,
                    command: "git -C \(ShellEscaper.quote(entry.projectRoot)) repack -a -d --depth=250 --window=250",
                    requiresWarning: false
                ),
                CleanupCommand(
                    title: "Backup as Bundle",
                    riskLevel: .safe,
                    command: "git -C \(ShellEscaper.quote(entry.projectRoot)) bundle create \(ShellEscaper.quote(entry.projectRoot + "/repo-backup.bundle")) --all",
                    requiresWarning: false
                ),
                CleanupCommand(
                    title: "Delete .git (Danger)",
                    riskLevel: .danger,
                    command: "mkdir -p \(trashDir) && mv \(ShellEscaper.quote(entry.path)) \(trashDir)/",
                    requiresWarning: true
                ),
            ])
        default:
            if let optimize = optimizeCommand(for: entry) {
                cmds.append(optimize)
            }
            let dest = trashDir
            cmds.append(contentsOf: [
                CleanupCommand(
                    title: "Move to Trash",
                    riskLevel: .safe,
                    command: "mkdir -p \(dest) && mv \(ShellEscaper.quote(entry.path)) \(dest)/",
                    requiresWarning: false
                ),
            ])
        }

        return cmds
    }

    public func optimizeCommand(for entry: TargetEntry) -> CleanupCommand? {
        let root = ShellEscaper.quote(entry.projectRoot)
        switch entry.kind {
        case .nodeModules:
            return CleanupCommand(
                title: "npm prune",
                riskLevel: .safe,
                command: "cd \(root) && npm prune",
                requiresWarning: false
            )
        case .venv:
            return CleanupCommand(
                title: "pip cache purge",
                riskLevel: .safe,
                command: "cd \(root) && pip cache purge",
                requiresWarning: false
            )
        case .target:
            return CleanupCommand(
                title: "cargo clean --doc",
                riskLevel: .safe,
                command: "cd \(root) && cargo clean --doc 2>/dev/null || true",
                requiresWarning: false
            )
        case .swiftBuild:
            return CleanupCommand(
                title: "swift package clean",
                riskLevel: .safe,
                command: "cd \(root) && swift package clean",
                requiresWarning: false
            )
        case .gradle:
            return CleanupCommand(
                title: "gradle --stop",
                riskLevel: .safe,
                command: "cd \(root) && gradle --stop 2>/dev/null || true",
                requiresWarning: false
            )
        case .next:
            return CleanupCommand(
                title: "Clear .next cache only",
                riskLevel: .safe,
                command: "mkdir -p \(trashDir) && mv \(ShellEscaper.quote(entry.path))/cache \(trashDir)/",
                requiresWarning: false
            )
        case .terraform:
            return CleanupCommand(
                title: "terraform init -upgrade",
                riskLevel: .safe,
                command: "cd \(root) && terraform init -upgrade",
                requiresWarning: false
            )
        default:
            return nil
        }
    }

    public func findCommand(roots: [String], kind: TargetKind) -> String {
        let quoted = roots.map { ShellEscaper.quote($0) }.joined(separator: " ")
        return "find \(quoted) -type d -name \(ShellEscaper.quote(kind.folderName))"
    }

    public func safeTrashCommand(roots: [String], kind: TargetKind) -> String {
        let quoted = roots.map { ShellEscaper.quote($0) }.joined(separator: " ")
        let dest = trashDir
        return "mkdir -p \(dest) && find \(quoted) -type d -name \(ShellEscaper.quote(kind.folderName)) -prune -exec mv {} \(dest)/ \\;"
    }

    public func hardDeleteCommand(roots: [String], kind: TargetKind) -> String {
        return safeTrashCommand(roots: roots, kind: kind)
    }

    public func optimizeGitCommand(roots: [String]) -> String {
        let quoted = roots.map { ShellEscaper.quote($0) }.joined(separator: " ")
        return #"find \#(quoted) -type d -name '.git' -prune -exec sh -c 'git -C "$(dirname "$1")" gc --aggressive --prune=now' _ {} \;"#
    }

    public func safeBundleCommand(roots: [String], kinds: [TargetKind], entries: [TargetKind: [TargetEntry]]) -> String {
        let dest = trashDir
        var lines: [String] = ["mkdir -p \(dest)"]
        for kind in kinds {
            guard let kindEntries = entries[kind], !kindEntries.isEmpty else { continue }
            if kind == .git {
                lines.append(optimizeGitCommand(roots: roots))
            } else {
                for entry in kindEntries.prefix(30) {
                    lines.append("mv \(ShellEscaper.quote(entry.path)) \(dest)/")
                }
            }
        }
        return lines.count <= 1 ? "# No cleanup targets found" : lines.joined(separator: "\n")
    }
}
