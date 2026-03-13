import Foundation
@testable import MacOptimizerStudioCore

#if canImport(Testing)
import Testing

struct ScanReportDecodingTests {
    @Test
    func decodesRustScanReportJSON() throws {
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

        #expect(report.roots.count == 1)
        #expect(report.folderTotals.count == 1)
        #expect(report.targets.first?.kind == .nodeModules)
        #expect(report.errors.count == 1)
    }
}

#elseif canImport(XCTest)
import XCTest

final class ScanReportDecodingTests: XCTestCase {
    func testDecodesRustScanReportJSON() throws {
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

        XCTAssertEqual(report.roots.count, 1)
        XCTAssertEqual(report.folderTotals.count, 1)
        XCTAssertEqual(report.targets.first?.kind, .nodeModules)
        XCTAssertEqual(report.errors.count, 1)
    }
}

#else
struct ScanReportDecodingTests {}
#endif
