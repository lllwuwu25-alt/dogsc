import AppKit
import ScreenCaptureKit

/// Small, transient previews of the actual chosen source. No disk cache and
/// no capture loop: each selection requests one frame, excluding our overlays.
@MainActor
enum RecorderSourceThumbnail {
    static func image(displayID: UInt32? = nil, windowID: UInt32? = nil) async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            try Task.checkCancellation()
            let filter: SCContentFilter
            let size: CGSize
            if let windowID, let window = content.windows.first(where: { $0.windowID == windowID }) {
                filter = SCContentFilter(desktopIndependentWindow: window)
                size = window.frame.size
            } else if let displayID, let display = content.displays.first(where: { $0.displayID == displayID }) {
                let ownApps = content.applications.filter { $0.processID == getpid() }
                filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
                size = display.frame.size
            } else { return nil }
            let config = SCStreamConfiguration()
            config.width = 256
            config.height = max(2, Int(256 * size.height / max(size.width, 1)))
            config.showsCursor = false
            config.scalesToFit = true
            let image: CGImage
            if #available(macOS 14.0, *) {
                image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            } else {
                guard let legacyImage = legacyImage(content: content, displayID: displayID,
                    windowID: windowID, width: config.width, height: config.height) else { return nil }
                image = legacyImage
            }
            try Task.checkCancellation()
            return NSImage(cgImage: image, size: CGSize(width: image.width, height: image.height))
        } catch { return nil }
    }

    /// One transient Quartz capture on Ventura, preserving the selected window
    /// ID or display bounds. The display list excludes this app's own overlays.
    private static func legacyImage(content: SCShareableContent, displayID: UInt32?,
                                    windowID: UInt32?, width: Int, height: Int) -> CGImage? {
        let image: CGImage?
        if let windowID {
            image = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID,
                                           [.boundsIgnoreFraming, .bestResolution])
        } else if let displayID,
                  let display = content.displays.first(where: { $0.displayID == displayID }),
                  let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
                    as? [[String: Any]] {
            let ids = windows.compactMap { entry -> CGWindowID? in
                guard (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value != getpid()
                else { return nil }
                return (entry[kCGWindowNumber as String] as? NSNumber)?.uint32Value
            }
            image = CGImage(windowListFromArrayScreenBounds: display.frame,
                windowArray: VenturaQuartzWindowList.makeArray(windowIDs: ids), imageOption: [.bestResolution])
        } else { return nil }
        guard let image, let context = CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
