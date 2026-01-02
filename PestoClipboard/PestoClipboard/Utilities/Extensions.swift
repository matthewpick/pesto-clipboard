import Foundation
import AppKit

// MARK: - Date Extensions

extension Date {
    /// Returns a relative time string like "2 minutes ago" or "Yesterday"
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - String Extensions

extension String {
    /// Returns a truncated version of the string if it exceeds maxLength
    func truncated(to maxLength: Int, trailing: String = "...") -> String {
        if count > maxLength {
            return String(prefix(maxLength - trailing.count)) + trailing
        }
        return self
    }

    /// Checks if the string is a valid URL
    var isValidURL: Bool {
        guard let url = URL(string: self) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
}

// MARK: - Data Extensions

extension Data {
    /// Returns a human-readable file size string
    var fileSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(count))
    }
}

// MARK: - URL Extensions

extension URL {
    /// Returns the file icon for this URL
    var fileIcon: NSImage? {
        NSWorkspace.shared.icon(forFile: path)
    }
}
