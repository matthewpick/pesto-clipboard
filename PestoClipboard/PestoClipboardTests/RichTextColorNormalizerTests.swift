import Testing
import AppKit
import SwiftUI
@testable import Pesto_Clipboard

struct RichTextColorNormalizerTests {

    // MARK: - Dark mode (panel is dark; near-black text is unreadable)

    @Test func darkMode_dropsBlackText() {
        #expect(RichTextColorNormalizer.isUnreadable(.black, colorScheme: .dark))
    }

    @Test func darkMode_dropsNearBlackGray() {
        let darkGray = NSColor(srgbRed: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        #expect(RichTextColorNormalizer.isUnreadable(darkGray, colorScheme: .dark))
    }

    @Test func darkMode_keepsWhiteText() {
        #expect(!RichTextColorNormalizer.isUnreadable(.white, colorScheme: .dark))
    }

    @Test func darkMode_keepsSaturatedBlue() {
        // Blue has low luminance but high brightness — must stay readable, not dropped.
        let blue = NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)
        #expect(!RichTextColorNormalizer.isUnreadable(blue, colorScheme: .dark))
    }

    @Test func darkMode_keepsGreenPathColor() {
        let green = NSColor(srgbRed: 0.2, green: 0.8, blue: 0.4, alpha: 1)
        #expect(!RichTextColorNormalizer.isUnreadable(green, colorScheme: .dark))
    }

    @Test func darkMode_keepsOrangeMarkdownColor() {
        let orange = NSColor(srgbRed: 1, green: 0.5, blue: 0, alpha: 1)
        #expect(!RichTextColorNormalizer.isUnreadable(orange, colorScheme: .dark))
    }

    // MARK: - Light mode (panel is light; near-white text is unreadable)

    @Test func lightMode_dropsWhiteText() {
        #expect(RichTextColorNormalizer.isUnreadable(.white, colorScheme: .light))
    }

    @Test func lightMode_dropsNearWhiteGray() {
        let nearWhite = NSColor(srgbRed: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        #expect(RichTextColorNormalizer.isUnreadable(nearWhite, colorScheme: .light))
    }

    @Test func lightMode_keepsBlackText() {
        #expect(!RichTextColorNormalizer.isUnreadable(.black, colorScheme: .light))
    }

    @Test func lightMode_keepsSaturatedBlue() {
        let blue = NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)
        #expect(!RichTextColorNormalizer.isUnreadable(blue, colorScheme: .light))
    }

    // MARK: - Threshold boundaries

    @Test func darkMode_thresholdBoundary() {
        // brightness just below 0.4 is dropped, at/above 0.4 is kept.
        let justBelow = NSColor(srgbRed: 0.39, green: 0.39, blue: 0.39, alpha: 1)
        let atThreshold = NSColor(srgbRed: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        #expect(RichTextColorNormalizer.isUnreadable(justBelow, colorScheme: .dark))
        #expect(!RichTextColorNormalizer.isUnreadable(atThreshold, colorScheme: .dark))
    }

    @Test func lightMode_thresholdBoundary() {
        // darkness just above 0.6 is dropped, at/below 0.6 is kept.
        let justAbove = NSColor(srgbRed: 0.61, green: 0.61, blue: 0.61, alpha: 1)
        let atThreshold = NSColor(srgbRed: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        #expect(RichTextColorNormalizer.isUnreadable(justAbove, colorScheme: .light))
        #expect(!RichTextColorNormalizer.isUnreadable(atThreshold, colorScheme: .light))
    }
}
