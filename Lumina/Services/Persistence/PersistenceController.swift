import Foundation
import SwiftData

/// Builds the app's `ModelContainer`. Local-first with iCloud sync via a
/// CloudKit-backed configuration.
///
/// CloudKit requirements (already satisfied by the models): every attribute has
/// a default or is optional, all relationships are optional, no `.unique`
/// constraints. Enable the iCloud + CloudKit capability in Xcode with container
/// `iCloud.com.lumina.app` (see project.yml entitlements).
enum PersistenceController {

    static let schema = Schema([
        Subject.self,
        Topic.self,
        ContentItem.self,
        Attachment.self,
        Tag.self,
        ChatThread.self,
        ChatMessage.self,
    ])

    /// The production container (private CloudKit DB).
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic   // ← iCloud sync
            )
        }
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // In development, fall back to a local-only store so a missing
            // iCloud entitlement doesn't hard-crash the app.
            let local = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
            return (try? ModelContainer(for: schema, configurations: [local]))
                ?? { fatalError("Could not create ModelContainer: \(error)") }()
        }
    }

    /// An in-memory container seeded with sample data for previews.
    @MainActor static func preview() -> ModelContainer {
        let container = makeContainer(inMemory: true)
        SampleData.seed(into: container.mainContext)
        return container
    }
}
