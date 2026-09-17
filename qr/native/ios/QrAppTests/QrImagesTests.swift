import XCTest

@testable import QrNativeApp

final class QrImagesTests: XCTestCase {
  func testPayloadPadsTheIndexToThreeDigits() {
    XCTAssertEqual(expectedPayload(0), "https://example.com/benchmark/qr/000")
    XCTAssertEqual(expectedPayload(7), "https://example.com/benchmark/qr/007")
    XCTAssertEqual(expectedPayload(499), "https://example.com/benchmark/qr/499")
  }
}
