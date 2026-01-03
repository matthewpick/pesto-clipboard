import SwiftUI

extension Notification.Name {
    static let hideHistoryPanel = Notification.Name("hideHistoryPanel")
    static let showHistoryPanel = Notification.Name("showHistoryPanel")
    static let openHistoryPanel = Notification.Name("openHistoryPanel")
    static let deleteSelectedItem = Notification.Name("deleteSelectedItem")
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
