import CoreGraphics
import Foundation
import RecorderCore
import ScreenCaptureKit

enum ScreenCaptureCompatibility {
    static func displayScale(filter: SCContentFilter, display: SCDisplay) -> CGFloat {
        if #available(macOS 14.0, *) { return max(CGFloat(filter.pointPixelScale), 1) }
        return scale(for: display)
    }

    static func windowSize(filter: SCContentFilter, window: SCWindow,
                           displays: [SCDisplay]) -> CaptureDimensions {
        if #available(macOS 14.0, *) {
            let size = filter.contentRect.size
            return LegacyCaptureGeometry.pixelSize(
                logicalSize: size.width > 0 && size.height > 0 ? size : window.frame.size,
                scale: max(CGFloat(filter.pointPixelScale), 1))
        }
        let geometries = displays.map {
            LegacyCaptureGeometry.Display(frame: $0.frame, scale: scale(for: $0))
        }
        return LegacyCaptureGeometry.pixelSize(logicalSize: window.frame.size,
            scale: LegacyCaptureGeometry.windowScale(frame: window.frame, displays: geometries))
    }

    private static func scale(for display: SCDisplay) -> CGFloat {
        let pixels = CGDisplayCopyDisplayMode(display.displayID)?.pixelWidth
            ?? CGDisplayPixelsWide(display.displayID)
        return LegacyCaptureGeometry.pixelScale(logicalWidth: CGFloat(display.width), pixelWidth: pixels)
    }
}
