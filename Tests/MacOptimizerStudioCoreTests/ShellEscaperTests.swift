@testable import MacOptimizerStudioCore

#if canImport(Testing)
import Testing

struct ShellEscaperTests {
    @Test
    func escapesSingleQuotes() {
        let escaped = ShellEscaper.quote("/Users/test/O'Reilly/repo")
        #expect(escaped == "'/Users/test/O'\"'\"'Reilly/repo'")
    }
}

#elseif canImport(XCTest)
import XCTest

final class ShellEscaperTests: XCTestCase {
    func testEscapesSingleQuotes() {
        let escaped = ShellEscaper.quote("/Users/test/O'Reilly/repo")
        XCTAssertEqual(escaped, "'/Users/test/O'\"'\"'Reilly/repo'")
    }
}

#else
struct ShellEscaperTests {}
#endif
