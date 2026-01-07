# Auto-Update for Multi-Distribution macOS Apps

This document covers strategies for implementing "Check for Updates" functionality in macOS apps distributed through multiple channels.

## The Challenge

macOS apps can be distributed via:
- **Mac App Store** - Apple handles updates automatically
- **Homebrew Cask** - Users update via `brew upgrade`
- **Direct Download** - App must handle its own updates

Each method has different expectations and technical requirements for updates.

## Detecting Installation Source

Detect at runtime how the app was installed:

```swift
enum InstallSource {
    case appStore
    case homebrew
    case directDownload
}

func detectInstallSource() -> InstallSource {
    let bundlePath = Bundle.main.bundlePath

    // Mac App Store - check for valid receipt
    if let receiptURL = Bundle.main.appStoreReceiptURL,
       FileManager.default.fileExists(atPath: receiptURL.path) {
        // Additional validation: verify receipt is not from sandbox
        if !receiptURL.path.contains("sandboxReceipt") {
            return .appStore
        }
    }

    // Homebrew Cask - check common installation paths
    if bundlePath.contains("Caskroom") ||
       bundlePath.contains("/opt/homebrew/") ||
       bundlePath.contains("/usr/local/Cellar/") {
        return .homebrew
    }

    // Default to direct download
    return .directDownload
}
```

## Update Strategy by Source

| Source | Strategy | UI |
|--------|----------|-----|
| Mac App Store | Disabled - Apple handles it | Hide "Check for Updates" menu item |
| Homebrew | Notify only, suggest CLI command | Show version info, link to instructions |
| Direct Download | Full in-app updates via Sparkle | Standard "Check for Updates" menu item |

## Implementation

### UpdateManager Service

```swift
import Foundation

class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    @Published var updateAvailable = false
    @Published var latestVersion: String?

    private(set) var installSource: InstallSource

    private init() {
        self.installSource = Self.detectInstallSource()
    }

    var shouldShowUpdateMenu: Bool {
        installSource != .appStore
    }

    func checkForUpdates() {
        switch installSource {
        case .appStore:
            // Do nothing - App Store handles updates
            break

        case .homebrew:
            // Check GitHub releases for new version, notify user
            checkGitHubReleases { [weak self] newVersion in
                if let version = newVersion {
                    self?.latestVersion = version
                    self?.updateAvailable = true
                    self?.showHomebrewUpdateNotification(version: version)
                }
            }

        case .directDownload:
            // Use Sparkle framework
            #if canImport(Sparkle)
            SUUpdater.shared().checkForUpdates(nil)
            #endif
        }
    }

    private func showHomebrewUpdateNotification(version: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = """
            Version \(version) is available.

            Update via Homebrew:
            brew upgrade pesto-clipboard
            """
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Copy Command")

        if alert.runModal() == .alertSecondButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("brew upgrade pesto-clipboard", forType: .string)
        }
    }

    private func checkGitHubReleases(completion: @escaping (String?) -> Void) {
        // Check GitHub API for latest release
        let url = URL(string: "https://api.github.com/repos/OWNER/REPO/releases/latest")!
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                completion(nil)
                return
            }

            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            if tagName != currentVersion {
                DispatchQueue.main.async {
                    completion(tagName)
                }
            } else {
                completion(nil)
            }
        }.resume()
    }

    private static func detectInstallSource() -> InstallSource {
        let bundlePath = Bundle.main.bundlePath

        if let receiptURL = Bundle.main.appStoreReceiptURL,
           FileManager.default.fileExists(atPath: receiptURL.path),
           !receiptURL.path.contains("sandboxReceipt") {
            return .appStore
        }

        if bundlePath.contains("Caskroom") ||
           bundlePath.contains("/opt/homebrew/") ||
           bundlePath.contains("/usr/local/Cellar/") {
            return .homebrew
        }

        return .directDownload
    }
}
```

### Menu Bar Integration

```swift
// In your app menu or settings
if UpdateManager.shared.shouldShowUpdateMenu {
    Button("Check for Updates...") {
        UpdateManager.shared.checkForUpdates()
    }
}
```

## Sparkle Framework Setup (Direct Download)

[Sparkle](https://sparkle-project.org/) is the standard framework for macOS app updates.

### Installation

Add to `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
]
```

Or via Xcode: File → Add Package Dependencies → `https://github.com/sparkle-project/Sparkle`

### Configuration

1. **Generate EdDSA keys** for signing updates:
   ```bash
   ./bin/generate_keys
   ```

2. **Add to Info.plist**:
   ```xml
   <key>SUFeedURL</key>
   <string>https://yoursite.com/appcast.xml</string>
   <key>SUPublicEDKey</key>
   <string>YOUR_PUBLIC_KEY</string>
   ```

3. **Host appcast.xml** on your server with release information

### Conditional Compilation

Only include Sparkle for non-App Store builds:

```swift
#if !APP_STORE
import Sparkle
#endif

class UpdateManager {
    #if !APP_STORE
    private let updaterController: SPUStandardUpdaterController
    #endif

    init() {
        #if !APP_STORE
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        #endif
    }
}
```

## Build Configuration

Use build flags to conditionally compile update code:

### Xcode Build Settings

1. Add `APP_STORE` to "Active Compilation Conditions" for App Store targets
2. Create separate schemes for App Store vs Direct distribution

### Example Scheme Setup

- **PestoClipboard** - Direct download build (includes Sparkle)
- **PestoClipboard-AppStore** - App Store build (no Sparkle, `APP_STORE` flag)

## Alternative: Marker File Approach

If runtime detection is unreliable, use a marker file during installation:

```swift
func detectInstallSource() -> InstallSource {
    let supportDir = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    ).first!.appendingPathComponent("PestoClipboard")

    if FileManager.default.fileExists(
        atPath: supportDir.appendingPathComponent(".homebrew").path
    ) {
        return .homebrew
    }

    // ... other checks
}
```

Homebrew cask post-install script writes the marker:
```ruby
postflight do
    touch "#{Dir.home}/Library/Application Support/PestoClipboard/.homebrew"
end
```

## Real-World Examples

| App | Approach |
|-----|----------|
| VS Code | Detects Homebrew, disables built-in updates, shows notification |
| Rectangle | Sparkle for direct, detects App Store receipt to disable |
| Firefox | Multiple update channels, enterprise policy support |
| iTerm2 | Sparkle with automatic/manual update preference |

## Recommendations for Pesto Clipboard

1. **Start simple** - Implement GitHub release checking for version comparison
2. **Add Sparkle later** - When direct download becomes primary distribution
3. **Homebrew-friendly** - Just notify users, don't force in-app updates
4. **Hide for App Store** - Detect receipt and hide update UI entirely

## References

- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [Apple App Store Receipt Validation](https://developer.apple.com/documentation/appstorereceipts)
- [Homebrew Cask Documentation](https://docs.brew.sh/Cask-Cookbook)
