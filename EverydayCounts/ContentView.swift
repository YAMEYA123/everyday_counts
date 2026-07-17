import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("今天", systemImage: "camera.fill") }
            TimelineView()
                .tabItem { Label("时间线", systemImage: "calendar") }
            ReviewView()
                .tabItem { Label("回顾", systemImage: "film") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }
}
