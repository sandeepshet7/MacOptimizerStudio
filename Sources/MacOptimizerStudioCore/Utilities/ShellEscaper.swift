import Foundation

public enum ShellEscaper {
    public static func quote(_ path: String) -> String {
        if path.isEmpty {
            return "''"
        }
        return "'" + path.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}
