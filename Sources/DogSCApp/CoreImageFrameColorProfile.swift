import AVFoundation
import CoreImage
import CoreVideo
import Metal
import RecorderCore

enum FrameColorProfileError: LocalizedError {
    case unsupported(FrameColorContract)
    case unavailableColorSpace

    var errorDescription: String? {
        switch self {
        case .unsupported:
            "当前版本只支持桌面 SDR 成片。"
        case .unavailableColorSpace:
            "系统无法建立 SDR 色彩空间。"
        }
    }
}

/// One executable lowering of RecorderCore's color contract. Preview and
/// export must construct their Core Image contexts through this value instead
/// of falling back to a display-dependent RGB space.
struct CoreImageFrameColorProfile: @unchecked Sendable {
    let contract: FrameColorContract
    let workingColorSpace: CGColorSpace
    let outputColorSpace: CGColorSpace
    /// Video encoding has a distinct, explicitly converted output. Preview
    /// stays sRGB; encoded files use Ventura-compatible Rec.709.
    let videoOutputColorSpace: CGColorSpace

    init(contract: FrameColorContract) throws {
        guard contract == .sdrDesktop else {
            throw FrameColorProfileError.unsupported(contract)
        }
        guard let working = CGColorSpace(name: CGColorSpace.linearSRGB),
              let output = CGColorSpace(name: CGColorSpace.sRGB),
              let videoOutput = CGColorSpace(name: VideoSDRColorProfile.colorSpaceName) else {
            throw FrameColorProfileError.unavailableColorSpace
        }
        self.contract = contract
        workingColorSpace = working
        outputColorSpace = output
        videoOutputColorSpace = videoOutput
    }

    func makeContext(cacheIntermediates: Bool, forVideoEncoding: Bool = false) -> CIContext {
        CIContext(options: [
            .cacheIntermediates: cacheIntermediates,
            .workingColorSpace: workingColorSpace,
            .outputColorSpace: forVideoEncoding ? videoOutputColorSpace : outputColorSpace,
        ])
    }

    /// PRE-001...PRE-006: the editor presents through a CAMetalLayer. Building
    /// the context against that exact device lets Core Image encode directly
    /// into the drawable instead of creating a CPU-backed CGImage every tick.
    func makeMetalContext(
        commandQueue: MTLCommandQueue,
        cacheIntermediates: Bool
    ) -> CIContext {
        CIContext(mtlCommandQueue: commandQueue, options: [
            .cacheIntermediates: cacheIntermediates,
            .workingColorSpace: workingColorSpace,
            .outputColorSpace: outputColorSpace,
        ])
    }

    var avVideoColorProperties: [String: String] {
        VideoSDRColorProfile.avVideoColorProperties
    }

    func applyAttachments(to pixelBuffer: CVPixelBuffer) {
        VideoSDRColorProfile.applyAttachments(to: pixelBuffer)
    }
}
