import Foundation
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // MARK: - General Settings

    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }

    @Published var pasteAutomatically: Bool {
        didSet { UserDefaults.standard.set(pasteAutomatically, forKey: "pasteAutomatically") }
    }

    @Published var plainTextMode: Bool {
        didSet { UserDefaults.standard.set(plainTextMode, forKey: "plainTextMode") }
    }

    @Published var isPaused: Bool {
        didSet { UserDefaults.standard.set(isPaused, forKey: "isPaused") }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    @Published var useTransparentBackground: Bool {
        didSet { UserDefaults.standard.set(useTransparentBackground, forKey: "useTransparentBackground") }
    }

    // MARK: - Storage Settings

    @Published var captureText: Bool {
        didSet { UserDefaults.standard.set(captureText, forKey: "captureText") }
    }

    @Published var captureImages: Bool {
        didSet { UserDefaults.standard.set(captureImages, forKey: "captureImages") }
    }

    @Published var captureFiles: Bool {
        didSet { UserDefaults.standard.set(captureFiles, forKey: "captureFiles") }
    }

    @Published var historyLimit: Int {
        didSet { UserDefaults.standard.set(historyLimit, forKey: "historyLimit") }
    }

    @Published var sortOrder: SortOrder {
        didSet { UserDefaults.standard.set(sortOrder.rawValue, forKey: "sortOrder") }
    }

    // MARK: - Ignore Settings

    @Published var ignoredApps: [String] {
        didSet { UserDefaults.standard.set(ignoredApps, forKey: "ignoredApps") }
    }

    // MARK: - Sort Order

    enum SortOrder: String, CaseIterable {
        case recentlyUsed = "Recently Used"
        case dateAdded = "Date Added"
    }

    // MARK: - Init

    private init() {
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        self.pasteAutomatically = UserDefaults.standard.object(forKey: "pasteAutomatically") as? Bool ?? false
        self.plainTextMode = UserDefaults.standard.bool(forKey: "plainTextMode")
        self.isPaused = UserDefaults.standard.bool(forKey: "isPaused")
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.useTransparentBackground = UserDefaults.standard.object(forKey: "useTransparentBackground") as? Bool ?? true
        self.captureText = UserDefaults.standard.object(forKey: "captureText") as? Bool ?? true
        self.captureImages = UserDefaults.standard.object(forKey: "captureImages") as? Bool ?? true
        self.captureFiles = UserDefaults.standard.object(forKey: "captureFiles") as? Bool ?? true
        self.historyLimit = UserDefaults.standard.object(forKey: "historyLimit") as? Int ?? Constants.defaultHistoryLimit
        self.ignoredApps = UserDefaults.standard.stringArray(forKey: "ignoredApps") ?? []

        let sortRaw = UserDefaults.standard.string(forKey: "sortOrder") ?? SortOrder.recentlyUsed.rawValue
        self.sortOrder = SortOrder(rawValue: sortRaw) ?? .recentlyUsed
    }

    // MARK: - Actions

    func clearHistory(includeStarred: Bool = false) {
        if includeStarred {
            ClipboardHistoryManager.shared.clearAllIncludingStarred()
        } else {
            ClipboardHistoryManager.shared.clearAll()
        }
    }
}
