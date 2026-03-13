import Foundation

public enum TargetCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case dependencies
    case buildOutput
    case cache
    case vcs

    public var displayName: String {
        switch self {
        case .dependencies: return "Dependencies"
        case .buildOutput: return "Build Output"
        case .cache: return "Caches"
        case .vcs: return "Version Control"
        }
    }

    public var icon: String {
        switch self {
        case .dependencies: return "shippingbox.fill"
        case .buildOutput: return "hammer.fill"
        case .cache: return "memorychip.fill"
        case .vcs: return "point.3.connected.trianglepath.dotted"
        }
    }

    public var tint: String {
        switch self {
        case .dependencies: return "blue"
        case .buildOutput: return "orange"
        case .cache: return "purple"
        case .vcs: return "green"
        }
    }
}

public enum TargetKind: String, Codable, CaseIterable, Hashable, Sendable {
    case venv
    case nodeModules = "node_modules"
    case git
    case pycache = "__pycache__"
    case pytestCache = "pytest_cache"
    case target
    case next
    case swiftBuild = "swift_build"
    case elixirBuild = "elixir_build"
    case dartTool = "dart_tool"
    case gradle
    case terraform
    case stackWork = "stack_work"
    case distNewstyle = "dist_newstyle"
    case vendor

    public var displayName: String {
        switch self {
        case .venv: return ".venv"
        case .nodeModules: return "node_modules"
        case .git: return ".git"
        case .pycache: return "__pycache__"
        case .pytestCache: return ".pytest_cache"
        case .target: return "target"
        case .next: return ".next"
        case .swiftBuild: return ".build"
        case .elixirBuild: return "_build"
        case .dartTool: return ".dart_tool"
        case .gradle: return ".gradle"
        case .terraform: return ".terraform"
        case .stackWork: return ".stack-work"
        case .distNewstyle: return "dist-newstyle"
        case .vendor: return "vendor"
        }
    }

    public var folderName: String { displayName }

    public var category: TargetCategory {
        switch self {
        case .venv, .nodeModules, .vendor:
            return .dependencies
        case .target, .next, .swiftBuild, .elixirBuild, .distNewstyle:
            return .buildOutput
        case .pycache, .pytestCache, .dartTool, .gradle, .terraform, .stackWork:
            return .cache
        case .git:
            return .vcs
        }
    }

    public var ecosystem: String {
        switch self {
        case .venv: return "Python"
        case .nodeModules: return "Node.js"
        case .git: return "Git"
        case .pycache: return "Python"
        case .pytestCache: return "Python"
        case .target: return "Java / Rust"
        case .next: return "Next.js"
        case .swiftBuild: return "Swift"
        case .elixirBuild: return "Elixir"
        case .dartTool: return "Dart / Flutter"
        case .gradle: return "Gradle"
        case .terraform: return "Terraform"
        case .stackWork: return "Haskell"
        case .distNewstyle: return "Haskell"
        case .vendor: return "Go / PHP / Ruby"
        }
    }

    public var restoreHint: String {
        switch self {
        case .venv: return "python -m venv .venv && pip install -r requirements.txt"
        case .nodeModules: return "npm install  (or yarn / pnpm install)"
        case .git: return "git clone <remote-url>"
        case .pycache: return "Regenerated automatically on next import"
        case .pytestCache: return "Regenerated automatically on next test run"
        case .target: return "cargo build  or  mvn compile"
        case .next: return "next build"
        case .swiftBuild: return "swift build"
        case .elixirBuild: return "mix compile"
        case .dartTool: return "dart pub get"
        case .gradle: return "gradle build"
        case .terraform: return "terraform init"
        case .stackWork: return "stack build"
        case .distNewstyle: return "cabal build"
        case .vendor: return "go mod vendor  /  composer install  /  bundle install"
        }
    }

    public static func kinds(for category: TargetCategory) -> [TargetKind] {
        allCases.filter { $0.category == category }
    }
}

public struct FolderTotal: Codable, Identifiable, Hashable, Sendable {
    public var id: String { path }
    public let path: String
    public let sizeBytes: UInt64

    enum CodingKeys: String, CodingKey {
        case path
        case sizeBytes = "size_bytes"
    }

    public init(path: String, sizeBytes: UInt64) {
        self.path = path
        self.sizeBytes = sizeBytes
    }
}

public struct TargetEntry: Codable, Identifiable, Hashable, Sendable {
    public var id: String { path }
    public let kind: TargetKind
    public let path: String
    public let sizeBytes: UInt64
    public let projectRoot: String
    public let lastActivityEpoch: UInt64?

    enum CodingKeys: String, CodingKey {
        case kind
        case path
        case sizeBytes = "size_bytes"
        case projectRoot = "project_root"
        case lastActivityEpoch = "last_activity_epoch"
    }

    public init(kind: TargetKind, path: String, sizeBytes: UInt64, projectRoot: String, lastActivityEpoch: UInt64? = nil) {
        self.kind = kind
        self.path = path
        self.sizeBytes = sizeBytes
        self.projectRoot = projectRoot
        self.lastActivityEpoch = lastActivityEpoch
    }

    public var lastActivityDate: Date? {
        guard let epoch = lastActivityEpoch else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(epoch))
    }

    public var inactiveDays: Int? {
        guard let lastDate = lastActivityDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day
    }

    public var stalenessLabel: String? {
        guard let days = inactiveDays else { return nil }
        if days < 7 { return nil }
        if days < 30 { return "\(days)d inactive" }
        let months = days / 30
        if months < 12 { return "\(months)mo inactive" }
        let years = months / 12
        return "\(years)y inactive"
    }

    public var isStale: Bool {
        guard let days = inactiveDays else { return false }
        return days >= 30
    }
}

public struct ScanErrorEntry: Codable, Identifiable, Hashable, Sendable {
    public var id: String { "\(path)::\(message)" }
    public let path: String
    public let message: String

    public init(path: String, message: String) {
        self.path = path
        self.message = message
    }
}

public struct ScanReport: Codable, Sendable {
    public let generatedAt: Date
    public let roots: [String]
    public let folderTotals: [FolderTotal]
    public let targets: [TargetEntry]
    public let errors: [ScanErrorEntry]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case roots
        case folderTotals = "folder_totals"
        case targets
        case errors
    }

    public init(generatedAt: Date, roots: [String], folderTotals: [FolderTotal], targets: [TargetEntry], errors: [ScanErrorEntry]) {
        self.generatedAt = generatedAt
        self.roots = roots
        self.folderTotals = folderTotals
        self.targets = targets
        self.errors = errors
    }
}
