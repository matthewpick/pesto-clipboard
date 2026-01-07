import SwiftUI

// MARK: - Header View

struct HeaderView: View {
    let itemCount: Int

    var body: some View {
        HStack {
            Text("Pesto Clipboard")
                .font(.system(size: 13, weight: .semibold))

            Text("(\(itemCount))")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No clipboard history")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Copy something to get started")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Search Empty State View

struct SearchEmptyStateView: View {
    let query: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No results found")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Text("No items matching \"\(query)\"")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Starred Empty State View

struct StarredEmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "star")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No starred items")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Star items to keep them safe")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
