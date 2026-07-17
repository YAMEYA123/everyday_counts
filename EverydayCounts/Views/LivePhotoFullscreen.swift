import SwiftUI
import Photos
import PhotosUI

struct LivePhotoFullscreen: View {
    let entry: DailyEntry
    @Environment(\.dismiss) private var dismiss
    @State private var livePhoto: PHLivePhoto?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let lp = livePhoto {
                LivePhotoView(livePhoto: lp).ignoresSafeArea()
            } else {
                ProgressView().tint(.white)
            }
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.title2).foregroundStyle(.white).padding()
                    }
                    Spacer()
                }
                Spacer()
                Text(entry.date).font(.caption).foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 40)
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [entry.assetIdentifier], options: nil
        ).firstObject else { return }
        livePhoto = await withCheckedContinuation { cont in
            PHImageManager.default().requestLivePhoto(
                for: asset, targetSize: UIScreen.main.bounds.size,
                contentMode: .aspectFit, options: nil
            ) { photo, _ in cont.resume(returning: photo) }
        }
    }
}

struct LivePhotoView: UIViewRepresentable {
    let livePhoto: PHLivePhoto
    func makeUIView(context: Context) -> PHLivePhotoView {
        let v = PHLivePhotoView()
        v.livePhoto = livePhoto
        v.contentMode = .scaleAspectFit
        return v
    }
    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        uiView.livePhoto = livePhoto
    }
}
