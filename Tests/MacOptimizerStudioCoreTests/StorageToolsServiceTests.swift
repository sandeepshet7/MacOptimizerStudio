@testable import MacOptimizerStudioCore
import Foundation

#if canImport(Testing)
import Testing

struct StorageToolsServiceTests {
    let service = StorageToolsService()

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("storage-tests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func createFile(in dir: URL, name: String, sizeBytes: Int) {
        let data = Data(repeating: 0x41, count: sizeBytes)
        FileManager.default.createFile(atPath: dir.appendingPathComponent(name).path, contents: data)
    }

    @Test
    func findLargeFilesAboveThreshold() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Create a 200KB file (above 100KB threshold)
        createFile(in: dir, name: "big.bin", sizeBytes: 200 * 1024)
        // Create a 50KB file (below threshold)
        createFile(in: dir, name: "small.txt", sizeBytes: 50 * 1024)

        let result = service.findLargeOldFiles(in: [dir], minSizeBytes: 100 * 1024, minAgeDays: nil) { _ in }
        #expect(result.count == 1)
        #expect(result.first?.name == "big.bin")
    }

    @Test
    func findLargeFilesIgnoresBelowThreshold() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        createFile(in: dir, name: "tiny.txt", sizeBytes: 1024)

        let result = service.findLargeOldFiles(in: [dir], minSizeBytes: 1024 * 1024, minAgeDays: nil) { _ in }
        #expect(result.isEmpty)
    }

    @Test
    func findLargeFilesEmptyDirectory() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = service.findLargeOldFiles(in: [dir], minSizeBytes: 1024, minAgeDays: nil) { _ in }
        #expect(result.isEmpty)
    }

    @Test
    func findLargeFilesSortedBySize() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        createFile(in: dir, name: "medium.bin", sizeBytes: 150 * 1024)
        createFile(in: dir, name: "large.bin", sizeBytes: 300 * 1024)
        createFile(in: dir, name: "small.bin", sizeBytes: 10 * 1024)

        let result = service.findLargeOldFiles(in: [dir], minSizeBytes: 100 * 1024, minAgeDays: nil) { _ in }
        #expect(result.count == 2)
        // Should be sorted largest first
        #expect(result.first?.sizeBytes ?? 0 >= result.last?.sizeBytes ?? 0)
    }

    @Test
    func scanFolderSizesReturnsValidStructure() {
        let dir = tempDir()
        let sub = dir.appendingPathComponent("subdir")
        try! FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        createFile(in: dir, name: "root.txt", sizeBytes: 1024)
        createFile(in: sub, name: "child.txt", sizeBytes: 2048)

        let tree = service.scanFolderSizes(at: dir, maxDepth: 3)
        #expect(tree != nil)
        #expect(tree?.name == dir.lastPathComponent)
        #expect(tree?.totalBytes ?? 0 > 0)
    }

    @Test
    func scanFolderSizesEmptyDirectory() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let tree = service.scanFolderSizes(at: dir, maxDepth: 3)
        #expect(tree != nil)
        #expect(tree?.totalBytes == 0)
    }
}

#elseif canImport(XCTest)
import XCTest

final class StorageToolsServiceTests: XCTestCase {
    let service = StorageToolsService()

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("storage-tests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func createFile(in dir: URL, name: String, sizeBytes: Int) {
        let data = Data(repeating: 0x41, count: sizeBytes)
        FileManager.default.createFile(atPath: dir.appendingPathComponent(name).path, contents: data)
    }

    func testFindLargeFilesAboveThreshold() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        createFile(in: dir, name: "big.bin", sizeBytes: 200 * 1024)
        createFile(in: dir, name: "small.txt", sizeBytes: 50 * 1024)

        let result = service.findLargeOldFiles(in: [dir], minSizeBytes: 100 * 1024, minAgeDays: nil) { _ in }
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "big.bin")
    }

    func testFindLargeFilesEmptyDirectory() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = service.findLargeOldFiles(in: [dir], minSizeBytes: 1024, minAgeDays: nil) { _ in }
        XCTAssertTrue(result.isEmpty)
    }
}

#else
struct StorageToolsServiceTests {}
#endif
