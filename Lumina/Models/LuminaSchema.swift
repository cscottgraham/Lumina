import Foundation
import SwiftData

// ═══════════════════════════════════════════════════════════════════════════
// LUMINA SCHEMA — VERSIONING & MIGRATION STRATEGY
// ═══════════════════════════════════════════════════════════════════════════
//
// Every @Model lives inside a numbered `VersionedSchema` namespace
// (`LuminaSchemaV1.Subject`, …) and the app refers to the *current* version
// through the typealiases below. That indirection is the whole migration
// story:
//
//   HOW TO EVOLVE THE SCHEMA (V1 → V2)
//   1. Freeze V1: never edit the classes inside `LuminaSchemaV1` again.
//   2. Copy the changed models into a new `enum LuminaSchemaV2: VersionedSchema`
//      (unchanged models can be re-declared or shared per Apple's sample).
//   3. Flip the typealiases below to the V2 types — all app code follows.
//   4. Append a stage to `LuminaMigrationPlan.stages`:
//        • `.lightweight(fromVersion:toVersion:)` — for additive changes
//          (new optional/defaulted attribute, new model, new relationship).
//          This covers the overwhelming majority of changes.
//        • `.custom(fromVersion:toVersion:willMigrate:didMigrate:)` — when
//          data must be rewritten (e.g. splitting a field, backfilling a
//          new required-with-default value from old data, de-duplicating).
//   5. Test: open a store created by a V1 build in the V2 build (keep old
//      TestFlight builds / a fixture .store file around for this).
//
//   CLOUDKIT RULES (this container syncs via CloudKit)
//   • CloudKit record types are ADDITIVE-ONLY once deployed to production:
//     you may add fields/models; you must never rename or delete deployed
//     ones — deprecate in place instead (stop reading, keep the property).
//   • All attributes need defaults or optionality; all relationships must be
//     optional; no `.unique` constraints (uniqueness is enforced in app code,
//     e.g. `TagStore`). Every model below obeys this.
//   • After changing the schema, run a Development-environment build so
//     CloudKit learns the new record layout, then promote the CloudKit
//     schema to Production in the dashboard BEFORE shipping the app update.
//   • Custom migration stages rewrite the LOCAL store; rewritten records
//     then sync outward like ordinary edits.
//
// ═══════════════════════════════════════════════════════════════════════════

enum LuminaSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Subject.self,
            Topic.self,
            ContentItem.self,
            Attachment.self,
            Tag.self,
            ChatThread.self,
            ChatMessage.self,
        ]
    }
    // The @Model classes are declared in `extension LuminaSchemaV1 { … }`
    // blocks, one file per model (Models/*.swift).
}

// MARK: - Current version — the only place app code should bind to a version.

typealias Subject     = LuminaSchemaV1.Subject
typealias Topic       = LuminaSchemaV1.Topic
typealias ContentItem = LuminaSchemaV1.ContentItem
typealias Attachment  = LuminaSchemaV1.Attachment
typealias Tag         = LuminaSchemaV1.Tag
typealias ChatThread  = LuminaSchemaV1.ChatThread
typealias ChatMessage = LuminaSchemaV1.ChatMessage

// MARK: - Migration plan

enum LuminaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [LuminaSchemaV1.self]
        // V2 ships as: [LuminaSchemaV1.self, LuminaSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        []
        // Example of a future custom stage (kept here as the template):
        //
        // static let migrateV1toV2 = MigrationStage.custom(
        //     fromVersion: LuminaSchemaV1.self,
        //     toVersion: LuminaSchemaV2.self,
        //     willMigrate: { context in
        //         // e.g. backfill: give every legacy item a captureMethod
        //         let items = try context.fetch(FetchDescriptor<LuminaSchemaV1.ContentItem>())
        //         // … mutate as needed …
        //         try context.save()
        //     },
        //     didMigrate: nil
        // )
    }
}
