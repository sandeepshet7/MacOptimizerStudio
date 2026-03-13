use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::SystemTime;

#[derive(Debug, Clone)]
struct ScanArgs {
    roots: Vec<PathBuf>,
    max_depth: usize,
    top: usize,
    json: bool,
}

#[derive(Debug, Clone)]
struct ScanReport {
    generated_at: String,
    roots: Vec<String>,
    folder_totals: Vec<FolderTotal>,
    targets: Vec<TargetEntry>,
    errors: Vec<ScanErrorEntry>,
}

#[derive(Debug, Clone)]
struct FolderTotal {
    path: String,
    size_bytes: u64,
}

#[derive(Debug, Clone)]
enum TargetKind {
    Venv,
    NodeModules,
    Git,
    Pycache,
    PytestCache,
    Target,
    Next,
    SwiftBuild,
    ElixirBuild,
    DartTool,
    Gradle,
    Terraform,
    StackWork,
    DistNewstyle,
    Vendor,
}

impl TargetKind {
    fn as_str(&self) -> &'static str {
        match self {
            Self::Venv => "venv",
            Self::NodeModules => "node_modules",
            Self::Git => "git",
            Self::Pycache => "__pycache__",
            Self::PytestCache => "pytest_cache",
            Self::Target => "target",
            Self::Next => "next",
            Self::SwiftBuild => "swift_build",
            Self::ElixirBuild => "elixir_build",
            Self::DartTool => "dart_tool",
            Self::Gradle => "gradle",
            Self::Terraform => "terraform",
            Self::StackWork => "stack_work",
            Self::DistNewstyle => "dist_newstyle",
            Self::Vendor => "vendor",
        }
    }
}

#[derive(Debug, Clone)]
struct TargetEntry {
    kind: TargetKind,
    path: String,
    size_bytes: u64,
    project_root: String,
    last_activity_epoch: Option<u64>,
}

#[derive(Debug, Clone)]
struct ScanErrorEntry {
    path: String,
    message: String,
}

#[derive(Debug)]
struct Scanner {
    max_depth: usize,
    folder_totals: Vec<FolderTotal>,
    targets: Vec<TargetEntry>,
    errors: Vec<ScanErrorEntry>,
}

impl Scanner {
    fn new(max_depth: usize) -> Self {
        Self {
            max_depth,
            folder_totals: Vec::new(),
            targets: Vec::new(),
            errors: Vec::new(),
        }
    }

    fn scan_roots(mut self, roots: &[PathBuf], top: usize) -> ScanReport {
        for root in roots {
            self.scan_path(root, 0);
        }

        self.folder_totals
            .sort_unstable_by(|a, b| b.size_bytes.cmp(&a.size_bytes).then_with(|| a.path.cmp(&b.path)));
        self.targets
            .sort_unstable_by(|a, b| b.size_bytes.cmp(&a.size_bytes).then_with(|| a.path.cmp(&b.path)));

        if self.folder_totals.len() > top {
            self.folder_totals.truncate(top);
        }

        ScanReport {
            generated_at: current_timestamp_rfc3339(),
            roots: roots.iter().map(|p| p.to_string_lossy().to_string()).collect(),
            folder_totals: self.folder_totals,
            targets: self.targets,
            errors: self.errors,
        }
    }

    fn scan_path(&mut self, path: &Path, depth: usize) -> u64 {
        let metadata = match fs::symlink_metadata(path) {
            Ok(metadata) => metadata,
            Err(err) => {
                self.record_error(path, err);
                return 0;
            }
        };

        if metadata.file_type().is_symlink() {
            return 0;
        }

        if metadata.is_file() {
            return metadata.len();
        }

        if !metadata.is_dir() {
            return 0;
        }

        if let Some(kind) = detect_target_kind(path) {
            let size = self.compute_dir_size(path);
            let project_root = path
                .parent()
                .map(|p| p.to_string_lossy().to_string())
                .unwrap_or_else(|| path.to_string_lossy().to_string());

            let last_activity = path.parent().and_then(|pr| detect_last_activity(pr));

            self.targets.push(TargetEntry {
                kind,
                path: path.to_string_lossy().to_string(),
                size_bytes: size,
                project_root,
                last_activity_epoch: last_activity,
            });

            return size;
        }

        let mut total_size = 0u64;

        let entries = match fs::read_dir(path) {
            Ok(entries) => entries,
            Err(err) => {
                self.record_error(path, err);
                return 0;
            }
        };

        for entry in entries {
            match entry {
                Ok(entry) => {
                    total_size = total_size.saturating_add(self.scan_path(&entry.path(), depth + 1));
                }
                Err(err) => {
                    self.record_error(path, err);
                }
            }
        }

        if depth <= self.max_depth {
            self.folder_totals.push(FolderTotal {
                path: path.to_string_lossy().to_string(),
                size_bytes: total_size,
            });
        }

        total_size
    }

    fn compute_dir_size(&mut self, path: &Path) -> u64 {
        let metadata = match fs::symlink_metadata(path) {
            Ok(metadata) => metadata,
            Err(err) => {
                self.record_error(path, err);
                return 0;
            }
        };

        if metadata.file_type().is_symlink() {
            return 0;
        }

        if metadata.is_file() {
            return metadata.len();
        }

        if !metadata.is_dir() {
            return 0;
        }

        let entries = match fs::read_dir(path) {
            Ok(entries) => entries,
            Err(err) => {
                self.record_error(path, err);
                return 0;
            }
        };

        let mut total_size = 0u64;
        for entry in entries {
            match entry {
                Ok(entry) => {
                    total_size = total_size.saturating_add(self.compute_dir_size(&entry.path()));
                }
                Err(err) => self.record_error(path, err),
            }
        }

        total_size
    }

    fn record_error(&mut self, path: &Path, err: std::io::Error) {
        self.errors.push(ScanErrorEntry {
            path: path.to_string_lossy().to_string(),
            message: err.to_string(),
        });
    }
}

fn detect_target_kind(path: &Path) -> Option<TargetKind> {
    let name = path.file_name()?.to_string_lossy();
    match name.as_ref() {
        ".venv" | "venv" => Some(TargetKind::Venv),
        "node_modules" => Some(TargetKind::NodeModules),
        ".git" => Some(TargetKind::Git),
        "__pycache__" => Some(TargetKind::Pycache),
        ".pytest_cache" => Some(TargetKind::PytestCache),
        "target" => detect_build_target(path),
        ".next" => Some(TargetKind::Next),
        ".build" => detect_swift_build(path),
        "_build" => Some(TargetKind::ElixirBuild),
        ".dart_tool" => Some(TargetKind::DartTool),
        ".gradle" => Some(TargetKind::Gradle),
        ".terraform" => Some(TargetKind::Terraform),
        ".stack-work" => Some(TargetKind::StackWork),
        "dist-newstyle" => Some(TargetKind::DistNewstyle),
        "vendor" => detect_vendor(path),
        _ => None,
    }
}

fn detect_build_target(path: &Path) -> Option<TargetKind> {
    let parent = path.parent()?;
    let has_cargo = parent.join("Cargo.toml").exists();
    let has_pom = parent.join("pom.xml").exists();
    let has_build_gradle = parent.join("build.gradle").exists() || parent.join("build.gradle.kts").exists();
    if has_cargo || has_pom || has_build_gradle {
        Some(TargetKind::Target)
    } else {
        None
    }
}

fn detect_swift_build(path: &Path) -> Option<TargetKind> {
    let parent = path.parent()?;
    if parent.join("Package.swift").exists() {
        Some(TargetKind::SwiftBuild)
    } else {
        None
    }
}

fn detect_last_activity(project_root: &Path) -> Option<u64> {
    let git_index = project_root.join(".git/index");
    if let Ok(meta) = fs::metadata(&git_index) {
        if let Ok(mtime) = meta.modified() {
            return mtime.duration_since(SystemTime::UNIX_EPOCH).ok().map(|d| d.as_secs());
        }
    }

    let indicators = [
        "Cargo.lock", "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
        "Pipfile.lock", "poetry.lock", "go.sum", "mix.lock", "pubspec.lock",
        "Gemfile.lock", "composer.lock", "cabal.project.freeze",
    ];

    let mut latest: Option<u64> = None;
    for name in indicators {
        let p = project_root.join(name);
        if let Ok(meta) = fs::metadata(&p) {
            if let Ok(mtime) = meta.modified() {
                if let Ok(dur) = mtime.duration_since(SystemTime::UNIX_EPOCH) {
                    let secs = dur.as_secs();
                    latest = Some(latest.map_or(secs, |prev: u64| prev.max(secs)));
                }
            }
        }
    }

    latest
}

fn detect_vendor(path: &Path) -> Option<TargetKind> {
    let parent = path.parent()?;
    let has_go_mod = parent.join("go.mod").exists();
    let has_composer = parent.join("composer.json").exists();
    let has_gemfile = parent.join("Gemfile").exists();
    if has_go_mod || has_composer || has_gemfile {
        Some(TargetKind::Vendor)
    } else {
        None
    }
}

fn parse_scan_args(args: &[String]) -> Result<ScanArgs, String> {
    let mut roots: Vec<PathBuf> = Vec::new();
    let mut max_depth: usize = 6;
    let mut top: usize = 200;
    let mut json = false;

    let mut i = 0usize;
    while i < args.len() {
        match args[i].as_str() {
            "--max-depth" => {
                i += 1;
                if i >= args.len() {
                    return Err("missing value for --max-depth".to_string());
                }
                max_depth = args[i]
                    .parse::<usize>()
                    .map_err(|_| "invalid integer for --max-depth".to_string())?;
            }
            "--top" => {
                i += 1;
                if i >= args.len() {
                    return Err("missing value for --top".to_string());
                }
                top = args[i]
                    .parse::<usize>()
                    .map_err(|_| "invalid integer for --top".to_string())?;
            }
            "--json" => {
                json = true;
            }
            "--roots" => {
                i += 1;
                while i < args.len() && !args[i].starts_with("--") {
                    roots.push(PathBuf::from(&args[i]));
                    i += 1;
                }
                i = i.saturating_sub(1);
            }
            unknown => {
                return Err(format!("unknown argument: {}", unknown));
            }
        }

        i += 1;
    }

    if roots.is_empty() {
        return Err("at least one root is required via --roots".to_string());
    }

    Ok(ScanArgs {
        roots,
        max_depth,
        top,
        json,
    })
}

fn run_scan(args: ScanArgs) {
    let report = Scanner::new(args.max_depth).scan_roots(&args.roots, args.top);

    if args.json {
        println!("{}", report_to_json(&report));
    } else {
        println!("roots: {}", report.roots.len());
        println!("folder_totals: {}", report.folder_totals.len());
        println!("targets: {}", report.targets.len());
        println!("errors: {}", report.errors.len());
    }
}

fn report_to_json(report: &ScanReport) -> String {
    let roots_json = report
        .roots
        .iter()
        .map(|r| format!("\"{}\"", escape_json(r)))
        .collect::<Vec<_>>()
        .join(",");

    let folder_totals_json = report
        .folder_totals
        .iter()
        .map(|f| {
            format!(
                "{{\"path\":\"{}\",\"size_bytes\":{}}}",
                escape_json(&f.path),
                f.size_bytes
            )
        })
        .collect::<Vec<_>>()
        .join(",");

    let targets_json = report
        .targets
        .iter()
        .map(|t| {
            let epoch_str = match t.last_activity_epoch {
                Some(e) => format!("{}", e),
                None => "null".to_string(),
            };
            format!(
                "{{\"kind\":\"{}\",\"path\":\"{}\",\"size_bytes\":{},\"project_root\":\"{}\",\"last_activity_epoch\":{}}}",
                t.kind.as_str(),
                escape_json(&t.path),
                t.size_bytes,
                escape_json(&t.project_root),
                epoch_str
            )
        })
        .collect::<Vec<_>>()
        .join(",");

    let errors_json = report
        .errors
        .iter()
        .map(|e| {
            format!(
                "{{\"path\":\"{}\",\"message\":\"{}\"}}",
                escape_json(&e.path),
                escape_json(&e.message)
            )
        })
        .collect::<Vec<_>>()
        .join(",");

    format!(
        "{{\"generated_at\":\"{}\",\"roots\":[{}],\"folder_totals\":[{}],\"targets\":[{}],\"errors\":[{}]}}",
        escape_json(&report.generated_at),
        roots_json,
        folder_totals_json,
        targets_json,
        errors_json
    )
}

fn escape_json(value: &str) -> String {
    let mut output = String::with_capacity(value.len());
    for ch in value.chars() {
        match ch {
            '\\' => output.push_str("\\\\"),
            '"' => output.push_str("\\\""),
            '\n' => output.push_str("\\n"),
            '\r' => output.push_str("\\r"),
            '\t' => output.push_str("\\t"),
            _ => output.push(ch),
        }
    }
    output
}

fn current_timestamp_rfc3339() -> String {
    let output = Command::new("date")
        .args(["-u", "+%Y-%m-%dT%H:%M:%SZ"])
        .output();

    match output {
        Ok(result) if result.status.success() => {
            let ts = String::from_utf8_lossy(&result.stdout).trim().to_string();
            if ts.is_empty() {
                "1970-01-01T00:00:00Z".to_string()
            } else {
                ts
            }
        }
        _ => "1970-01-01T00:00:00Z".to_string(),
    }
}

fn usage() {
    eprintln!("Usage: macopt-scanner scan --roots <absPath>... [--max-depth N] [--top N] [--json]");
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        usage();
        std::process::exit(1);
    }

    let command = args[1].as_str();
    match command {
        "scan" => match parse_scan_args(&args[2..]) {
            Ok(scan_args) => run_scan(scan_args),
            Err(err) => {
                eprintln!("{}", err);
                usage();
                std::process::exit(1);
            }
        },
        _ => {
            eprintln!("unknown command: {}", command);
            usage();
            std::process::exit(1);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use std::time::{SystemTime, UNIX_EPOCH};

    #[cfg(unix)]
    use std::os::unix::fs::{symlink, PermissionsExt};

    struct LocalTempDir {
        path: PathBuf,
    }

    impl LocalTempDir {
        fn new() -> Self {
            let unique = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .expect("time")
                .as_nanos();
            let path = env::temp_dir().join(format!(
                "macopt-scanner-test-{}-{}",
                std::process::id(),
                unique
            ));
            fs::create_dir_all(&path).expect("create temp dir");
            Self { path }
        }

        fn path(&self) -> &Path {
            &self.path
        }
    }

    impl Drop for LocalTempDir {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.path);
        }
    }

    fn mkfile(path: &Path, size: usize) {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).expect("create parent directories");
        }
        let mut file = fs::File::create(path).expect("create file");
        file.write_all(&vec![0_u8; size]).expect("write file");
    }

    #[test]
    fn detects_target_folders_and_sizes() {
        let temp = LocalTempDir::new();
        let root = temp.path();

        mkfile(&root.join("project-a/.venv/bin/python"), 100);
        mkfile(&root.join("project-a/src/main.py"), 40);
        mkfile(&root.join("project-a/__pycache__/mod.pyc"), 50);
        mkfile(&root.join("project-b/node_modules/lib/index.js"), 220);
        mkfile(&root.join("project-b/.git/objects/ab/cd"), 320);
        mkfile(&root.join("project-c/.next/cache/data.json"), 180);
        mkfile(&root.join("project-d/.terraform/providers/aws"), 90);
        mkfile(&root.join("project-e/Cargo.toml"), 1);
        mkfile(&root.join("project-e/target/debug/binary"), 400);

        let report = Scanner::new(6).scan_roots(&[root.to_path_buf()], 50);

        assert!(report
            .targets
            .iter()
            .any(|t| matches!(t.kind, TargetKind::Venv) && t.size_bytes == 100));
        assert!(report
            .targets
            .iter()
            .any(|t| matches!(t.kind, TargetKind::NodeModules) && t.size_bytes == 220));
        assert!(report
            .targets
            .iter()
            .any(|t| matches!(t.kind, TargetKind::Git) && t.size_bytes == 320));
        assert!(report
            .targets
            .iter()
            .any(|t| matches!(t.kind, TargetKind::Pycache)));
        assert!(report
            .targets
            .iter()
            .any(|t| matches!(t.kind, TargetKind::Next)));
        assert!(report
            .targets
            .iter()
            .any(|t| matches!(t.kind, TargetKind::Terraform)));
        assert!(report
            .targets
            .iter()
            .any(|t| matches!(t.kind, TargetKind::Target)));
    }

    #[test]
    fn prunes_target_subtrees_for_detection() {
        let temp = LocalTempDir::new();
        let root = temp.path();

        mkfile(&root.join("repo/node_modules/pkg/.git/objects/blob"), 200);

        let report = Scanner::new(6).scan_roots(&[root.to_path_buf()], 20);
        let node_modules_count = report
            .targets
            .iter()
            .filter(|t| matches!(t.kind, TargetKind::NodeModules))
            .count();
        let git_count = report
            .targets
            .iter()
            .filter(|t| matches!(t.kind, TargetKind::Git))
            .count();

        assert_eq!(node_modules_count, 1);
        assert_eq!(git_count, 0);
    }

    #[cfg(unix)]
    #[test]
    fn ignores_symlink_loops() {
        let temp = LocalTempDir::new();
        let root = temp.path();

        mkfile(&root.join("data/file.bin"), 128);
        symlink(root.join("data"), root.join("data/loop")).expect("create symlink");

        let report = Scanner::new(6).scan_roots(&[root.to_path_buf()], 20);
        assert!(report.errors.is_empty());
        assert!(report.folder_totals.iter().any(|f| f.size_bytes == 128));
    }

    #[cfg(unix)]
    #[test]
    fn reports_permission_denied_errors() {
        let temp = LocalTempDir::new();
        let root = temp.path();

        let blocked = root.join("blocked");
        fs::create_dir_all(&blocked).expect("create blocked dir");
        mkfile(&blocked.join("a.txt"), 10);

        let mut permissions = fs::metadata(&blocked).expect("metadata").permissions();
        permissions.set_mode(0o000);
        fs::set_permissions(&blocked, permissions).expect("set permissions");

        let report = Scanner::new(6).scan_roots(&[root.to_path_buf()], 20);

        let mut restore = fs::metadata(&blocked).expect("metadata restore").permissions();
        restore.set_mode(0o755);
        let _ = fs::set_permissions(&blocked, restore);

        assert!(!report.errors.is_empty());
    }

    #[test]
    fn parses_scan_args() {
        let args = vec![
            "--max-depth".to_string(),
            "3".to_string(),
            "--top".to_string(),
            "10".to_string(),
            "--json".to_string(),
            "--roots".to_string(),
            "/tmp/a".to_string(),
            "/tmp/b".to_string(),
        ];

        let parsed = parse_scan_args(&args).expect("parse");
        assert_eq!(parsed.max_depth, 3);
        assert_eq!(parsed.top, 10);
        assert!(parsed.json);
        assert_eq!(parsed.roots.len(), 2);
    }

    #[test]
    fn emits_valid_json_shape() {
        let report = ScanReport {
            generated_at: "2026-01-01T00:00:00Z".to_string(),
            roots: vec!["/tmp/root".to_string()],
            folder_totals: vec![FolderTotal {
                path: "/tmp/root/a".to_string(),
                size_bytes: 42,
            }],
            targets: vec![TargetEntry {
                kind: TargetKind::Git,
                path: "/tmp/root/repo/.git".to_string(),
                size_bytes: 7,
                project_root: "/tmp/root/repo".to_string(),
                last_activity_epoch: None,
            }],
            errors: vec![ScanErrorEntry {
                path: "/tmp/root/blocked".to_string(),
                message: "Permission denied".to_string(),
            }],
        };

        let json = report_to_json(&report);
        assert!(json.contains("\"generated_at\""));
        assert!(json.contains("\"folder_totals\""));
        assert!(json.contains("\"targets\""));
        assert!(json.contains("\"errors\""));
    }
}
