import CoreFoundation
import CoreGraphics

enum VenturaQuartzWindowList {
    /// Quartz window-list arrays contain raw integer IDs in pointer slots,
    /// not retained CFNumber/NSNumber objects. Nil callbacks preserve that ABI.
    static func makeArray(windowIDs: [CGWindowID]) -> CFArray {
        let array = CFArrayCreateMutable(kCFAllocatorDefault, windowIDs.count, nil)!
        for id in windowIDs where id != kCGNullWindowID {
            CFArrayAppendValue(array, UnsafeRawPointer(bitPattern: Int(id)))
        }
        return array
    }
}
