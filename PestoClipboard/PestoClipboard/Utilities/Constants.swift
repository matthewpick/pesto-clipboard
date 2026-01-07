import Carbon
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

    // MARK: - Key Codes

    /// Virtual key code for Delete (Backspace)
    static let deleteKeyCode: UInt16 = 51

    /// Virtual key code for Forward Delete
    static let forwardDeleteKeyCode: UInt16 = 117

    /// Virtual key code for 'V' (used for paste simulation)
    static let vKeyCode: CGKeyCode = 0x09

    // MARK: - Timing

    /// Delay before simulating paste (seconds) - allows panel to dismiss and focus to return
    static let pasteSimulationDelay: TimeInterval = 0.15

    /// Standard animation duration for UI transitions
    static let animationDuration: TimeInterval = 0.15
}
