import Testing
import CoreData
import Foundation
@testable import Pesto_Clipboard

@MainActor
struct ClipboardExpirationTests {

    // MARK: - Helpers

    func createManager() -> ClipboardHistoryManager {
        let persistenceController = PersistenceController(inMemory: true)
        return ClipboardHistoryManager(persistenceController: persistenceController)
    }

    /// Backdates an item's deadline so the sweep sees it as expired without waiting.
    func expire(_ item: ClipboardItem, in manager: ClipboardHistoryManager) {
        item.expiresAt = Date().addingTimeInterval(-1)
        try? manager.viewContext.save()
    }

    // MARK: - ExpirationOption

    @Test func optionDurations() {
        #expect(ExpirationOption.never.duration == nil)
        #expect(ExpirationOption.fiveMinutes.duration == 300)
        #expect(ExpirationOption.fifteenMinutes.duration == 900)
        #expect(ExpirationOption.oneHour.duration == 3600)
        #expect(ExpirationOption.sixHours.duration == 21600)
        #expect(ExpirationOption.oneDay.duration == 86400)
        #expect(ExpirationOption.sevenDays.duration == 604800)
    }

    @Test func optionRoundTripsThroughStoredDuration() {
        for option in ExpirationOption.allCases where option != .never {
            #expect(ExpirationOption(duration: option.duration!) == option)
        }
        // 0 and unknown values fall back to "never"
        #expect(ExpirationOption(duration: 0) == .never)
        #expect(ExpirationOption(duration: 42) == .never)
    }

    // MARK: - Setting an Expiration

    @Test func setExpirationStoresDurationAndDeadline() {
        let manager = createManager()
        manager.addTextItem("Temporary secret")
        let item = manager.items[0]

        manager.setExpiration(.oneHour, for: item)

        #expect(item.expirationDuration == 3600)
        #expect(item.expirationOption == .oneHour)
        #expect(item.hasExpiration)
        // Deadline is roughly an hour out
        let remaining = item.expiresAt!.timeIntervalSinceNow
        #expect(remaining > 3590 && remaining <= 3600)
        #expect(!item.isExpired())
    }

    @Test func neverClearsExpiration() {
        let manager = createManager()
        manager.addTextItem("Temporary secret")
        let item = manager.items[0]

        manager.setExpiration(.fiveMinutes, for: item)
        #expect(item.hasExpiration)

        manager.setExpiration(.never, for: item)

        #expect(item.expiresAt == nil)
        #expect(item.expirationDuration == 0)
        #expect(item.expirationOption == .never)
        #expect(!item.hasExpiration)
    }

    @Test func newItemsHaveNoExpirationByDefault() {
        let manager = createManager()
        manager.addTextItem("Plain item")

        let item = manager.items[0]
        #expect(!item.hasExpiration)
        #expect(item.expirationOption == .never)
        #expect(!item.isExpired())
    }

    // MARK: - Sweeping

    @Test func expiredItemIsHiddenFromFetchBeforeItIsDeleted() {
        let manager = createManager()
        manager.addTextItem("Disappearing")
        let item = manager.items[0]
        manager.setExpiration(.fiveMinutes, for: item)

        expire(item, in: manager)
        manager.fetchItems()

        // Still on disk, but never shown to the user
        #expect(manager.items.isEmpty)
        #expect(item.isExpired())
    }

    @Test func expiredItemIsHiddenFromSearch() {
        let manager = createManager()
        manager.addTextItem("Disappearing")
        let item = manager.items[0]
        manager.setExpiration(.fiveMinutes, for: item)

        expire(item, in: manager)
        manager.searchItems(query: "Disappearing")

        #expect(manager.items.isEmpty)
    }

    @Test func sweepDeletesExpiredItems() {
        let manager = createManager()
        manager.addTextItem("Disappearing")
        manager.addTextItem("Staying")
        let doomed = manager.items.first { $0.textContent == "Disappearing" }!
        manager.setExpiration(.fiveMinutes, for: doomed)

        expire(doomed, in: manager)
        let deleted = manager.deleteItemsPastExpiration()

        #expect(deleted == 1)
        #expect(manager.items.count == 1)
        #expect(manager.items[0].textContent == "Staying")
    }

    @Test func sweepLeavesItemsWhoseCountdownIsStillRunning() {
        let manager = createManager()
        manager.addTextItem("Still alive")
        manager.setExpiration(.oneHour, for: manager.items[0])

        let deleted = manager.deleteItemsPastExpiration()

        #expect(deleted == 0)
        #expect(manager.items.count == 1)
    }

    @Test func sweepIgnoresItemsWithoutExpiration() {
        let manager = createManager()
        manager.addTextItem("No countdown")

        let deleted = manager.deleteItemsPastExpiration()

        #expect(deleted == 0)
        #expect(manager.items.count == 1)
    }

    @Test func explicitExpirationBeatsStarring() {
        // The global auto-delete spares starred items, but a per-item countdown was
        // set on that item deliberately, so it must still fire.
        let manager = createManager()
        manager.addTextItem("Starred but temporary")
        let item = manager.items[0]
        manager.togglePin(item)
        manager.setExpiration(.fiveMinutes, for: item)
        #expect(item.isPinned)

        expire(item, in: manager)

        #expect(manager.deleteItemsPastExpiration() == 1)
        #expect(manager.items.isEmpty)
    }

    @Test func globalAutoDeleteStillSparesStarredItems() {
        let manager = createManager()
        manager.addTextItem("Starred, no countdown")
        manager.togglePin(manager.items[0])

        manager.deleteExpiredItems(olderThan: -1) // everything is "older" than a future cutoff

        #expect(manager.items.count == 1)
    }

    // MARK: - Re-arming

    @Test func copyingAnItemAgainRestartsItsCountdown() {
        let manager = createManager()
        manager.addTextItem("Recurring")
        let item = manager.items[0]
        manager.setExpiration(.oneHour, for: item)

        // Simulate a countdown that is nearly done
        item.expiresAt = Date().addingTimeInterval(5)
        try? manager.viewContext.save()

        manager.addTextItem("Recurring") // duplicate -> moveToTop

        #expect(manager.items.count == 1)
        let remaining = item.expiresAt!.timeIntervalSinceNow
        #expect(remaining > 3590 && remaining <= 3600)
    }

    @Test func editingTextRestartsCountdown() {
        let manager = createManager()
        manager.addTextItem("Before edit")
        let item = manager.items[0]
        manager.setExpiration(.oneHour, for: item)

        item.expiresAt = Date().addingTimeInterval(5)
        try? manager.viewContext.save()

        manager.updateTextContent(item, newText: "After edit")

        let remaining = item.expiresAt!.timeIntervalSinceNow
        #expect(remaining > 3590 && remaining <= 3600)
    }

    @Test func itemsWithoutExpirationAreNotArmedByReuse() {
        let manager = createManager()
        manager.addTextItem("Recurring")
        manager.addTextItem("Recurring")

        #expect(manager.items[0].expiresAt == nil)
        #expect(manager.items[0].expirationDuration == 0)
    }
}
