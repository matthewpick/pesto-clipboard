import Foundation

/// Per-item lifetime presets offered in the history context menu.
///
/// This is independent of `SettingsManager.AutoDeleteInterval`, which is a global
/// policy over the whole history. An expiration set here belongs to one item and
/// is honored even if that item is starred.
/// `nonisolated` because the target defaults to `MainActor` isolation: this is a
/// stateless value type and the sweep reads it off the main actor.
nonisolated enum ExpirationOption: CaseIterable, Identifiable {
    case never
    case fiveMinutes
    case fifteenMinutes
    case oneHour
    case sixHours
    case oneDay
    case sevenDays

    var id: String { String(describing: self) }

    /// Lifetime in seconds, or nil for `.never`.
    var duration: TimeInterval? {
        switch self {
        case .never: return nil
        case .fiveMinutes: return 60 * 5
        case .fifteenMinutes: return 60 * 15
        case .oneHour: return 3600
        case .sixHours: return 3600 * 6
        case .oneDay: return 3600 * 24
        case .sevenDays: return 3600 * 24 * 7
        }
    }

    var localizedName: String {
        switch self {
        case .never: return String(localized: "Never")
        case .fiveMinutes: return String(localized: "5 minutes")
        case .fifteenMinutes: return String(localized: "15 minutes")
        case .oneHour: return String(localized: "1 hour")
        case .sixHours: return String(localized: "6 hours")
        case .oneDay: return String(localized: "1 day")
        case .sevenDays: return String(localized: "7 days")
        }
    }

    /// Maps a stored `expirationDuration` back to a preset so the menu can show
    /// which one is active. Durations that don't match a preset (e.g. left over
    /// from an older build) fall back to `.never`.
    init(duration: TimeInterval) {
        self = Self.allCases.first { $0.duration == duration } ?? .never
    }
}
