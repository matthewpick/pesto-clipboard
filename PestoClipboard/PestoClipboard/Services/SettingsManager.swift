import Foundation
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private weak var historyManager: ClipboardHistoryManaging?

    func configure(historyManager: ClipboardHistoryManaging) {
        self.historyManager = historyManager
    }

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
        didSet {
            let clamped = historyLimit.clamped(to: Constants.historyLimitRange)
            if historyLimit != clamped {
                historyLimit = clamped
            }
            UserDefaults.standard.set(historyLimit, forKey: "historyLimit")
        }
    }

    @Published var sortOrder: SortOrder {
        didSet { UserDefaults.standard.set(sortOrder.rawValue, forKey: "sortOrder") }
    }

    @Published var autoDeleteInterval: AutoDeleteInterval {
        didSet { UserDefaults.standard.set(autoDeleteInterval.rawValue, forKey: "autoDeleteInterval") }
    }

    // MARK: - Ignore Settings

    @Published var ignoredApps: [String] {
        didSet { UserDefaults.standard.set(ignoredApps, forKey: "ignoredApps") }
    }

    @Published var ignoreRemoteClipboard: Bool {
        didSet { UserDefaults.standard.set(ignoreRemoteClipboard, forKey: "ignoreRemoteClipboard") }
    }

    @Published var ignorePasswordManagers: Bool {
        didSet { UserDefaults.standard.set(ignorePasswordManagers, forKey: "ignorePasswordManagers") }
    }

    // MARK: - Advanced Settings

    @Published var hideMenuBarIcon: Bool {
        didSet { UserDefaults.standard.set(hideMenuBarIcon, forKey: "hideMenuBarIcon") }
    }

    // MARK: - Sort Order

    enum SortOrder: String, CaseIterable {
        case recentlyUsed = "Recently Used"
        case dateAdded = "Date Added"

        var localizedName: String {
            switch self {
            case .recentlyUsed: return String(localized: "Recently Used")
            case .dateAdded: return String(localized: "Date Added")
            }
        }
    }

    // MARK: - Auto-Delete Interval

    enum AutoDeleteInterval: String, CaseIterable {
        case never
        case oneHour
        case threeHours
        case twelveHours
        case oneDay
        case sevenDays
        case thirtyDays

        var timeInterval: TimeInterval? {
            switch self {
            case .never: return nil
            case .oneHour: return 3600
            case .threeHours: return 3600 * 3
            case .twelveHours: return 3600 * 12
            case .oneDay: return 3600 * 24
            case .sevenDays: return 3600 * 24 * 7
            case .thirtyDays: return 3600 * 24 * 30
            }
        }

        var localizedName: String {
            switch self {
            case .never: return String(localized: "Never")
            case .oneHour: return String(localized: "1 hour")
            case .threeHours: return String(localized: "3 hours")
            case .twelveHours: return String(localized: "12 hours")
            case .oneDay: return String(localized: "1 day")
            case .sevenDays: return String(localized: "7 days")
            case .thirtyDays: return String(localized: "30 days")
            }
        }
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
        let storedLimit = UserDefaults.standard.object(forKey: "historyLimit") as? Int ?? Constants.defaultHistoryLimit
        self.historyLimit = storedLimit.clamped(to: Constants.historyLimitRange)
        self.ignoredApps = UserDefaults.standard.stringArray(forKey: "ignoredApps") ?? []
        self.ignoreRemoteClipboard = UserDefaults.standard.object(forKey: "ignoreRemoteClipboard") as? Bool ?? true
        self.ignorePasswordManagers = UserDefaults.standard.object(forKey: "ignorePasswordManagers") as? Bool ?? true

        let sortRaw = UserDefaults.standard.string(forKey: "sortOrder") ?? SortOrder.recentlyUsed.rawValue
        self.sortOrder = SortOrder(rawValue: sortRaw) ?? .recentlyUsed

        let autoDeleteRaw = UserDefaults.standard.string(forKey: "autoDeleteInterval") ?? AutoDeleteInterval.never.rawValue
        self.autoDeleteInterval = AutoDeleteInterval(rawValue: autoDeleteRaw) ?? .never

        self.hideMenuBarIcon = UserDefaults.standard.bool(forKey: "hideMenuBarIcon")
    }

    // MARK: - Actions

    func clearHistory(includeStarred: Bool = false) {
        if includeStarred {
            historyManager?.clearAllIncludingStarred()
        } else {
            historyManager?.clearAll()
        }
    }
}
