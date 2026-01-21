import Carbon
import AppKit

/// Manages global keyboard shortcuts using Carbon API.
/// This lower-level approach prevents event leaks to RDP sessions.
final class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (() -> Void)?
    
    private init() {}
    
    /// Register the global hotkey (Cmd+Shift+V)
    func registerHotkeys(action: @escaping () -> Void) {
        self.action = action
        
        // Unregister any existing
        unregisterHotkeys()
        
        // Define Hotkey: Cmd+Shift+V
        // V key code = 0x09
        // Modifiers = cmdKey + shiftKey
        let keyCode: UInt32 = 0x09 // kVK_ANSI_V
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        
        let hotKeyID = EventHotKeyID(signature: OSType(0x50455354), id: 1) // "PEST"
        
        var gMyHotKeyRef: EventHotKeyRef?
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &gMyHotKeyRef
        )
        
        if status == noErr {
            hotKeyRef = gMyHotKeyRef
            if eventHandler == nil {
                installEventHandler()
            }
            print("✅ Global Hotkey (Carbon) registered: Cmd+Shift+V")
        } else {
            print("❌ Failed to register global hotkey: \(status)")
        }
    }
    
    /// Unregister hotkeys
    func unregisterHotkeys() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
    
    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { _, _, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            
            // Call callback synchronously (like ClipKitty)
            // The caller is responsible for main thread dispatch if needed
            manager.action?()
            
            return noErr
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
    }
    
    deinit {
        unregisterHotkeys()
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}
