import Foundation
@testable import MacOptimizerStudioCore

#if canImport(Testing)
import Testing

struct ByteFormattingTests {
    @Test
    func zeroBytes() {
        let result = ByteFormatting.string(0)
        #expect(!result.isEmpty)
    }

    @Test
    func kilobytes() {
        let result = ByteFormatting.string(1_500)
        #expect(result.contains("KB"))
    }

    @Test
    func megabytes() {
        let result = ByteFormatting.string(5_000_000)
        #expect(result.contains("MB"))
    }

    @Test
    func gigabytes() {
        let result = ByteFormatting.string(2_500_000_000)
        #expect(result.contains("GB"))
    }

    @Test
    func terabytes() {
        let result = ByteFormatting.string(2_000_000_000_000)
        #expect(result.contains("TB"))
    }

    @Test
    func memoryStringMB() {
        let result = ByteFormatting.memoryString(500_000_000)
        // memoryString uses .memory countStyle, so it may differ from .file
        #expect(!result.isEmpty)
        #expect(result.contains("MB") || result.contains("GB"))
    }

    @Test
    func memoryStringGB() {
        let result = ByteFormatting.memoryString(8_000_000_000)
        #expect(result.contains("GB"))
    }
}

#elseif canImport(XCTest)
import XCTest

final class ByteFormattingTests: XCTestCase {
    func testZeroBytes() {
        let result = ByteFormatting.string(0)
        XCTAssertFalse(result.isEmpty)
    }

    func testKilobytes() {
        let result = ByteFormatting.string(1_500)
        XCTAssertTrue(result.contains("KB"))
    }

    func testMegabytes() {
        let result = ByteFormatting.string(5_000_000)
        XCTAssertTrue(result.contains("MB"))
    }

    func testGigabytes() {
        let result = ByteFormatting.string(2_500_000_000)
        XCTAssertTrue(result.contains("GB"))
    }

    func testTerabytes() {
        let result = ByteFormatting.string(2_000_000_000_000)
        XCTAssertTrue(result.contains("TB"))
    }

    func testMemoryStringMB() {
        let result = ByteFormatting.memoryString(500_000_000)
        XCTAssertFalse(result.isEmpty)
    }

    func testMemoryStringGB() {
        let result = ByteFormatting.memoryString(8_000_000_000)
        XCTAssertTrue(result.contains("GB"))
    }
}

#else
struct ByteFormattingTests {}
#endif
