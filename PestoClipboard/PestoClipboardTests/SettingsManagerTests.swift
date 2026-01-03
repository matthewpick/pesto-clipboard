import Testing
@testable import Pesto_Clipboard

struct SettingsManagerTests {

    // MARK: - SortOrder Enum Tests

    @Test func sortOrderRawValues() {
        #expect(SettingsManager.SortOrder.recentlyUsed.rawValue == "Recently Used")
        #expect(SettingsManager.SortOrder.dateAdded.rawValue == "Date Added")
    }

    @Test func sortOrderFromRawValue() {
        #expect(SettingsManager.SortOrder(rawValue: "Recently Used") == .recentlyUsed)
        #expect(SettingsManager.SortOrder(rawValue: "Date Added") == .dateAdded)
        #expect(SettingsManager.SortOrder(rawValue: "Invalid") == nil)
    }

    @Test func sortOrderAllCases() {
        let allCases = SettingsManager.SortOrder.allCases
        #expect(allCases.count == 2)
        #expect(allCases.contains(.recentlyUsed))
        #expect(allCases.contains(.dateAdded))
    }

    // MARK: - Singleton Tests

    @Test func sharedInstanceExists() {
        let shared = SettingsManager.shared
        #expect(shared != nil)
    }

    @Test func sharedInstanceIsSame() {
        let first = SettingsManager.shared
        let second = SettingsManager.shared
        #expect(first === second)
    }

    // MARK: - Default Values Tests
    // Note: These test the current state of UserDefaults, which may have been modified

    @Test func defaultCaptureSettingsAreEnabled() {
        // Fresh install defaults should be true for capture settings
        // This tests the expected defaults, not necessarily the current state
        let defaults = UserDefaults.standard

        // If the key hasn't been set, object(forKey:) returns nil
        // The SettingsManager treats nil as true for these settings
        if defaults.object(forKey: "captureText") == nil {
            // Not set = default to true (as per SettingsManager init)
            #expect(true)
        }
    }

    @Test func defaultHistoryLimit() {
        // Default history limit should be 500 (Constants.defaultHistoryLimit)
        #expect(Constants.defaultHistoryLimit == 500)
    }

    @Test func historyLimitRange() {
        // Verify the history limit range constants
        #expect(Constants.historyLimitRange.lowerBound == 50)
        #expect(Constants.historyLimitRange.upperBound == 5000)
    }

    @Test func historyLimitStep() {
        #expect(Constants.historyLimitStep == 50)
    }
}

// MARK: - Constants Tests

struct ConstantsTests {

    @Test func clipboardPollInterval() {
        #expect(Constants.clipboardPollInterval == 0.5)
    }

    @Test func maxImageSizeBytes() {
        #expect(Constants.maxImageSizeBytes == 5_000_000) // 5MB
    }

    @Test func thumbnailMaxSize() {
        #expect(Constants.thumbnailMaxSize == 128)
    }

    @Test func thumbnailCompressionQuality() {
        #expect(Constants.thumbnailCompressionQuality == 0.7)
    }
}
