@testable import MacOptimizerStudioCore
import Foundation

#if canImport(Testing)
import Testing

struct BrokenDownloadsServiceTests {
    let service = BrokenDownloadsService()

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("broken-dl-tests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func createOldFile(at path: String, content: String = "data") {
        FileManager.default.createFile(atPath: path, contents: Data(content.utf8))
        // Set modification date to 2 hours ago so it passes the 1-hour threshold
        let twoHoursAgo = Date().addingTimeInterval(-7200)
        try? FileManager.default.setAttributes([.modificationDate: twoHoursAgo], ofItemAtPath: path)
    }

    @Test
    func detectsCrdownloadFiles() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        createOldFile(at: dir.appendingPathComponent("file.crdownload").path)

        let result = service.scan(paths: [dir])
        #expect(result.files.count == 1)
        #expect(result.files.first?.downloadType == .crdownload)
    }

    @Test
    func detectsPartFiles() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        createOldFile(at: dir.appendingPathComponent("video.part").path)

        let result = service.scan(paths: [dir])
        #expect(result.files.count == 1)
        #expect(result.files.first?.downloadType == .part)
    }

    @Test
    func detectsMultipleExtensions() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        createOldFile(at: dir.appendingPathComponent("a.download").path)
        createOldFile(at: dir.appendingPathComponent("b.tmp").path)
        createOldFile(at: dir.appendingPathComponent("c.partial").path)
        createOldFile(at: dir.appendingPathComponent("d.opdownload").path)

        let result = service.scan(paths: [dir])
        #expect(result.files.count == 4)
    }

    @Test
    func ignoresNormalFiles() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        createOldFile(at: dir.appendingPathComponent("document.pdf").path)
        createOldFile(at: dir.appendingPathComponent("image.jpg").path)
        createOldFile(at: dir.appendingPathComponent("archive.zip").path)
        createOldFile(at: dir.appendingPathComponent("readme.txt").path)

        let result = service.scan(paths: [dir])
        #expect(result.files.isEmpty)
    }

    @Test
    func respectsAgeThreshold() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // This file is brand new — should be EXCLUDED (might still be downloading)
        let freshPath = dir.appendingPathComponent("fresh.crdownload").path
        FileManager.default.createFile(atPath: freshPath, contents: Data("new".utf8))
        // Don't set old date — it stays as "just created"

        // This file is old — should be INCLUDED
        createOldFile(at: dir.appendingPathComponent("old.crdownload").path)

        let result = service.scan(paths: [dir])
        #expect(result.files.count == 1)
        #expect(result.files.first?.name == "old.crdownload")
    }

    @Test
    func calculatesCorrectTotalBytes() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        createOldFile(at: dir.appendingPathComponent("a.crdownload").path, content: "12345") // 5 bytes
        createOldFile(at: dir.appendingPathComponent("b.part").path, content: "123456789") // 9 bytes

        let result = service.scan(paths: [dir])
        #expect(result.files.count == 2)
        #expect(result.totalBytes == result.files.reduce(0 as UInt64) { $0 + $1.sizeBytes })
    }

    @Test
    func emptyDirectoryReturnsEmptyResult() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = service.scan(paths: [dir])
        #expect(result.files.isEmpty)
        #expect(result.totalBytes == 0)
    }

    @Test
    func nonExistentDirectoryReturnsEmptyResult() {
        let fake = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString)")
        let result = service.scan(paths: [fake])
        #expect(result.files.isEmpty)
    }
}

#elseif canImport(XCTest)
import XCTest

final class BrokenDownloadsServiceTests: XCTestCase {
    let service = BrokenDownloadsService()

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("broken-dl-tests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func createOldFile(at path: String) {
        FileManager.default.createFile(atPath: path, contents: Data("data".utf8))
        let twoHoursAgo = Date().addingTimeInterval(-7200)
        try? FileManager.default.setAttributes([.modificationDate: twoHoursAgo], ofItemAtPath: path)
    }

    func testIgnoresNormalFiles() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        createOldFile(at: dir.appendingPathComponent("document.pdf").path)
        let result = service.scan(paths: [dir])
        XCTAssertTrue(result.files.isEmpty)
    }

    func testDetectsCrdownload() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        createOldFile(at: dir.appendingPathComponent("file.crdownload").path)
        let result = service.scan(paths: [dir])
        XCTAssertEqual(result.files.count, 1)
    }

    func testRespectsAgeThreshold() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Fresh file — should be excluded
        FileManager.default.createFile(atPath: dir.appendingPathComponent("fresh.crdownload").path, contents: Data("new".utf8))
        // Old file — should be included
        createOldFile(at: dir.appendingPathComponent("old.crdownload").path)

        let result = service.scan(paths: [dir])
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files.first?.name, "old.crdownload")
    }
}

#else
struct BrokenDownloadsServiceTests {}
#endif
