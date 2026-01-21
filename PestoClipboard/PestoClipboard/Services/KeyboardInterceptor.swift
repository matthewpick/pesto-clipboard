import Cocoa
import Carbon
import KeyboardShortcuts

/// Intercepts keyboard events using CGEventTap to prevent modifier keys
/// from reaching RDP clients like RoyalTSX when our hotkey combo is pressed.
///
/// Strategy: If the configured shortcut contains Cmd, buffer Cmd key events
/// for a short window. If the complete shortcut combo is detected, suppress ALL.
/// If not, release them. This prevents WinKey from reaching Windows.
final class KeyboardInterceptor {
    static let shared = KeyboardInterceptor()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hotkeyCallback: (() -> Void)?
    
    // Configured shortcut info
    private var targetKeyCode: CGKeyCode = 0x09  // Default: V
    private var requiresCmd = true
    private var requiresShift = true
    private var requiresOption = false
    private var requiresControl = false
    
    // Buffering for Cmd key (only used if shortcut contains Cmd)
    private var bufferedCmdEvent: CGEvent?
    private var bufferedShiftEvent: CGEvent?
    private var bufferTimer: DispatchSourceTimer?
    private let bufferDuration: TimeInterval = 0.3 // Increased to 300ms based on logs
    
    // Track modifier state
    private var cmdDown = false
    private var shiftDown = false
    private var optionDown = false
    private var controlDown = false
    private var isBuffering = false
    
    // Suppression flags for release events
    private var preventNextCmdRelease = false
    private var preventNextShiftRelease = false
    private var preventNextOptionRelease = false
    private var preventNextControlRelease = false
    
    // Key codes
    private let leftCmdKeyCode: CGKeyCode = 0x37
    private let rightCmdKeyCode: CGKeyCode = 0x36
    private let leftShiftKeyCode: CGKeyCode = 0x38
    private let rightShiftKeyCode: CGKeyCode = 0x3C
    private let leftOptionKeyCode: CGKeyCode = 0x3A
    private let rightOptionKeyCode: CGKeyCode = 0x3D
    private let leftControlKeyCode: CGKeyCode = 0x3B
    private let rightControlKeyCode: CGKeyCode = 0x3E
    
    private init() {}
    
    /// Start intercepting keyboard events
    func start(hotkeyCallback: @escaping () -> Void) {
        self.hotkeyCallback = hotkeyCallback
        
        // Read configured shortcut from KeyboardShortcuts
        loadConfiguredShortcut()
        
        // Reset state
        resetState()
        
        // Only use event tap if shortcut contains Cmd (for RDP WinKey issue)
        guard requiresCmd else {
            print("ℹ️ KeyboardInterceptor: Shortcut doesn't contain Cmd - no buffering needed")
            // No Cmd in shortcut means no WinKey issue, use simple Carbon API
            HotkeyManager.shared.registerHotkeys(action: hotkeyCallback)
            return
        }
        
        guard AccessibilityHelper.hasPermission else {
            print("⚠️ KeyboardInterceptor: No accessibility permission - using Carbon fallback")
            HotkeyManager.shared.registerHotkeys(action: hotkeyCallback)
            return
        }
        
        // Create event tap for keyDown, keyUp, and flagsChanged (modifiers)
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                                      (1 << CGEventType.keyUp.rawValue) |
                                      (1 << CGEventType.flagsChanged.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let interceptor = Unmanaged<KeyboardInterceptor>.fromOpaque(refcon).takeUnretainedValue()
                return interceptor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("❌ KeyboardInterceptor: Failed to create event tap - using Carbon fallback")
            HotkeyManager.shared.registerHotkeys(action: hotkeyCallback)
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("✅ KeyboardInterceptor: Started - buffering Cmd key for RDP compatibility")
        }
        
        // Listen for shortcut changes and restart
        setupShortcutChangeListener()
    }
    
    // Reset internal state
    private func resetState() {
        isBuffering = false
        preventNextCmdRelease = false
        preventNextShiftRelease = false
        preventNextOptionRelease = false
        preventNextControlRelease = false
        bufferTimer?.cancel()
        bufferTimer = nil
        bufferedCmdEvent = nil
        bufferedShiftEvent = nil
    }
    
    /// Restart the interceptor (call when shortcut changes)
    func restart() {
        guard let callback = hotkeyCallback else { return }
        print("🔄 KeyboardInterceptor: Restarting due to shortcut change...")
        stop()
        start(hotkeyCallback: callback)
    }
    
    private func setupShortcutChangeListener() {
        // KeyboardShortcuts library notifies when shortcut changes
        // We use onKeyUp to detect when user finishes recording a new shortcut
        KeyboardShortcuts.onKeyUp(for: .openHistory) { [weak self] in
            // This fires when the shortcut is used, which is fine
            // But we need to detect when it CHANGES
        }
        
        // Alternative: observe UserDefaults for the shortcut key
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Check if our shortcut config changed
            self?.checkForShortcutChange()
        }
    }
    
    private var lastShortcutHash: Int = 0
    
    private func checkForShortcutChange() {
        if let shortcut = KeyboardShortcuts.getShortcut(for: .openHistory),
           let key = shortcut.key {
            let newHash = "\(key)\(shortcut.modifiers)".hashValue
            if lastShortcutHash != 0 && newHash != lastShortcutHash {
                print("🔄 Shortcut changed - restarting interceptor")
                restart()
            }
            lastShortcutHash = newHash
        }
    }
    
    /// Load the configured shortcut from KeyboardShortcuts library
    private func loadConfiguredShortcut() {
        if let shortcut = KeyboardShortcuts.getShortcut(for: .openHistory),
           let key = shortcut.key {
            // Map Key to CGKeyCode
            targetKeyCode = keyToCGKeyCode(key)
            
            // Check modifiers
            requiresCmd = shortcut.modifiers.contains(.command)
            requiresShift = shortcut.modifiers.contains(.shift)
            requiresOption = shortcut.modifiers.contains(.option)
            requiresControl = shortcut.modifiers.contains(.control)
            
            // Store hash for change detection
            lastShortcutHash = "\(key)\(shortcut.modifiers)".hashValue
            
            print("📋 Configured shortcut: key=\(key) cmd=\(requiresCmd) shift=\(requiresShift) opt=\(requiresOption) ctrl=\(requiresControl)")
        } else {
            // Default fallback
            targetKeyCode = 0x09 // V
            requiresCmd = true
            requiresShift = true
            lastShortcutHash = "v[command, shift]".hashValue
            print("📋 Using default shortcut: Cmd+Shift+V")
        }
    }
    
    /// Convert KeyboardShortcuts.Key to CGKeyCode
    private func keyToCGKeyCode(_ key: KeyboardShortcuts.Key) -> CGKeyCode {
        // Map common keys - add more as needed
        switch key {
        case .a: return 0x00
        case .b: return 0x0B
        case .c: return 0x08
        case .d: return 0x02
        case .e: return 0x0E
        case .f: return 0x03
        case .g: return 0x05
        case .h: return 0x04
        case .i: return 0x22
        case .j: return 0x26
        case .k: return 0x28
        case .l: return 0x25
        case .m: return 0x2E
        case .n: return 0x2D
        case .o: return 0x1F
        case .p: return 0x23
        case .q: return 0x0C
        case .r: return 0x0F
        case .s: return 0x01
        case .t: return 0x11
        case .u: return 0x20
        case .v: return 0x09
        case .w: return 0x0D
        case .x: return 0x07
        case .y: return 0x10
        case .z: return 0x06
        case .zero: return 0x1D
        case .one: return 0x12
        case .two: return 0x13
        case .three: return 0x14
        case .four: return 0x15
        case .five: return 0x17
        case .six: return 0x16
        case .seven: return 0x1A
        case .eight: return 0x1C
        case .nine: return 0x19
        default: return 0x09 // Default to V
        }
    }
    
    /// Stop intercepting
    func stop() {
        bufferTimer?.cancel()
        bufferTimer = nil
        bufferedCmdEvent = nil
        bufferedShiftEvent = nil
        
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        HotkeyManager.shared.unregisterHotkeys()
        print("🛑 KeyboardInterceptor: Stopped")
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Handle tap disabled/timeout
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        
        // Track modifier state from flags
        cmdDown = flags.contains(.maskCommand)
        shiftDown = flags.contains(.maskShift)
        optionDown = flags.contains(.maskAlternate)
        controlDown = flags.contains(.maskControl)
        
        // Handle flagsChanged (modifier key presses)
        if type == .flagsChanged {
            let isCmdKey = keyCode == leftCmdKeyCode || keyCode == rightCmdKeyCode
            let isShiftKey = keyCode == leftShiftKeyCode || keyCode == rightShiftKeyCode
            let isOptionKey = keyCode == leftOptionKeyCode || keyCode == rightOptionKeyCode
            let isControlKey = keyCode == leftControlKeyCode || keyCode == rightControlKeyCode
            
            // Cmd key released - Check for suppression
            if isCmdKey && !cmdDown {
                if preventNextCmdRelease {
                    preventNextCmdRelease = false
                    return nil
                }
                
                if isBuffering {
                    flushBuffer()
                }
                isBuffering = false
            }
            
            // Shift key released - Check for suppression
            if isShiftKey && !shiftDown {
                if preventNextShiftRelease {
                    preventNextShiftRelease = false
                    return nil
                }
            }
            
            // Option key released - Check for suppression
            if isOptionKey && !optionDown {
                if preventNextOptionRelease {
                    preventNextOptionRelease = false
                    return nil
                }
            }
            
            // Control key released - Check for suppression
            if isControlKey && !controlDown {
                if preventNextControlRelease {
                    preventNextControlRelease = false
                    return nil
                }
            }
            
            // Cmd key pressed down - start buffering
            if isCmdKey && cmdDown && !isBuffering {
                isBuffering = true
                bufferedCmdEvent = event.copy()
                startBufferTimer()
                return nil // Suppress Cmd from reaching other apps
            }
            
            // If we're buffering and other required modifiers are pressed, continue buffering
            if isBuffering {
                if isShiftKey && requiresShift {
                    bufferedShiftEvent = event.copy()
                    return nil // Suppress Shift too
                }
                // Also buffer other required modifiers if we supported them
            }
            
            return Unmanaged.passUnretained(event)
        }
        
        // Handle keyDown
        if type == .keyDown {
            // Target key pressed while buffering with required modifiers
            if keyCode == targetKeyCode && isBuffering && checkModifiersMatch() {
                print("🎯 Detected configured hotkey while buffering - triggering!")
                
                // Cancel buffer timer - we're consuming the combo
                bufferTimer?.cancel()
                bufferTimer = nil
                bufferedCmdEvent = nil
                bufferedShiftEvent = nil
                isBuffering = false
                
                // Set flags to suppress the REAL release of these keys
                if requiresCmd { preventNextCmdRelease = true }
                if requiresShift { preventNextShiftRelease = true }
                if requiresOption { preventNextOptionRelease = true }
                if requiresControl { preventNextControlRelease = true }
                
                // CRITICAL: Inject modifier key-up events to clean up RDP state
                // This ensures RoyalTSX/Windows doesn't think modifiers are still held
                injectModifierCleanup()
                
                // Trigger hotkey callback
                DispatchQueue.main.async { [weak self] in
                    self?.hotkeyCallback?()
                }
                
                // Suppress the key
                return nil
            }
            
            // Other key pressed while buffering - flush buffer and pass through
            if isBuffering {
                flushBuffer()
                isBuffering = false
            }
        }
        
        // Pass event through
        return Unmanaged.passUnretained(event)
    }
    
    /// Check if current modifiers match required modifiers
    private func checkModifiersMatch() -> Bool {
        if requiresCmd && !cmdDown { return false }
        if requiresShift && !shiftDown { return false }
        if requiresOption && !optionDown { return false }
        if requiresControl && !controlDown { return false }
        return true
    }
    
    private func startBufferTimer() {
        bufferTimer?.cancel()
        
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + bufferDuration)
        timer.setEventHandler { [weak self] in
            self?.flushBuffer()
            self?.isBuffering = false
        }
        timer.resume()
        bufferTimer = timer
    }
    
    private func flushBuffer() {
        // Release buffered events
        if let cmdEvent = bufferedCmdEvent {
            cmdEvent.post(tap: .cghidEventTap)
        }
        if let shiftEvent = bufferedShiftEvent {
            shiftEvent.post(tap: .cghidEventTap)
        }
        bufferedCmdEvent = nil
        bufferedShiftEvent = nil
        bufferTimer?.cancel()
        bufferTimer = nil
    }
    
    /// Inject modifier key-up events to clean up RDP modifier state
    /// This ensures RoyalTSX/Windows doesn't think modifiers are still held
    private func injectModifierCleanup() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Send Cmd Up (will be WinKey Up in RDP)
        if requiresCmd {
            let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: leftCmdKeyCode, keyDown: false)
            cmdUp?.flags = []
            cmdUp?.post(tap: .cghidEventTap)
        }
        
        // Send Shift Up
        if requiresShift {
            let shiftUp = CGEvent(keyboardEventSource: source, virtualKey: leftShiftKeyCode, keyDown: false)
            shiftUp?.flags = []
            shiftUp?.post(tap: .cghidEventTap)
        }
        
        // Send Option Up if needed
        if requiresOption {
            let optUp = CGEvent(keyboardEventSource: source, virtualKey: leftOptionKeyCode, keyDown: false)
            optUp?.flags = []
            optUp?.post(tap: .cghidEventTap)
        }
        
        // Send Control Up if needed
        if requiresControl {
            let ctrlUp = CGEvent(keyboardEventSource: source, virtualKey: leftControlKeyCode, keyDown: false)
            ctrlUp?.flags = []
            ctrlUp?.post(tap: .cghidEventTap)
        }
        
        print("🔓 Injected modifier key-up events for RDP cleanup")
    }
    
    deinit {
        stop()
    }
}

