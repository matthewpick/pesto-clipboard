import AppKit
import SwiftUI

// MARK: - Edit Window Controller

class EditWindowController {
    static let shared = EditWindowController()

    private var editWindow: NSWindow?
    private var editWindowDelegate: EditWindowDelegate?

    private init() {}

    @MainActor
    func showEditWindow(for item: ClipboardItem, historyManager: ClipboardHistoryManager) {
        editWindow?.close()
        editWindow = nil
        editWindowDelegate = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "Edit Clipboard Item")
        window.isReleasedWhenClosed = false

        let delegate = EditWindowDelegate { [weak self] in
            self?.editWindow = nil
            self?.editWindowDelegate = nil
        }
        window.delegate = delegate
        editWindowDelegate = delegate

        let editView = EditItemView(
            initialText: item.textContent ?? "",
            onSave: { newText in
                historyManager.updateTextContent(item, newText: newText)
            },
            onClose: { [weak self] in
                self?.editWindow?.close()
            }
        )

        window.contentView = NSHostingView(rootView: editView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        editWindow = window
    }
}

// MARK: - Edit Window Delegate

private class EditWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

// MARK: - Edit Item View

struct EditItemView: View {
    @State private var text: String
    var onSave: (String) -> Void
    var onClose: () -> Void

    init(initialText: String, onSave: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        _text = State(initialValue: initialText)
        self.onSave = onSave
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)
                .padding()

            Divider()

            HStack {
                Button("Cancel", action: onClose)
                    .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button("Save") {
                    onSave(text)
                    onClose()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}
