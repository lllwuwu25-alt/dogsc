import Foundation
import XCTest
@testable import RecorderCore

final class CompatibilityTests: XCTestCase {
    func testRetinaAndScaledDisplaySizes() {
        XCTAssertEqual(LegacyCaptureGeometry.pixelScale(logicalWidth: 1280, pixelWidth: 2560), 2)
        XCTAssertEqual(LegacyCaptureGeometry.pixelScale(logicalWidth: 1920, pixelWidth: 2880), 1.5)
        let size = LegacyCaptureGeometry.pixelSize(logicalSize: CGSize(width: 400, height: 250), scale: 2)
        XCTAssertEqual(size.width, 800)
        XCTAssertEqual(size.height, 500)
    }

    func testInvalidScaleCannotProduceInvalidDimensions() {
        XCTAssertEqual(LegacyCaptureGeometry.pixelScale(logicalWidth: 0, pixelWidth: 0), 1)
        XCTAssertEqual(LegacyCaptureGeometry.pixelScale(logicalWidth: .nan, pixelWidth: 2560), 1)
        let size = LegacyCaptureGeometry.pixelSize(logicalSize: .zero, scale: .infinity)
        XCTAssertEqual(size.width, 2)
        XCTAssertEqual(size.height, 2)
    }

    func testWindowUsesDisplayWithLargestIntersection() {
        let displays = [
            LegacyCaptureGeometry.Display(frame: CGRect(x: 0, y: 0, width: 1440, height: 900), scale: 2),
            LegacyCaptureGeometry.Display(frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080), scale: 1),
        ]
        XCTAssertEqual(LegacyCaptureGeometry.windowScale(frame: CGRect(x: 1500, y: 50, width: 700, height: 400), displays: displays), 1)
        XCTAssertEqual(LegacyCaptureGeometry.windowScale(frame: CGRect(x: 1100, y: 50, width: 400, height: 400), displays: displays), 2)
    }

    func testSpringStartsAtCurrentPositionAndVelocityAndSettles() {
        let spring = CompatibilitySpring(response: 0.5, dampingRatio: 0.82)
        XCTAssertEqual(spring.value(target: 200, initialVelocity: 12, time: 0), 0, accuracy: 0.000001)
        XCTAssertEqual(spring.velocity(target: 200, initialVelocity: 12, time: 0), 12, accuracy: 0.000001)
        XCTAssertEqual(spring.value(target: 200, initialVelocity: 12, time: spring.settlingDuration), 200, accuracy: 0.1)
        let t = 0.14, dt = 0.000001
        let numerical = (spring.value(target: 200, initialVelocity: 12, time: t + dt) - spring.value(target: 200, initialVelocity: 12, time: t - dt)) / (2 * dt)
        XCTAssertEqual(spring.velocity(target: 200, initialVelocity: 12, time: t), numerical, accuracy: 0.0001)
    }
}
