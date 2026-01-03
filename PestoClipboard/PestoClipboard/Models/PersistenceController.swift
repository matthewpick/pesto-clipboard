import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // Create the managed object model programmatically
        let model = Self.createManagedObjectModel()
        container = NSPersistentContainer(name: "PestoClipboard", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Store in Application Support
            let storeURL = Self.storeURL()
            container.persistentStoreDescriptions.first?.url = storeURL
        }

        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                fatalError("Failed to load Core Data store: \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
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

        // Attributes
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
            isPinnedAttribute
        ]

        model.entities = [clipboardItemEntity]

        return model
    }
}
