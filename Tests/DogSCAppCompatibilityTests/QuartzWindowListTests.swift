import CoreFoundation
import CoreGraphics
import XCTest
@testable import DogSCApp

final class QuartzWindowListTests: XCTestCase {
    func testQuartzReceivesRawWindowIDsInsteadOfObjectAddresses() {
        let array = VenturaQuartzWindowList.makeArray(windowIDs: [42, 1001])
        XCTAssertEqual(CFArrayGetCount(array), 2)
        XCTAssertEqual(Int(bitPattern: CFArrayGetValueAtIndex(array, 0)), 42)
        XCTAssertEqual(Int(bitPattern: CFArrayGetValueAtIndex(array, 1)), 1001)
    }

    func testNullWindowIDIsNotPassedToTheCaptureAPI() {
        let array = VenturaQuartzWindowList.makeArray(windowIDs: [0, 42])
        XCTAssertEqual(CFArrayGetCount(array), 1)
        XCTAssertEqual(Int(bitPattern: CFArrayGetValueAtIndex(array, 0)), 42)
    }
}
