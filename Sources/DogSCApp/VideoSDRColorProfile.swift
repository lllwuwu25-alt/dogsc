import AVFoundation
import CoreGraphics
import CoreVideo

/// AVAssetWriter's SDR contract, including Ventura. Its sRGB transfer-function
/// option is only available on macOS 15+. Convert pixels to Rec.709 at the
/// producer (ScreenCaptureKit or Core Image); never merely relabel sRGB bytes.
enum VideoSDRColorProfile {
    static var colorSpaceName: CFString { CGColorSpace.itur_709 }

    static let avVideoColorProperties: [String: String] = [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
    ]

    static func applyAttachments(to pixelBuffer: CVPixelBuffer) {
        CVBufferSetAttachment(pixelBuffer, kCVImageBufferColorPrimariesKey,
            kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(pixelBuffer, kCVImageBufferTransferFunctionKey,
            kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey,
            kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
        if let colorSpace = CGColorSpace(name: colorSpaceName) {
            CVBufferSetAttachment(pixelBuffer, kCVImageBufferCGColorSpaceKey,
                colorSpace, .shouldPropagate)
        }
    }
}
