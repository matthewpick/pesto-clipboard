import Testing
import CoreData
import Foundation
@testable import Pesto_Clipboard

/// Guards the upgrade path for users who already have a clipboard history on disk.
///
/// The expiration feature adds two attributes to the `ClipboardItem` entity. If that
/// change were not lightweight-migratable, `PersistenceController.loadStoreWithRecovery`
/// would discard the store on first launch and every existing user would lose their
/// history — so this builds a store with the pre-expiration model and reopens it with
/// the current one.
struct ExpirationMigrationTests {

    private static let addedAttributes = ["expiresAt", "expirationDuration"]

    /// The current model minus the expiration attributes, i.e. the shipped v0.3.5 shape.
    private func modelBeforeExpiration() -> NSManagedObjectModel {
        let model = PersistenceController.createManagedObjectModel().copy() as! NSManagedObjectModel
        for entity in model.entities where entity.name == "ClipboardItem" {
            entity.properties = entity.properties.filter {
                !Self.addedAttributes.contains($0.name)
            }
        }
        return model
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("PestoMigrationTest-\(UUID().uuidString).sqlite")
    }

    private func removeStore(at url: URL) {
        for path in [url.path, url.path + "-wal", url.path + "-shm"] {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    @Test func oldStoreOpensWithTheExpirationModel() throws {
        let storeURL = temporaryStoreURL()
        var openCoordinators: [NSPersistentStoreCoordinator] = []
        defer {
            // Close the store before deleting the file, or SQLite complains about
            // its vnode being unlinked while still in use.
            for coordinator in openCoordinators {
                for store in coordinator.persistentStores {
                    try? coordinator.remove(store)
                }
            }
            removeStore(at: storeURL)
        }

        // 1. Write an item using the pre-expiration model
        let oldModel = modelBeforeExpiration()
        #expect(oldModel.entitiesByName["ClipboardItem"]?.attributesByName["expiresAt"] == nil)

        let oldCoordinator = NSPersistentStoreCoordinator(managedObjectModel: oldModel)
        openCoordinators.append(oldCoordinator)
        try oldCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil
        )
        let oldContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        oldContext.persistentStoreCoordinator = oldCoordinator

        let itemID = UUID()
        try oldContext.performAndWait {
            let item = NSEntityDescription.insertNewObject(forEntityName: "ClipboardItem", into: oldContext)
            // Set through KVC: the typed accessors would touch attributes this model lacks.
            item.setValue(itemID, forKey: "id")
            item.setValue(Date(), forKey: "createdAt")
            item.setValue("text", forKey: "contentType")
            item.setValue("hash-from-old-version", forKey: "contentHash")
            item.setValue("History written before the update", forKey: "textContent")
            item.setValue(true, forKey: "isPinned")
            try oldContext.save()
        }
        for store in oldCoordinator.persistentStores {
            try oldCoordinator.remove(store)
        }

        // 2. Reopen the same file with the current model, as the app does on launch
        let newCoordinator = NSPersistentStoreCoordinator(
            managedObjectModel: PersistenceController.createManagedObjectModel()
        )
        openCoordinators.append(newCoordinator)
        try newCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true
            ]
        )
        let newContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        newContext.persistentStoreCoordinator = newCoordinator

        try newContext.performAndWait {
            let request = ClipboardItem.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", itemID as CVarArg)
            let migrated = try newContext.fetch(request)

            #expect(migrated.count == 1)
            let item = try #require(migrated.first)

            // Existing data survived
            #expect(item.textContent == "History written before the update")
            #expect(item.contentHash == "hash-from-old-version")
            #expect(item.isPinned)

            // And the new attributes default to "no expiration"
            #expect(item.expiresAt == nil)
            #expect(item.expirationDuration == 0)
            #expect(!item.hasExpiration)
            #expect(!item.isExpired())
            #expect(item.expirationOption == .never)
        }
    }
}
