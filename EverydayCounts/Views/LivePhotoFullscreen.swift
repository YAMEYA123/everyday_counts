import SwiftData
import SwiftUI
import Photos
import UIKit

struct LivePhotoFullscreen: View {
    let entry: DailyEntry
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = EntryStore()
    @State private var liveMovieURL: URL?
    @State private var thumbnail: UIImage?
    @State private var sketchImage: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if entry.kind == .photo {
                if let movieURL = liveMovieURL {
                    LivePhotoMovieView(
                        url: movieURL,
                        videoGravity: .resizeAspect,
                        autoplay: true
                    )
                    .ignoresSafeArea()
                } else if let image = thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                } else {
                    ProgressView().tint(.white)
                }
            } else if entry.kind == .text {
                VStack(alignment: .leading, spacing: 8) {
                    Text("文字记录")
                        .font(.headline).foregroundStyle(.white.opacity(0.6))
                    Text(entry.noteText ?? "")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if entry.kind == .sketch {
                if let image = sketchImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                } else {
                    ProgressView().tint(.white)
                }
            }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                    }
                    Spacer()
                }
                Spacer()
                Text(entry.date)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 40)
            }
        }
        .task { await load() }
    }

    private func load() async {
        switch entry.kind {
        case .photo:
            guard !entry.assetIdentifier.isEmpty else { return }
            guard let fetched = PHAsset.fetchAssets(
                withLocalIdentifiers: [entry.assetIdentifier], options: nil
            ).firstObject else { return }

            let asset = await store.restoreIfNeeded(entry: entry, context: context) ?? fetched

            if let movieURL = await store.pairedMovieURL(for: asset) {
                liveMovieURL = movieURL
                return
            }

            let opts = PHImageRequestOptions()
            opts.deliveryMode = .opportunistic
            opts.isNetworkAccessAllowed = false
            thumbnail = await withCheckedContinuation { cont in
                var resumed = false
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: UIScreen.main.bounds.size,
                    contentMode: .aspectFit,
                    options: opts
                ) { image, _ in
                    guard !resumed else { return }
                    resumed = true
                    cont.resume(returning: image)
                }
            }
        case .text:
            // 非照片内容直接显示文本即可
            break
        case .sketch:
            sketchImage = store.loadSketchImage(for: entry)
        }
    }
}
