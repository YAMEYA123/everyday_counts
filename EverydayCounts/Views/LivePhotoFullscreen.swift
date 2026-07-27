import SwiftData
import SwiftUI
import Photos

struct LivePhotoFullscreen: View {
    let entry: DailyEntry
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = EntryStore()
    @State private var liveMovieURL: URL?
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let movieURL = liveMovieURL {
                LivePhotoMovieView(
                    url: movieURL,
                    videoGravity: .resizeAspectFit,
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
    }
}
