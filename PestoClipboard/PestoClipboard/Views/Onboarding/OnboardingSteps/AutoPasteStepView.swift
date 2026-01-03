import SwiftUI

struct AutoPasteStepView: View {
    @Binding var pasteAutomatically: Bool
    @Binding var launchAtLogin: Bool
    @State private var hasAccessibilityPermission = AccessibilityHelper.hasPermission
    @State private var permissionCheckTimer: Timer?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text("Preferences")
                .font(.title2)
                .fontWeight(.bold)

            Text("Configure how Pesto Clipboard behaves.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                // Launch at Login toggle
                Toggle(isOn: $launchAtLogin) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Launch at login")
                            .font(.body)
                        Text("Start Pesto Clipboard when you log in")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onChange(of: launchAtLogin) { _, newValue in
                    LaunchAtLoginManager.setLaunchAtLogin(newValue)
                }

                // Auto-paste toggle
                Toggle(isOn: $pasteAutomatically) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Paste automatically")
                            .font(.body)
                        Text("Immediately paste after selecting an item")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onChange(of: pasteAutomatically) { _, newValue in
                    if newValue && !hasAccessibilityPermission {
                        // Open System Settings to Accessibility pane
                        AccessibilityHelper.openAccessibilitySettings()
                        startPermissionPolling()
                    } else {
                        stopPermissionPolling()
                    }
                }

                if pasteAutomatically && !hasAccessibilityPermission {
                    Button {
                        AccessibilityHelper.openAccessibilitySettings()
                        startPermissionPolling()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Accessibility permission required")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text("Click to open System Settings")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.forward.square")
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(32)
        .onAppear {
            hasAccessibilityPermission = AccessibilityHelper.hasPermission
            if pasteAutomatically && !hasAccessibilityPermission {
                startPermissionPolling()
            }
        }
        .onDisappear {
            stopPermissionPolling()
        }
    }

    private func startPermissionPolling() {
        stopPermissionPolling()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let newPermission = AccessibilityHelper.hasPermission
            if newPermission != hasAccessibilityPermission {
                hasAccessibilityPermission = newPermission
                if newPermission {
                    stopPermissionPolling()
                }
            }
        }
    }

    private func stopPermissionPolling() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }
}

#Preview {
    AutoPasteStepView(pasteAutomatically: .constant(false), launchAtLogin: .constant(false))
        .frame(width: 480, height: 460)
}
