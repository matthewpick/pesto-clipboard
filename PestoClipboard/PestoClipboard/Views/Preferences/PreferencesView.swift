import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers

struct PreferencesView: View {
    @State private var selectedTab: PreferenceTab = .general

    enum PreferenceTab: String, CaseIterable {
        case general = "General"
        case ignore = "Ignore"
        case storage = "Storage"

        var icon: String {
            switch self {
            case .general: return "gearshape.fill"
            case .ignore: return "eye.slash.fill"
            case .storage: return "externaldrive.fill"
            }
        }

        var localizedName: String {
            switch self {
            case .general: return String(localized: "General")
            case .ignore: return String(localized: "Ignore")
            case .storage: return String(localized: "Storage")
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            List(PreferenceTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.localizedName, systemImage: tab.icon)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
            .listStyle(.sidebar)
            .frame(width: 180)

            Divider()

            // Detail view
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .ignore:
                    IgnoreSettingsView()
                case .storage:
                    StorageSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 450)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hotkey Section
                SettingsSection(title: "Keyboard Shortcut") {
                    HStack {
                        Text("Open Pesto Clipboard:")
                        KeyboardShortcuts.Recorder(for: .openHistory)
                        Spacer()
                    }
                }

                // Startup Section
                SettingsSection(title: "Startup") {
                    SettingsToggle(
                        title: "Launch at login",
                        subtitle: "Automatically start Pesto Clipboard when you log in",
                        isOn: $settings.launchAtLogin
                    )
                    .onChange(of: settings.launchAtLogin) { _, newValue in
                        LaunchAtLoginManager.setLaunchAtLogin(newValue)
                    }
                }

                // Behavior Section
                SettingsSection(title: "Behavior") {
                    SettingsToggle(
                        title: "Paste automatically",
                        subtitle: "Paste immediately after selecting an item",
                        isOn: $settings.pasteAutomatically
                    )
                }

                // Appearance Section
                SettingsSection(title: "Appearance") {
                    SettingsToggle(
                        title: "Transparent background",
                        subtitle: "Use a glass effect for the clipboard panel",
                        isOn: $settings.useTransparentBackground
                    )
                }

                // Setup Section
                SettingsSection(title: "Setup") {
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            NSApp.keyWindow?.close()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                OnboardingWindowController.shared.showOnboarding()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Run Setup Wizard")
                            }
                        }
                        .buttonStyle(.bordered)

                        Text("Re-run the initial setup wizard to configure basic settings.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Ignore Settings

struct IgnoreSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var showingAppPicker = false
    @State private var selectedApp: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsSection(title: "Ignored Applications") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Clipboard content from these applications will not be captured.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        // App list
                        VStack(spacing: 0) {
                            if settings.ignoredApps.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        Image(systemName: "app.dashed")
                                            .font(.system(size: 32))
                                            .foregroundStyle(.tertiary)
                                        Text("No ignored applications")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 32)
                                    Spacer()
                                }
                            } else {
                                ForEach(settings.ignoredApps, id: \.self) { app in
                                    AppRow(path: app, isSelected: selectedApp == app)
                                        .onTapGesture {
                                            selectedApp = selectedApp == app ? nil : app
                                        }
                                }
                                Spacer()
                            }
                        }
                        .frame(minHeight: 150, alignment: .top)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )

                        // Buttons
                        HStack(spacing: 8) {
                            Button {
                                showingAppPicker = true
                            } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                if let selected = selectedApp {
                                    settings.ignoredApps.removeAll { $0 == selected }
                                    selectedApp = nil
                                }
                            } label: {
                                Image(systemName: "minus")
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedApp == nil)

                            Spacer()
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .fileImporter(
            isPresented: $showingAppPicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                if !settings.ignoredApps.contains(url.path) {
                    settings.ignoredApps.append(url.path)
                }
            }
        }
    }
}

struct AppRow: View {
    let path: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .frame(width: 24, height: 24)

            Text(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Storage Settings

struct StorageSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var showingClearConfirmation = false
    @State private var includeStarred = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Capture Types Section
                SettingsSection(title: "Capture Types") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose what types of content to capture from the clipboard.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            SettingsCheckbox(title: "Text", icon: "doc.text.fill", isOn: $settings.captureText)
                            SettingsCheckbox(title: "Images", icon: "photo.fill", isOn: $settings.captureImages)
                            SettingsCheckbox(title: "Files", icon: "folder.fill", isOn: $settings.captureFiles)
                        }

                        Divider()
                            .padding(.vertical, 4)

                        Toggle(isOn: $settings.ignoreRemoteClipboard) {
                            HStack(spacing: 8) {
                                Image(systemName: "laptopcomputer.and.iphone")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text("Ignore clipboard from other devices")
                            }
                        }
                        .toggleStyle(.checkbox)

                        Text("When enabled, items copied on other Macs or iOS devices via Universal Clipboard will not be saved.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                // History Section
                SettingsSection(title: "History") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Maximum items:")
                                .frame(width: 120, alignment: .leading)

                            TextField("", value: $settings.historyLimit, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)

                            Stepper("", value: $settings.historyLimit, in: Constants.historyLimitRange, step: Constants.historyLimitStep)
                                .labelsHidden()

                            Text("items")
                                .foregroundStyle(.secondary)

                            Spacer()
                        }

                        HStack {
                            Text("Sort by:")
                                .frame(width: 120, alignment: .leading)

                            Picker("", selection: $settings.sortOrder) {
                                ForEach(SettingsManager.SortOrder.allCases, id: \.self) { order in
                                    Text(order.localizedName).tag(order)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)

                            Spacer()
                        }
                    }
                }

                // Danger Zone
                SettingsSection(title: "Danger Zone") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Clearing history cannot be undone.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button(role: .destructive) {
                            showingClearConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Clear All History")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .confirmationDialog("Clear History", isPresented: $showingClearConfirmation) {
            Button("Clear History (Keep Starred)", role: .destructive) {
                settings.clearHistory(includeStarred: false)
            }
            Button("Clear Everything (Including Starred)", role: .destructive) {
                settings.clearHistory(includeStarred: true)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to clear your clipboard history?")
        }
    }
}

// MARK: - Reusable Components

struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            content
        }
    }
}

struct SettingsToggle: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
    }
}

struct SettingsCheckbox: View {
    let title: LocalizedStringKey
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 20)
                    .foregroundStyle(.secondary)
                Text(title)
            }
        }
        .toggleStyle(.checkbox)
    }
}

#Preview {
    PreferencesView()
}
