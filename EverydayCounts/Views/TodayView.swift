import SwiftUI
import SwiftData
import Photos
import PhotosUI
import AVFoundation
import PencilKit

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var store = EntryStore()
    @State private var todayEntry: DailyEntry?
    @State private var thumbnail: UIImage?
    @State private var liveMovieURL: URL?
    @State private var playTrigger = 0
    @State private var showCamera = false
    @State private var showRetakeConfirm = false
    @State private var streak = 0
    @State private var noteDraft = ""
    @State private var showTextSheet = false
    @State private var showSketchSheet = false
    @State private var sketchDrawing = PKDrawing()
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @AppStorage("hasShownLiveHint") private var hasShownLiveHint = false

    private var todayKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
    private var canEditToday: Bool { store.canEdit(date: todayKey, now: Date()) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Text(formattedDate())
                            .font(.subheadline).foregroundStyle(.white.opacity(0.4))
                        Spacer()
                        if streak > 0 {
                            HStack(spacing: 4) {
                                Text("✦")
                                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
                                Text("连续 \(streak) 天")
                                    .font(.subheadline).foregroundStyle(.white.opacity(0.55))
                            }
                        }
                    }
                .padding(.horizontal)

                    if let entry = todayEntry {
                        ZStack(alignment: .topTrailing) {
                            if entry.kind == .photo {
                                if let movieURL = liveMovieURL {
                                    LivePhotoMovieView(
                                        url: movieURL,
                                        videoGravity: .resizeAspectFill,
                                        playTrigger: playTrigger
                                    )
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .onLongPressGesture(minimumDuration: 0.3) {
                                        playTrigger += 1
                                        hasShownLiveHint = true
                                    }
                                    if !hasShownLiveHint {
                                        Text("长按体验 Live Photo ✦")
                                            .font(.caption).foregroundStyle(.white.opacity(0.35))
                                    }
                                } else if let img = thumbnail {
                                    Image(uiImage: img)
                                        .resizable().scaledToFill()
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            } else if entry.kind == .text {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("文字笔记")
                                        .font(.caption).foregroundStyle(.white.opacity(0.6))
                                    Text(entry.noteText ?? "")
                                        .font(.title3)
                                        .foregroundStyle(.white.opacity(0.95))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .lineLimit(8)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            } else if entry.kind == .sketch, let img = thumbnail {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            if entry.kind == .photo && liveMovieURL != nil {
                                Image(systemName: "livephoto")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .padding(10)
                            }
                            if entry.kind == .text {
                                Text("✎")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(10)
                            }
                            if entry.kind == .sketch {
                                Image(systemName: "paintbrush.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(10)
                            }
                        }
                        .padding(.horizontal)
                        if canEditToday {
                            if entry.kind == .photo {
                                HStack(spacing: 18) {
                                    Button("重新拍摄") { showRetakeConfirm = true }
                                    PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                                        Text("从相册替换")
                                    }
                                }
                                .font(.subheadline).foregroundStyle(.white.opacity(0.4))
                                .confirmationDialog("今天的照片将被替换", isPresented: $showRetakeConfirm, titleVisibility: .visible) {
                                    Button("确定重拍", role: .destructive) { showCamera = true }
                                    Button("取消", role: .cancel) {}
                                } message: {
                                    Text("每天只有一次机会，确定要重拍吗？")
                                }
                            } else {
                                Button("重写内容") { showRetakeConfirm = true }
                                    .font(.subheadline).foregroundStyle(.white.opacity(0.4))
                                    .confirmationDialog("今天的记录将被替换", isPresented: $showRetakeConfirm, titleVisibility: .visible) {
                                        Button("重拍照片", role: .destructive) { showCamera = true }
                                        Button("从相册选择") { selectedPhoto = nil; showPhotoPicker = true }
                                        Button("改为文字") { showTextSheet = true }
                                        Button("改为白板") { showSketchSheet = true; sketchDrawing = PKDrawing() }
                                        Button("取消", role: .cancel) {}
                                    } message: {
                                        Text("每天只能保留一个内容，确定要替换吗？")
                                    }
                            }
                        }
                    } else if canEditToday {
                        VStack(spacing: 12) {
                            Button { showCamera = true } label: {
                                VStack(spacing: 16) {
                                    Image(systemName: "camera.fill").font(.system(size: 48))
                                    Text("拍照记录").font(.headline)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal)
                            }

                            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                                HStack { Image(systemName: "photo.on.rectangle"); Text("从相册选择图片") }
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.horizontal)
                            }

                            Button { showTextSheet = true } label: {
                                HStack { Image(systemName: "text.alignleft"); Text("写文字补记") }
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.horizontal)
                            }
                            Button { showSketchSheet = true; sketchDrawing = PKDrawing() } label: {
                                HStack { Image(systemName: "paintbrush.fill"); Text("白板补记") }
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.horizontal)
                            }
                        }
                    } else {
                        Text("今天已截止，当前时间已过编辑窗口")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.4))
                            .padding(.horizontal)
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
                Task { await savePhoto(imageData: imageData, movieURL: movieURL, targetDate: todayKey) }
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                await saveSelectedPhoto(item, targetDate: todayKey)
                selectedPhoto = nil
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .sheet(isPresented: $showTextSheet) {
            TextNoteSheet(isPresented: $showTextSheet, text: $noteDraft) { text in
                noteDraft = text
                saveText(targetDate: todayKey)
            } onCancel: { noteDraft = "" }
        }
        .sheet(isPresented: $showSketchSheet) {
            SketchBoardSheet(drawing: $sketchDrawing) { png in
                showSketchSheet = false
                saveSketch(png: png, targetDate: todayKey)
            } onCancel: { sketchDrawing = PKDrawing(); showSketchSheet = false }
        }
        .alert("保存失败", isPresented: $showSaveError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await load() }
        }
    }

    private func load() async {
        store.rebuildEntriesFromAlbum(context: context)
        todayEntry = store.entry(for: todayKey, context: context)
        guard let entry = todayEntry else {
            thumbnail = nil; liveMovieURL = nil
            NotificationManager.shared.scheduleDailyReminder()
            return
        }
        switch entry.kind {
        case .photo:
            guard let asset = await store.restoreIfNeeded(entry: entry, context: context) else {
                thumbnail = nil; liveMovieURL = nil; break
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

            if store.isLivePhoto(asset: asset) {
                liveMovieURL = await store.pairedMovieURL(for: asset)
            } else {
                liveMovieURL = nil
            }
        case .text:
            liveMovieURL = nil
            thumbnail = nil
        case .sketch:
            liveMovieURL = nil
            thumbnail = store.loadSketchImage(for: entry)
        }

        streak = store.currentStreak(context: context)
        NotificationManager.shared.cancelTodayReminder()
    }

    private func savePhoto(imageData: Data, movieURL: URL?, targetDate: String) async {
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if authStatus != .authorized && authStatus != .limited {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            if status != .authorized && status != .limited { return }
        }
        do {
            _ = try await store.saveLivePhoto(
                imageData: imageData, videoURL: movieURL, date: targetDate, context: context
            )
            await load()
        } catch {
            saveErrorMessage = error.localizedDescription
            showSaveError = true
            print("Save error:", error)
        }
    }

    private func saveSelectedPhoto(_ item: PhotosPickerItem, targetDate: String) async {
        do {
            guard let imageData = try await item.loadTransferable(type: Data.self) else {
                throw NSError(domain: "EverydayCounts", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法读取所选图片"])
            }
            _ = try await store.saveImage(imageData: imageData, date: targetDate, context: context)
            await load()
        } catch {
            saveErrorMessage = error.localizedDescription
            showSaveError = true
            print("Image upload error:", error)
        }
    }

    private func saveText(targetDate: String) {
        let text = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.saveText(text, date: targetDate, context: context)
        noteDraft = ""
        Task { await load() }
    }

    private func saveSketch(png: Data, targetDate: String) {
        do {
            try store.saveSketch(png, date: targetDate, context: context)
            sketchDrawing = PKDrawing()
            Task { await load() }
        } catch { print("Save sketch error:", error) }
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: Date())
    }
}

struct TextNoteSheet: View {
    @Binding var isPresented: Bool
    @Binding var text: String
    var onSave: (String) -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15))
                    )
                    .frame(minHeight: 220)
                HStack {
                    Button("取消") { onCancel(); isPresented = false }
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Button("保存") {
                        onSave(text)
                        isPresented = false
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.top, 4)
            }
            .padding()
            .background(Color.black)
            .navigationTitle("写下今天")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SketchBoardSheet: View {
    @Binding var drawing: PKDrawing
    var onSavePNG: (Data) -> Void
    var onCancel: () -> Void

    init(drawing: Binding<PKDrawing>, onSave: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
        self._drawing = drawing
        self.onSavePNG = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                PencilCanvas(drawing: $drawing)
                    .background(Color.white.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.18))
                    )
                    .frame(minHeight: 300)

                HStack {
                    Button("清空") {
                        drawing = PKDrawing()
                    }
                    Spacer()
                    Button("取消") { onCancel() }
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 4)
            }
            .padding()
            .background(Color.black)
            .navigationTitle("白板补记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let img = drawing.image(
                            from: CGRect(x: 0, y: 0, width: 1080, height: 1440),
                            scale: UIScreen.main.scale
                        )
                        if let data = img.pngData() {
                            onSavePNG(data)
                        }
                    }
                    .disabled(drawing.strokes.isEmpty)
                }
            }
        }
    }
}

struct PencilCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .clear
        canvas.tool = PKInkingTool(.pen, color: .white, width: 4)
        canvas.alwaysBounceVertical = true
        canvas.allowsFingerDrawing = true
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: PencilCanvas
        init(_ parent: PencilCanvas) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}
