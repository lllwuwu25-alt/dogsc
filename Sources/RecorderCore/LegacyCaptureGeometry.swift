import Foundation

/// Geometry fallback for ScreenCaptureKit before filter scale metadata existed.
/// Display selection is used only for resolution, never to replace a requested
/// capture target. IDs and window filters remain owned by the recorder.
public enum LegacyCaptureGeometry {
    public struct Display: Sendable {
        public let frame: CGRect
        public let scale: CGFloat

        public init(frame: CGRect, scale: CGFloat) {
            self.frame = frame
            self.scale = scale
        }
    }

    public static func pixelScale(logicalWidth: CGFloat, pixelWidth: Int) -> CGFloat {
        guard logicalWidth.isFinite, logicalWidth > 0, pixelWidth > 0 else { return 1 }
        let scale = CGFloat(pixelWidth) / logicalWidth
        return scale.isFinite && scale >= 1 ? scale : 1
    }

    public static func pixelSize(logicalSize: CGSize, scale: CGFloat) -> CaptureDimensions {
        let safeScale = scale.isFinite && scale >= 1 ? scale : 1
        func dimension(_ value: CGFloat) -> Int {
            let pixels = value * safeScale
            guard pixels.isFinite, pixels > 0 else { return 2 }
            return max(2, Int(min(pixels.rounded(), 65_536)))
        }
        return CaptureDimensions(width: dimension(logicalSize.width), height: dimension(logicalSize.height))
    }

    public static func windowScale(frame: CGRect, displays: [Display]) -> CGFloat {
        guard !displays.isEmpty else { return 1 }
        let display = displays.max { left, right in
            func area(_ display: Display) -> CGFloat {
                let overlap = frame.intersection(display.frame)
                return overlap.isNull ? 0 : overlap.width * overlap.height
            }
            let leftArea = area(left), rightArea = area(right)
            if leftArea != rightArea { return leftArea < rightArea }
            func distance(_ display: Display) -> CGFloat {
                pow(frame.midX - display.frame.midX, 2) + pow(frame.midY - display.frame.midY, 2)
            }
            return distance(left) > distance(right)
        }
        let scale = display?.scale ?? 1
        return scale.isFinite && scale >= 1 ? scale : 1
    }
}
