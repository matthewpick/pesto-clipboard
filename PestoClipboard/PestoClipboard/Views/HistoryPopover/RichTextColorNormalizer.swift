import AppKit
import SwiftUI

/// Decides whether rich-text foreground colors are legible against the history
/// panel background, so unreadable ones can be dropped in favor of the adaptive
/// primary color. Extracted from the view so the decision logic is unit-testable.
enum RichTextColorNormalizer {

    /// Whether a foreground color has too little contrast with the panel
    /// background to be legible.
    ///
    /// We key off the color's HSB brightness (its max RGB component) and darkness
    /// (its min RGB component) rather than luminance, so saturated-but-low-luminance
    /// colors like blue stay untouched — only near-black/near-white text is dropped.
    static func isUnreadable(_ color: NSColor, colorScheme: ColorScheme) -> Bool {
        guard let rgb = color.usingColorSpace(.sRGB) else { return false }
        let brightness = max(rgb.redComponent, max(rgb.greenComponent, rgb.blueComponent))
        let darkness = min(rgb.redComponent, min(rgb.greenComponent, rgb.blueComponent))

        switch colorScheme {
        case .dark:
            // Near-black text is invisible on the dark panel.
            return brightness < 0.4
        case .light:
            // Near-white text is invisible on the light panel.
            return darkness > 0.6
        @unknown default:
            return false
        }
    }
}
