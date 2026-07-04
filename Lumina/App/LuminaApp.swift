import SwiftUI
import SwiftData

@main
struct LuminaApp: App {
    /// One container for the whole app (CloudKit-backed).
    let container = PersistenceController.makeContainer()

    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(\.mediaStore, MediaStore.shared)
                .tint(LuminaColors.textPrimary)
                .preferredColorScheme(.dark)   // dark-mode-first
        }
        .modelContainer(container)
    }
}
