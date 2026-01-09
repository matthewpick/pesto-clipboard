import Testing
import AppKit
@testable import Pesto_Clipboard

@MainActor
struct ThumbnailGeneratorTests {

    // MARK: - Helper

    /// Creates valid PNG image data for testing
    func createTestImageData(width: Int = 256, height: Int = 256) -> Data? {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    // MARK: - Thumbnail Generation Tests

    @Test func generateThumbnailFromValidImage() {
        guard let imageData = createTestImageData() else {
            Issue.record("Failed to create test image data")
            return
        }

        let thumbnail = ThumbnailGenerator.generateThumbnail(from: imageData)

        #expect(thumbnail != nil)
        #expect(thumbnail!.count > 0)
        #expect(thumbnail!.count < imageData.count) // Thumbnail should be smaller
    }

    @Test func generateThumbnailRespectsMaxSize() {
        guard let imageData = createTestImageData(width: 1000, height: 1000) else {
            Issue.record("Failed to create test image data")
            return
        }

        let maxSize: CGFloat = 64
        let thumbnail = ThumbnailGenerator.generateThumbnail(from: imageData, maxSize: maxSize)

        #expect(thumbnail != nil)

        // Verify thumbnail dimensions
        if let thumbnailData = thumbnail,
           let thumbnailImage = NSImage(data: thumbnailData) {
            #expect(thumbnailImage.size.width <= maxSize)
            #expect(thumbnailImage.size.height <= maxSize)
        }
    }

    @Test func generateThumbnailFromInvalidDataReturnsNil() {
        let invalidData = Data([0x00, 0x01, 0x02, 0x03]) // Random bytes

        let thumbnail = ThumbnailGenerator.generateThumbnail(from: invalidData)

        #expect(thumbnail == nil)
    }

    @Test func generateThumbnailFromEmptyDataReturnsNil() {
        let emptyData = Data()

        let thumbnail = ThumbnailGenerator.generateThumbnail(from: emptyData)

        #expect(thumbnail == nil)
    }

    @Test func generateThumbnailUsesDefaultMaxSize() {
        guard let imageData = createTestImageData(width: 500, height: 500) else {
            Issue.record("Failed to create test image data")
            return
        }

        // Use default maxSize (should be Constants.thumbnailMaxSize = 128)
        let thumbnail = ThumbnailGenerator.generateThumbnail(from: imageData)

        #expect(thumbnail != nil)

        if let thumbnailData = thumbnail,
           let thumbnailImage = NSImage(data: thumbnailData) {
            #expect(thumbnailImage.size.width <= 128)
            #expect(thumbnailImage.size.height <= 128)
        }
    }

    @Test func generateThumbnailPreservesAspectRatio() {
        // Create a wide image (400x100)
        guard let imageData = createTestImageData(width: 400, height: 100) else {
            Issue.record("Failed to create test image data")
            return
        }

        let thumbnail = ThumbnailGenerator.generateThumbnail(from: imageData, maxSize: 128)

        #expect(thumbnail != nil)

        if let thumbnailData = thumbnail,
           let thumbnailImage = NSImage(data: thumbnailData) {
            // Width should be 128 (max), height should be scaled proportionally
            let aspectRatio = thumbnailImage.size.width / thumbnailImage.size.height
            #expect(aspectRatio > 3.5 && aspectRatio < 4.5) // Should be close to 4:1
        }
    }

    @Test func generateThumbnailOutputsJPEGData() {
        guard let imageData = createTestImageData() else {
            Issue.record("Failed to create test image data")
            return
        }

        let thumbnail = ThumbnailGenerator.generateThumbnail(from: imageData)

        #expect(thumbnail != nil)

        // Check for JPEG magic bytes (0xFF 0xD8 0xFF)
        if let data = thumbnail, data.count >= 3 {
            #expect(data[0] == 0xFF)
            #expect(data[1] == 0xD8)
            #expect(data[2] == 0xFF)
        }
    }
}

// MARK: - File URL Thumbnail Tests (QuickLook)

@MainActor
struct ThumbnailGeneratorFileURLTests {

    // MARK: - Helper

    /// Creates a temporary image file and returns its URL
    func createTempImageFile(width: Int = 256, height: Int = 256) -> URL? {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test-image-\(UUID().uuidString).png")

        do {
            try pngData.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }

    // MARK: - Tests

    @Test func generateThumbnailFromImageFile() {
        guard let imageURL = createTempImageFile() else {
            Issue.record("Failed to create temp image file")
            return
        }
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let thumbnail = ThumbnailGenerator.generateThumbnail(from: imageURL)

        #expect(thumbnail != nil)
        #expect(thumbnail!.count > 0)
    }

    @Test func generateThumbnailFromNonExistentFileReturnsNil() {
        let fakeURL = URL(fileURLWithPath: "/nonexistent/path/to/file.png")

        let thumbnail = ThumbnailGenerator.generateThumbnail(from: fakeURL)

        #expect(thumbnail == nil)
    }

    @Test func generateThumbnailFromFirstFileFindsImage() {
        guard let imageURL = createTempImageFile() else {
            Issue.record("Failed to create temp image file")
            return
        }
        defer { try? FileManager.default.removeItem(at: imageURL) }

        // Create a text file that won't have a thumbnail
        let textURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test-\(UUID().uuidString).xyz")
        try? "test".write(to: textURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: textURL) }

        // Image file should generate thumbnail even if it's not first
        let urls = [textURL, imageURL]
        let thumbnail = ThumbnailGenerator.generateThumbnailFromFirstFile(urls: urls)

        #expect(thumbnail != nil)
    }

    @Test func generateThumbnailFromEmptyArrayReturnsNil() {
        let thumbnail = ThumbnailGenerator.generateThumbnailFromFirstFile(urls: [])

        #expect(thumbnail == nil)
    }

    @Test func generateThumbnailFromFileOutputsJPEGData() {
        guard let imageURL = createTempImageFile() else {
            Issue.record("Failed to create temp image file")
            return
        }
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let thumbnail = ThumbnailGenerator.generateThumbnail(from: imageURL)

        #expect(thumbnail != nil)

        // Check for JPEG magic bytes (0xFF 0xD8 0xFF)
        if let data = thumbnail, data.count >= 3 {
            #expect(data[0] == 0xFF)
            #expect(data[1] == 0xD8)
            #expect(data[2] == 0xFF)
        }
    }
}

// MARK: - NSImage Extension Tests

@MainActor
struct NSImageExtensionTests {

    @Test func jpegDataFromValidImage() {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        image.unlockFocus()

        let jpegData = image.jpegData()

        #expect(jpegData != nil)
        #expect(jpegData!.count > 0)
    }

    @Test func jpegDataWithCustomCompression() {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.green.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        image.unlockFocus()

        let highQuality = image.jpegData(compressionQuality: 1.0)
        let lowQuality = image.jpegData(compressionQuality: 0.1)

        #expect(highQuality != nil)
        #expect(lowQuality != nil)
        #expect(highQuality!.count > lowQuality!.count) // Higher quality = larger file
    }
}
