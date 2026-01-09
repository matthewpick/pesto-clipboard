import AppKit
import ImageIO
import QuickLookThumbnailing

struct ThumbnailGenerator {
    /// Generate a thumbnail from a file URL using QuickLook.
    /// Works for any file type that macOS can preview (images, PDFs, videos, documents, etc.)
    static func generateThumbnail(from fileURL: URL, maxSize: CGFloat = Constants.thumbnailMaxSize) -> Data? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        let size = CGSize(width: maxSize, height: maxSize)
        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: size,
            scale: 2.0,  // Retina
            representationTypes: .thumbnail
        )

        var thumbnailData: Data?
        let semaphore = DispatchSemaphore(value: 0)

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
            defer { semaphore.signal() }

            guard let representation = representation else { return }

            // Convert to JPEG data for storage efficiency
            let nsImage = representation.nsImage
            thumbnailData = nsImage.jpegData(compressionQuality: Constants.thumbnailCompressionQuality)
        }

        // Wait with timeout to avoid blocking indefinitely
        _ = semaphore.wait(timeout: .now() + 5.0)

        return thumbnailData
    }

    /// Generate a thumbnail from the first file in an array of URLs that has a preview
    static func generateThumbnailFromFirstFile(urls: [URL], maxSize: CGFloat = Constants.thumbnailMaxSize) -> Data? {
        for url in urls {
            if let thumbnail = generateThumbnail(from: url, maxSize: maxSize) {
                return thumbnail
            }
        }
        return nil
    }

    /// Generate a thumbnail from image data using CGImageSource for optimal performance.
    /// Use this for clipboard images where we have raw data instead of a file URL.
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
