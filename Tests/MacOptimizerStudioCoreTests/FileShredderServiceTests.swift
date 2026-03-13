@testable import MacOptimizerStudioCore
import Foundation

#if canImport(Testing)
import Testing

struct FileShredderServiceTests {
    let service = FileShredderService()

    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("shredder-tests-\(UUID().uuidString)")
    }

    @Test
    func shredSingleFile() {
        let dir = tempDir()
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let filePath = dir.appendingPathComponent("secret.txt").path
        FileManager.default.createFile(atPath: filePath, contents: Data("secret data".utf8))

        let result = service.shredFile(at: filePath)
        #expect(result.success)
        #expect(result.error == nil)
        #expect(!FileManager.default.fileExists(atPath: filePath))
    }

    @Test
    func shredNonExistentFileReturnsError() {
        let result = service.shredFile(at: "/tmp/does-not-exist-\(UUID().uuidString).txt")
        #expect(!result.success)
        #expect(result.error == "File not found")
    }

    @Test
    func shredDirectoryRemovesAllFiles() {
        let dir = tempDir()
        let subDir = dir.appendingPathComponent("sub")
        try! FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        FileManager.default.createFile(atPath: dir.appendingPathComponent("a.txt").path, contents: Data("aaa".utf8))
        FileManager.default.createFile(atPath: subDir.appendingPathComponent("b.txt").path, contents: Data("bbb".utf8))

        let result = service.shredDirectory(at: dir.path) { _ in }
        #expect(result.success)
        #expect(result.errors.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: dir.path))
    }

    @Test
    func shredDoesNotAffectSiblingFiles() {
        let dir = tempDir()
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let targetPath = dir.appendingPathComponent("target.txt").path
        let siblingPath = dir.appendingPathComponent("sibling.txt").path

        FileManager.default.createFile(atPath: targetPath, contents: Data("target".utf8))
        FileManager.default.createFile(atPath: siblingPath, contents: Data("sibling".utf8))

        let result = service.shredFile(at: targetPath)
        #expect(result.success)
        #expect(!FileManager.default.fileExists(atPath: targetPath))
        #expect(FileManager.default.fileExists(atPath: siblingPath))

        let siblingContent = FileManager.default.contents(atPath: siblingPath)
        #expect(siblingContent == Data("sibling".utf8))
    }

    @Test
    func shredOverwritesOriginalContent() {
        let dir = tempDir()
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let filePath = dir.appendingPathComponent("overwrite-test.txt").path
        let original = Data("SENSITIVE CONTENT THAT MUST NOT SURVIVE".utf8)
        FileManager.default.createFile(atPath: filePath, contents: original)

        let result = service.shredFile(at: filePath)
        #expect(result.success)
        #expect(!FileManager.default.fileExists(atPath: filePath))
    }
}

#elseif canImport(XCTest)
import XCTest

final class FileShredderServiceTests: XCTestCase {
    let service = FileShredderService()

    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("shredder-tests-\(UUID().uuidString)")
    }

    func testShredSingleFile() {
        let dir = tempDir()
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let filePath = dir.appendingPathComponent("secret.txt").path
        FileManager.default.createFile(atPath: filePath, contents: Data("secret data".utf8))

        let result = service.shredFile(at: filePath)
        XCTAssertTrue(result.success)
        XCTAssertNil(result.error)
        XCTAssertFalse(FileManager.default.fileExists(atPath: filePath))
    }

    func testShredNonExistentFileReturnsError() {
        let result = service.shredFile(at: "/tmp/does-not-exist-\(UUID().uuidString).txt")
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.error, "File not found")
    }

    func testShredDoesNotAffectSiblingFiles() {
        let dir = tempDir()
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let targetPath = dir.appendingPathComponent("target.txt").path
        let siblingPath = dir.appendingPathComponent("sibling.txt").path

        FileManager.default.createFile(atPath: targetPath, contents: Data("target".utf8))
        FileManager.default.createFile(atPath: siblingPath, contents: Data("sibling".utf8))

        let result = service.shredFile(at: targetPath)
        XCTAssertTrue(result.success)
        XCTAssertFalse(FileManager.default.fileExists(atPath: targetPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: siblingPath))
    }
}

#else
struct FileShredderServiceTests {}
#endif
