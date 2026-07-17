import SwiftUI
import SwiftData
import Photos
import PhotosUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var store = EntryStore()
    @State private var todayEntry: DailyEntry?
    @State private var thumbnail: UIImage?
    @State private var livePhoto: PHLivePhoto?
    @State private var isPlayingLive = false
    @State private var showCamera = false

    private var todayKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(formattedDate())
                        .font(.subheadline).foregroundStyle(.white.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    if thumbnail != nil || livePhoto != nil {
                        ZStack(alignment: .topTrailing) {
                            if let lp = livePhoto {
                                LivePhotoCardView(livePhoto: lp, isPlaying: $isPlayingLive)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .onLongPressGesture(minimumDuration: 0.3) {
                                        isPlayingLive = true
                                    }
                            } else if let img = thumbnail {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            if livePhoto != nil {
                                Image(systemName: "livephoto")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .padding(10)
                            }
                        }
                        .padding(.horizontal)

                        Button("重新拍摄") { showCamera = true }
                            .font(.subheadline).foregroundStyle(.white.opacity(0.5))
                    } else {
                        Button { showCamera = true } label: {
                            VStack(spacing: 16) {
                                Image(systemName: "camera.fill").font(.system(size: 48))
                                Text("记录今天").font(.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(3.0 / 4.0, contentMode: .fit)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .background(Color.black)
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
              let asset = await store.restoreIfNeeded(entry: entry, context: context) else {
            thumbnail = nil; livePhoto = nil; return
        }

        // Load static thumbnail always (fallback)
        let imgOpts = PHImageRequestOptions()
        imgOpts.deliveryMode = .opportunistic
        imgOpts.isNetworkAccessAllowed = false
        thumbnail = await withCheckedContinuation { cont in
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset, targetSize: CGSize(width: 400, height: 800),
                contentMode: .aspectFill, options: imgOpts
            ) { img, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded, !resumed else { return }
                resumed = true
                cont.resume(returning: img)
            }
        }

        // Load Live Photo if available
        if store.isLivePhoto(asset: asset) {
            let liveOpts = PHLivePhotoRequestOptions()
            liveOpts.deliveryMode = .opportunistic
            liveOpts.isNetworkAccessAllowed = false
            livePhoto = await withCheckedContinuation { cont in
                var resumed = false
                PHImageManager.default().requestLivePhoto(
                    for: asset,
                    targetSize: CGSize(width: 800, height: 1067),
                    contentMode: .aspectFill,
                    options: liveOpts
                ) { photo, info in
                    let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    guard !isDegraded, !resumed else { return }
                    resumed = true
                    cont.resume(returning: photo)
                }
            }
        } else {
            livePhoto = nil
        }

        NotificationManager.shared.cancelTodayReminder()
    }

    private func savePhoto(imageData: Data, movieURL: URL?) async {
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if authStatus != .authorized && authStatus != .limited {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            if status != .authorized && status != .limited { return }
        }
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

struct LivePhotoCardView: UIViewRepresentable {
    let livePhoto: PHLivePhoto
    @Binding var isPlaying: Bool

    func makeUIView(context: Context) -> PHLivePhotoView {
        let v = PHLivePhotoView()
        v.livePhoto = livePhoto
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.delegate = context.coordinator
        return v
    }

    func updateUIView(_ v: PHLivePhotoView, context: Context) {
        v.livePhoto = livePhoto
        if isPlaying { v.startPlayback(with: .full) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(isPlaying: $isPlaying) }

    class Coordinator: NSObject, PHLivePhotoViewDelegate {
        @Binding var isPlaying: Bool
        init(isPlaying: Binding<Bool>) { _isPlaying = isPlaying }

        func livePhotoView(_ livePhotoView: PHLivePhotoView,
                           didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
            isPlaying = false
        }
    }
}
