import SwiftUI

struct ToolbarView: View {
    @Binding var plainTextMode: Bool
    @Binding var showStarredOnly: Bool
    @Binding var isPaused: Bool
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Star filter toggle
            ToolbarToggleButton(
                icon: showStarredOnly ? "star.fill" : "star",
                isActive: showStarredOnly,
                help: showStarredOnly ? "Showing starred only" : "Show starred only",
                activeColor: .yellow
            ) {
                showStarredOnly.toggle()
            }

            // Pause/resume capture toggle
            ToolbarToggleButton(
                icon: isPaused ? "play.fill" : "pause.fill",
                isActive: isPaused,
                help: isPaused ? "Resume capture" : "Pause capture",
                activeColor: .orange
            ) {
                isPaused.toggle()
            }

            // Plain text mode toggle
            ToolbarToggleButton(
                icon: "textformat",
                isActive: plainTextMode,
                help: plainTextMode ? "Plain text mode ON" : "Plain text mode OFF",
                activeColor: .accentColor
            ) {
                plainTextMode.toggle()
            }

            Spacer()

            // Delete button
            ToolbarButton(icon: "trash", help: "Delete (⌫)", tint: .red) {
                onDelete()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Toolbar Toggle Button

struct ToolbarToggleButton: View {
    let icon: String
    let isActive: Bool
    var help: String = ""
    var activeColor: Color = .accentColor
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isActive ? activeColor : (isHovered ? .primary : .secondary))
                .frame(width: 28, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? activeColor.opacity(0.2) : (isHovered ? Color.primary.opacity(0.1) : Color.clear))
                }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help(help)
    }
}

// MARK: - Toolbar Icon Button

struct ToolbarButton: View {
    let icon: String
    var help: String = ""
    var tint: Color = .secondary
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isHovered ? tint : .secondary)
                .frame(width: 28, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
                }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help(help)
    }
}

#Preview {
    ToolbarView(
        plainTextMode: .constant(false),
        showStarredOnly: .constant(false),
        isPaused: .constant(false),
        onDelete: {}
    )
    .frame(width: 320)
    .background(.ultraThinMaterial)
}
