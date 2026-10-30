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

    func testFlashToggleCycles() {
        var mode: FlashMode = .off
        mode = (mode == .off) ? .on : (mode == .on) ? .auto : .off
        XCTAssertEqual(mode, .on)
        mode = (mode == .off) ? .on : (mode == .on) ? .auto : .off
        XCTAssertEqual(mode, .auto)
        mode = (mode == .off) ? .on : (mode == .on) ? .auto : .off
        XCTAssertEqual(mode, .off)
    }

    func testStyleSwitching() {
        var style: CameraStyle = .natural
        XCTAssertEqual(style.title, "Natural")
        style = .xiaomi
        XCTAssertEqual(style.title, "Xiaomi")
        style = .oppo
        XCTAssertEqual(style.title, "Oppo")
        style = .vivo
        XCTAssertEqual(style.title, "Vivo")
    }

    func testLensSwitching() {
        var lens: CameraLens = .wide
        XCTAssertEqual(lens.title, "1×")
        lens = .ultraWide
        XCTAssertEqual(lens.title, "0.5×")
        lens = .telephoto
        XCTAssertEqual(lens.title, "2×")
    }

    func testDefaultSettings() {
        XCTAssertEqual(CameraLens.allCases.count, 3)
        XCTAssertEqual(CameraStyle.allCases.count, 4)
        XCTAssertEqual(FlashMode.allCases.count, 3)
    }

    func testStyleAccentColorsAreNonNil() {
        for style in CameraStyle.allCases {
            XCTAssertNotNil(style.accentColor)
        }
    }

    func testLensIconsAreNonEmpty() {
        for lens in CameraLens.allCases {
            XCTAssertFalse(lens.icon.isEmpty)
        }
    }
}
