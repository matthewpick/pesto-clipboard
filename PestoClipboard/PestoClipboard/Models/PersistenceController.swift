import CoreData
import os

struct PersistenceController {
    static let shared = PersistenceController()

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PestoClipboard",
        category: "PersistenceController"
    )

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // Create the managed object model programmatically
        let model = Self.createManagedObjectModel()
        container = NSPersistentContainer(name: "PestoClipboard", managedObjectModel: model)

        let description = container.persistentStoreDescriptions.first
        if inMemory {
            description?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Store in Application Support
            description?.url = Self.storeURL()
        }

        // Enable automatic lightweight migration (default for NSPersistentContainer,
        // but set explicitly so model changes don't surprise us).
        description?.shouldMigrateStoreAutomatically = true
        description?.shouldInferMappingModelAutomatically = true

        Self.loadStoreWithRecovery(container: container, inMemory: inMemory)

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Loads the persistent store, recovering from an unreadable/corrupt/incompatible store
    /// instead of crashing. Clipboard history is a disposable cache: if the store can't be opened
    /// (corruption, a leftover -wal/-shm after a hard quit, a failed migration, a missing external
    /// data file, etc.) we discard it and start fresh. If even a fresh store fails, we fall back to
    /// an in-memory store so the app still launches. This avoids the permanent crash-loop that a
    /// `fatalError` here would cause once a store gets into a bad state.
    private static func loadStoreWithRecovery(container: NSPersistentContainer, inMemory: Bool) {
        if let error = load(container) {
            logger.error("Failed to load Core Data store: \(error, privacy: .public)")

            // Don't destroy the in-memory store (used in previews/tests); just surface the failure.
            guard !inMemory,
                  let storeURL = container.persistentStoreDescriptions.first?.url,
                  storeURL.path != "/dev/null" else {
                logger.fault("In-memory store failed to load; continuing without recovery.")
                return
            }

            // Discard the unreadable store (removes .sqlite, -wal, -shm and external binary data).
            do {
                try container.persistentStoreCoordinator.destroyPersistentStore(
                    at: storeURL, type: .sqlite, options: nil
                )
                logger.notice("Discarded unreadable store; recreating a fresh one.")
            } catch {
                logger.error("destroyPersistentStore failed: \(error as NSError, privacy: .public); removing files manually.")
                removeStoreFiles(at: storeURL)
            }

            // Retry with a fresh store.
            if let retryError = load(container) {
                logger.fault("Recreated store still failed: \(retryError, privacy: .public). Falling back to in-memory store.")
                container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
                if let memError = load(container) {
                    logger.fault("In-memory fallback failed: \(memError, privacy: .public)")
                }
            }
        }
    }

    /// Loads the container's stores synchronously, returning the first load error (if any).
    private static func load(_ container: NSPersistentContainer) -> NSError? {
        var loadError: NSError?
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                loadError = error
            }
        }
        return loadError
    }

    /// Fallback cleanup if `destroyPersistentStore` can't remove the store itself.
    /// Removes the SQLite file, its -wal/-shm sidecars, and the external binary data directory.
    private static func removeStoreFiles(at storeURL: URL) {
        let fileManager = FileManager.default
        let supportDir = storeURL.deletingLastPathComponent()
            .appendingPathComponent(".\(storeURL.deletingPathExtension().lastPathComponent)_SUPPORT", isDirectory: true)
        let targets = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm"),
            supportDir
        ]
        for url in targets {
            try? fileManager.removeItem(at: url)
        }
    }

    private static func storeURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("PestoClipboard", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        return appFolder.appendingPathComponent("PestoClipboard.sqlite")
    }

    private static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // ClipboardItem entity
        let clipboardItemEntity = NSEntityDescription()
        clipboardItemEntity.name = "ClipboardItem"
        clipboardItemEntity.managedObjectClassName = "ClipboardItem"

        // ClipboardItemContent entity (for multi-format storage)
        let contentEntity = NSEntityDescription()
        contentEntity.name = "ClipboardItemContent"
        contentEntity.managedObjectClassName = "ClipboardItemContent"

        // Attributes for ClipboardItem
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = false

        let createdAtAttribute = NSAttributeDescription()
        createdAtAttribute.name = "createdAt"
        createdAtAttribute.attributeType = .dateAttributeType
        createdAtAttribute.isOptional = false

        let contentTypeAttribute = NSAttributeDescription()
        contentTypeAttribute.name = "contentType"
        contentTypeAttribute.attributeType = .stringAttributeType
        contentTypeAttribute.isOptional = false

        let contentHashAttribute = NSAttributeDescription()
        contentHashAttribute.name = "contentHash"
        contentHashAttribute.attributeType = .stringAttributeType
        contentHashAttribute.isOptional = false

        let textContentAttribute = NSAttributeDescription()
        textContentAttribute.name = "textContent"
        textContentAttribute.attributeType = .stringAttributeType
        textContentAttribute.isOptional = true

        let rtfDataAttribute = NSAttributeDescription()
        rtfDataAttribute.name = "rtfData"
        rtfDataAttribute.attributeType = .binaryDataAttributeType
        rtfDataAttribute.isOptional = true

        let imageDataAttribute = NSAttributeDescription()
        imageDataAttribute.name = "imageData"
        imageDataAttribute.attributeType = .binaryDataAttributeType
        imageDataAttribute.isOptional = true
        imageDataAttribute.allowsExternalBinaryDataStorage = true

        let thumbnailDataAttribute = NSAttributeDescription()
        thumbnailDataAttribute.name = "thumbnailData"
        thumbnailDataAttribute.attributeType = .binaryDataAttributeType
        thumbnailDataAttribute.isOptional = true

        let fileURLsAttribute = NSAttributeDescription()
        fileURLsAttribute.name = "fileURLsData"
        fileURLsAttribute.attributeType = .binaryDataAttributeType
        fileURLsAttribute.isOptional = true

        let isPinnedAttribute = NSAttributeDescription()
        isPinnedAttribute.name = "isPinned"
        isPinnedAttribute.attributeType = .booleanAttributeType
        isPinnedAttribute.isOptional = false
        isPinnedAttribute.defaultValue = false

        let totalSizeBytesAttribute = NSAttributeDescription()
        totalSizeBytesAttribute.name = "totalSizeBytes"
        totalSizeBytesAttribute.attributeType = .integer64AttributeType
        totalSizeBytesAttribute.isOptional = false
        totalSizeBytesAttribute.defaultValue = 0

        // Attributes for ClipboardItemContent
        let contentTypeAttr = NSAttributeDescription()
        contentTypeAttr.name = "type"
        contentTypeAttr.attributeType = .stringAttributeType
        contentTypeAttr.isOptional = false

        let contentValueAttr = NSAttributeDescription()
        contentValueAttr.name = "value"
        contentValueAttr.attributeType = .binaryDataAttributeType
        contentValueAttr.isOptional = true
        contentValueAttr.allowsExternalBinaryDataStorage = true

        let contentOrderAttr = NSAttributeDescription()
        contentOrderAttr.name = "order"
        contentOrderAttr.attributeType = .integer16AttributeType
        contentOrderAttr.isOptional = false
        contentOrderAttr.defaultValue = 0

        // Relationships
        let contentsRelationship = NSRelationshipDescription()
        contentsRelationship.name = "contents"
        contentsRelationship.destinationEntity = contentEntity
        contentsRelationship.isOptional = true
        contentsRelationship.deleteRule = .cascadeDeleteRule
        contentsRelationship.minCount = 0
        contentsRelationship.maxCount = 0  // To-many

        let itemRelationship = NSRelationshipDescription()
        itemRelationship.name = "item"
        itemRelationship.destinationEntity = clipboardItemEntity
        itemRelationship.isOptional = false
        itemRelationship.deleteRule = .nullifyDeleteRule
        itemRelationship.minCount = 1
        itemRelationship.maxCount = 1  // To-one

        // Set inverse relationships
        contentsRelationship.inverseRelationship = itemRelationship
        itemRelationship.inverseRelationship = contentsRelationship

        clipboardItemEntity.properties = [
            idAttribute,
            createdAtAttribute,
            contentTypeAttribute,
            contentHashAttribute,
            textContentAttribute,
            rtfDataAttribute,
            imageDataAttribute,
            thumbnailDataAttribute,
            fileURLsAttribute,
            isPinnedAttribute,
            totalSizeBytesAttribute,
            contentsRelationship
        ]

        contentEntity.properties = [
            contentTypeAttr,
            contentValueAttr,
            contentOrderAttr,
            itemRelationship
        ]

        model.entities = [clipboardItemEntity, contentEntity]

        return model
    }
}
