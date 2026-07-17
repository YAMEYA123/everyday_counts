import AVFoundation
import Photos
import UIKit

class VideoGenerator {
    static func generate(assets: [PHAsset], onProgress: @escaping (Double) -> Void) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        let W = 1080, H = 1920
        let FPS: Int32 = 30
        let secsPerPhoto = 3.0

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: W, AVVideoHeightKey: H
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: W,
                kCVPixelBufferHeightKey as String: H
            ]
        )
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameCount = Int(secsPerPhoto * Double(FPS))
        let mgr = PHImageManager.default()
        let opts = PHImageRequestOptions()
        opts.isSynchronous = true
        opts.deliveryMode = .highQualityFormat

        for (idx, asset) in assets.enumerated() {
            var uiImage: UIImage?
            mgr.requestImage(for: asset, targetSize: CGSize(width: W, height: H),
                             contentMode: .aspectFill, options: opts) { img, _ in uiImage = img }
            guard let image = uiImage else { continue }
            for frame in 0..<frameCount {
                while !input.isReadyForMoreMediaData { await Task.yield() }
                let time = CMTime(value: CMTimeValue(idx * frameCount + frame), timescale: FPS)
                if let buf = pixelBuffer(from: image, width: W, height: H) {
                    adaptor.append(buf, withPresentationTime: time)
                }
            }
            onProgress(Double(idx + 1) / Double(assets.count))
        }

        input.markAsFinished()
        await writer.finishWriting()
        return outputURL
    }

    private static func pixelBuffer(from image: UIImage, width: Int, height: Int) -> CVPixelBuffer? {
        var buf: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &buf)
        guard let buffer = buf else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        if let cgImage = image.cgImage {
            ctx?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}
