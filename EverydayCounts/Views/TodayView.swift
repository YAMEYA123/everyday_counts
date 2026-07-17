import SwiftUI
import SwiftData
import Photos

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var store = EntryStore()
    @State private var todayEntry: DailyEntry?
    @State private var thumbnail: UIImage?
    @State private var showCamera = false

    private var todayKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable().scaledToFill().ignoresSafeArea()
                        .overlay(Color.black.opacity(0.15))
                    VStack {
                        Spacer()
                        Button("重新拍摄") { showCamera = true }
                            .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                            .padding(.bottom, 120)
                    }
                } else {
                    VStack(spacing: 24) {
                        Text(formattedDate())
                            .font(.title3).foregroundStyle(.white.opacity(0.5))
                        Button { showCamera = true } label: {
                            VStack(spacing: 12) {
                                Image(systemName: "camera.fill").font(.system(size: 44))
                                Text("记录今天").font(.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(width: 160, height: 160)
                            .background(.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        }
                    }
                }
            }
            .navigationTitle("今天")
            .navigationBarTitleDisplayMode(.large)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { imageData, movieURL in
                showCamera = false
                Task { await savePhoto(imageData: imageData, movieURL: movieURL) }
            }
        }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await load() }
        }
    }

    private func load() async {
        todayEntry = store.entry(for: todayKey, context: context)
        guard let entry = todayEntry,
              let asset = store.resolveAsset(identifier: entry.assetIdentifier) else {
            thumbnail = nil; return
        }
        thumbnail = await withCheckedContinuation { cont in
            PHImageManager.default().requestImage(
                for: asset, targetSize: CGSize(width: 400, height: 800),
                contentMode: .aspectFill, options: nil
            ) { img, _ in cont.resume(returning: img) }
        }
        NotificationManager.shared.cancelTodayReminder()
    }

    private func savePhoto(imageData: Data, movieURL: URL) async {
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard authStatus == .authorized ||
              (await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized) else { return }
        do {
            _ = try await store.saveLivePhoto(
                imageData: imageData, videoURL: movieURL, date: todayKey, context: context
            )
            await load()
        } catch { print("Save error:", error) }
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: Date())
    }
}
