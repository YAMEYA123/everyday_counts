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
    @State private var showCaptionSheet = false
    @State private var captionDraft = ""
    @State private var showDeleteCaptionConfirm = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                } else if let image = thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                if entry.kind == .photo || entry.kind == .sketch {
                    captionPanel
                }
                Text(entry.date)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await load() }
        .sheet(isPresented: $showCaptionSheet) {
            TextNoteSheet(
                isPresented: $showCaptionSheet,
                text: $captionDraft,
                title: "今天的一句话"
            ) { text in
                saveCaption(text)
            } onCancel: {
                captionDraft = ""
            }
        }
        .confirmationDialog(
            "删除这句说明？",
            isPresented: $showDeleteCaptionConfirm,
            titleVisibility: .visible
        ) {
            Button("删除说明", role: .destructive) {
                saveCaption(nil)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("照片和当天记录不会受到影响")
        }
        .alert("保存失败", isPresented: $showSaveError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
    }

    private var captionPanel: some View {
        CaptionCardView(
            caption: entry.noteText,
            onEdit: {
                captionDraft = entry.noteText ?? ""
                showCaptionSheet = true
            },
            onDelete: { showDeleteCaptionConfirm = true }
        )
        .padding(.horizontal, 16)
    }

    private func load() async {
        switch entry.kind {
        case .photo:
            let asset: PHAsset?
            if let resolved = store.resolveAsset(identifier: entry.assetIdentifier) {
                asset = resolved
            } else {
                asset = await store.restoreIfNeeded(entry: entry, context: context)
            }
            guard let asset else { return }

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

    private func saveCaption(_ text: String?) {
        do {
            try store.updateCaption(text, for: entry.date, context: context)
            captionDraft = ""
        } catch {
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }
}

struct TimelineDetailPager: View {
    let entries: [DailyEntry]
    let initialIndex: Int
    @State private var selectedIndex: Int

    init(entries: [DailyEntry], initialIndex: Int) {
        self.entries = entries
        self.initialIndex = initialIndex
        _selectedIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            if entries.indices.contains(selectedIndex) {
                LivePhotoFullscreen(entry: entries[selectedIndex])
                    .id(entries[selectedIndex].date)
            } else {
                Color.black.ignoresSafeArea()
            }

        }
        .background(Color.black)
        .ignoresSafeArea()
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < 0, selectedIndex < entries.count - 1 {
                        selectedIndex += 1
                    } else if value.translation.width > 0, selectedIndex > 0 {
                        selectedIndex -= 1
                    }
                }
        )
    }
}
