import SwiftUI
import SwiftData

@main
struct BlueskyModerationApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.indigo)
        }
        .modelContainer(for: BlueskyAccount.self)
    }
}
