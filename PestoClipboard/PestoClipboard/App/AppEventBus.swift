import Combine
import Foundation

// MARK: - App Events

enum AppEvent {
    case showHistoryPanel
    case hideHistoryPanel
    case openHistoryPanel
    case deleteSelectedItem
}

// MARK: - App Event Bus

final class AppEventBus {
    static let shared = AppEventBus()

    private let subject = PassthroughSubject<AppEvent, Never>()

    var publisher: AnyPublisher<AppEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    private init() {}

    func send(_ event: AppEvent) {
        subject.send(event)
    }

    func publisher(for event: AppEvent) -> AnyPublisher<Void, Never> {
        subject
            .filter { $0 == event }
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}

// MARK: - Convenience Extensions

extension AppEventBus {
    func showHistoryPanel() {
        send(.showHistoryPanel)
    }

    func hideHistoryPanel() {
        send(.hideHistoryPanel)
    }

    func openHistoryPanel() {
        send(.openHistoryPanel)
    }

    func deleteSelectedItem() {
        send(.deleteSelectedItem)
    }
}
