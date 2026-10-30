import XCTest
@testable import CameraApp

/// Basic tests for CameraApp types. From-scratch implementation.
final class CameraAppTests: XCTestCase {
    func testStyleTitles() {
        XCTAssertEqual(CameraStyle.natural.title, "Natural")
        XCTAssertEqual(CameraStyle.xiaomi.title, "Xiaomi")
        XCTAssertEqual(CameraStyle.oppo.title, "Oppo")
        XCTAssertEqual(CameraStyle.vivo.title, "Vivo")
    }

    func testStyleInitials() {
        XCTAssertEqual(CameraStyle.natural.initials, "N")
        XCTAssertEqual(CameraStyle.xiaomi.initials, "X")
        XCTAssertEqual(CameraStyle.oppo.initials, "O")
        XCTAssertEqual(CameraStyle.vivo.initials, "V")
    }

    func testLensTitles() {
        XCTAssertEqual(CameraLens.ultraWide.title, "0.5×")
        XCTAssertEqual(CameraLens.wide.title, "1×")
        XCTAssertEqual(CameraLens.telephoto.title, "2×")
    }

    func testFlashModes() {
        XCTAssertEqual(FlashMode.allCases.count, 3)
        XCTAssertEqual(FlashMode.off.title, "\u{26A1}\u{20E5}")
        XCTAssertEqual(FlashMode.on.title, "\u{26A1}")
        XCTAssertEqual(FlashMode.auto.title, "\u{26A1}\u{00A0}A")
    }
}
