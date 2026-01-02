import Foundation

enum Constants {
    // MARK: - Clipboard History

    /// Default maximum number of clipboard items to store
    static let defaultHistoryLimit = 500

    /// Range for history limit setting in preferences
    static let historyLimitRange = 50...5000

    /// Step size for history limit stepper
    static let historyLimitStep = 50

    // MARK: - Clipboard Monitoring

    /// Interval between clipboard checks (in seconds)
    static let clipboardPollInterval: TimeInterval = 0.5

    // MARK: - Images

    /// Maximum image size to store in bytes (5MB)
    static let maxImageSizeBytes = 5_000_000

    /// Maximum thumbnail dimension in pixels
    static let thumbnailMaxSize: CGFloat = 128

    /// JPEG compression quality for thumbnails
    static let thumbnailCompressionQuality: CGFloat = 0.7
}
