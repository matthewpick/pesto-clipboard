import SwiftUI

extension Notification.Name {
    static let hideHistoryPanel = Notification.Name("hideHistoryPanel")
    static let showHistoryPanel = Notification.Name("showHistoryPanel")
}

@main
struct PestoClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
                .onAppear {
                    NotificationCenter.default.post(name: .hideHistoryPanel, object: nil)
                }
        }
    }
}
