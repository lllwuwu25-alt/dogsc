import AVFoundation
import CoreGraphics
import CoreImage
import CoreVideo
import RecorderCore
import XCTest
@testable import DogSCApp

final class VideoColorCompatibilityTests: XCTestCase {
    // Values reported by Ventura's real AVAssetWriterInput validation error.
    private let venturaTransferFunctions: Set<String> = [
        "ITU_R_709_2", "ITU_R_2100_HLG", "Linear", "SMPTE_ST_2084_PQ",
        "ITU_R_2020", "SMPTE_ST_428_1", "SMPTE_240M_1995",
    ]

    func testCaptureWriterUsesVenturaSupportedTransferFunction() throws {
        for codec in [CaptureCodec.h264, .hevc, .proRes422] {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(codec.usesMOVContainer ? "mov" : "mp4")
            defer { try? FileManager.default.removeItem(at: url) }
            let output = try CaptureOutput(
                run: ScreenRecorderRunToken(runID: RecordingRunID(), streamGeneration: 1),
                outputURL: url, width: 64, height: 64, frameRate: .fps60,
                codec: codec, recordsSystemAudio: false, onTerminalFailure: { _ in }
            )
            let input = try XCTUnwrap(Mirror(reflecting: output).children
                .first { $0.label == "videoInput" }?.value as? AVAssetWriterInput)
            let properties = try XCTUnwrap(input.outputSettings?[AVVideoColorPropertiesKey]
                as? [String: String])
            let transfer = try XCTUnwrap(properties[AVVideoTransferFunctionKey])
            XCTAssertTrue(venturaTransferFunctions.contains(transfer),
                "\(codec): Ventura rejects AVVideoTransferFunctionKey=\(transfer)")
        }
    }

    func testExportWriterUsesVenturaSupportedTransferFunction() throws {
        let profile = try CoreImageFrameColorProfile(contract: .sdrDesktop)
        let transfer = try XCTUnwrap(profile.avVideoColorProperties[AVVideoTransferFunctionKey])
        XCTAssertTrue(venturaTransferFunctions.contains(transfer),
            "Ventura rejects export AVVideoTransferFunctionKey=\(transfer)")
    }

    func testVideoPixelsAreConvertedBeforeReceivingRec709Attachments() throws {
        let profile = try CoreImageFrameColorProfile(contract: .sdrDesktop)
        XCTAssertEqual(profile.outputColorSpace.name, CGColorSpace.sRGB,
            "Preview must retain the desktop sRGB contract")
        XCTAssertEqual(profile.videoOutputColorSpace.name, CGColorSpace.itur_709)
        let source = try XCTUnwrap(CGColor(colorSpace: profile.outputColorSpace,
            components: [0.25, 0.25, 0.25, 1]))
        let expected = try XCTUnwrap(source.converted(to: profile.videoOutputColorSpace,
            intent: .relativeColorimetric, options: nil)?.components)
        let image = CIImage(color: CIColor(cgColor: source))
        let context = profile.makeContext(cacheIntermediates: false, forVideoEncoding: true)
        var pixel: [Float] = [0, 0, 0, 0]
        pixel.withUnsafeMutableBytes { bytes in
            context.render(image, toBitmap: bytes.baseAddress!, rowBytes: 16,
                bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf,
                colorSpace: profile.videoOutputColorSpace)
        }
        XCTAssertEqual(pixel[0], Float(expected[0]), accuracy: 0.01)
        XCTAssertGreaterThan(abs(pixel[0] - 0.25), 0.015,
            "Relabeling unchanged sRGB pixels would alter video appearance")

        var buffer: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 1, 1,
            kCVPixelFormatType_32BGRA, nil, &buffer), kCVReturnSuccess)
        let output = try XCTUnwrap(buffer)
        profile.applyAttachments(to: output)
        XCTAssertEqual(CVBufferCopyAttachment(output, kCVImageBufferTransferFunctionKey, nil)
            as? String, AVVideoTransferFunction_ITU_R_709_2)
        XCTAssertEqual(VideoSDRColorProfile.colorSpaceName, CGColorSpace.itur_709)
    }
}
