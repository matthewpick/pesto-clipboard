import SwiftUI

@main
struct PestoClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
                .onAppear {
                    AppEventBus.shared.hideHistoryPanel()
                }
        }
    }
}
