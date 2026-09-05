import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Stateless image work that can run in a detached task without blocking the UI.
enum PhotoImageProcessor {
    private static let maximumPixelSize = 1_600
    private static let maximumInputBytes = 50 * 1_024 * 1_024

    static func jpegData(from data: Data) throws -> Data {
        guard !data.isEmpty else { throw ProcessingError.invalidImage }
        guard data.count <= maximumInputBytes else { throw ProcessingError.imageTooLarge }

        // Leave the original compressed. ImageIO downsamples before allocating the
        // decoded bitmap, keeping large camera photos out of full-resolution memory.
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              isImage(source),
              let scaledImage = downsample(source, maxPixelSize: maximumPixelSize) else {
            throw ProcessingError.invalidImage
        }

        // Render only the downsampled image. An opaque white background preserves
        // transparent PNG artwork when converting to JPEG's opaque pixel format.
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: scaledImage.width,
                height: scaledImage.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
              ) else {
            throw ProcessingError.renderFailed
        }
        let bounds = CGRect(x: 0, y: 0, width: scaledImage.width, height: scaledImage.height)
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(bounds)
        context.interpolationQuality = .high
        context.draw(scaledImage, in: bounds)
        guard let opaqueImage = context.makeImage() else {
            throw ProcessingError.renderFailed
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ProcessingError.encodingFailed
        }

        // Encode pixels into a fresh file; never copy source EXIF/GPS metadata.
        // Orientation has already been applied by ImageIO's thumbnail transform.
        let properties = [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary
        CGImageDestinationAddImage(destination, opaqueImage, properties)
        guard CGImageDestinationFinalize(destination), output.length > 0 else {
            throw ProcessingError.encodingFailed
        }
        return output as Data
    }

    static func thumbnail(from url: URL, maxPixelSize: Int) -> UIImage? {
        guard url.isFileURL, maxPixelSize > 0 else { return nil }
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions),
              isImage(source),
              let cgImage = downsample(source, maxPixelSize: maxPixelSize) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    private static func isImage(_ source: CGImageSource) -> Bool {
        guard CGImageSourceGetCount(source) > 0,
              let identifier = CGImageSourceGetType(source),
              let type = UTType(identifier as String) else {
            return false
        }
        return type.conforms(to: .image)
    }

    private static func downsample(_ source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            // Rotate/mirror the pixels using EXIF, then display with .up orientation.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    enum ProcessingError: LocalizedError {
        case invalidImage
        case imageTooLarge
        case renderFailed
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "写真を読み込めませんでした。別の写真を選んでください。"
            case .imageTooLarge:
                return "写真のサイズが大きすぎます。50MB以下の写真を選んでください。"
            case .renderFailed:
                return "写真を処理できませんでした。もう一度お試しください。"
            case .encodingFailed:
                return "写真を保存用の画像に変換できませんでした。別の写真を選んでください。"
            }
        }
    }
}
