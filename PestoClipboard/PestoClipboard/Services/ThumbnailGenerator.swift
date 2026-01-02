import AppKit
import ImageIO

struct ThumbnailGenerator {
    /// Generate a thumbnail from image data using CGImageSource for optimal performance.
    /// This method is significantly faster than using NSImage for resizing.
    static func generateThumbnail(from imageData: Data, maxSize: CGFloat = Constants.thumbnailMaxSize) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        // Convert CGImage to JPEG data for smaller storage
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        return nsImage.jpegData(compressionQuality: Constants.thumbnailCompressionQuality)
    }
}

// MARK: - NSImage Extension

extension NSImage {
    func jpegData(compressionQuality: CGFloat = 0.8) -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}
