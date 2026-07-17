import SwiftUI
import SwiftData

@main
struct EverydayCountsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: DailyEntry.self)
        }
    }
}
