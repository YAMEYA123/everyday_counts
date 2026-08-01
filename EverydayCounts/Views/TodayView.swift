import SwiftUI
import SwiftData
import Photos
import PhotosUI
import AVFoundation
import PencilKit
import UIKit

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
    @State private var showCaptionSheet = false
    @State private var captionDraft = ""
    @State private var showDeleteCaptionConfirm = false
    @AppStorage("hasShownLiveHint") private var hasShownLiveHint = false

    private var todayKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
    private var canEditToday: Bool { store.canEdit(date: todayKey, now: Date()) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack {
                        Text(formattedDate())
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.4))
                        Spacer()
                        if streak > 0 {
                            HStack(spacing: 5) {
                                Text("✦")
                                    .font(.system(size: 11))
                                Text("连续 \(streak) 天")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.white.opacity(0.55))
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
                                    if !hasShownLiveHint { Text("长按播放").font(.caption).foregroundStyle(.white.opacity(0.35)) }
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
                        if entry.kind == .photo || entry.kind == .sketch {
                            CaptionCardView(
                                caption: entry.noteText,
                                onEdit: {
                                    captionDraft = entry.noteText ?? ""
                                    showCaptionSheet = true
                                },
                                onDelete: { showDeleteCaptionConfirm = true }
                            )
                            .padding(.horizontal)
                            .confirmationDialog(
                                "删除这句说明？",
                                isPresented: $showDeleteCaptionConfirm,
                                titleVisibility: .visible
                            ) {
                                Button("删除说明", role: .destructive) {
                                    saveCaption(nil, targetDate: todayKey)
                                }
                                Button("取消", role: .cancel) {}
                            } message: {
                                Text("照片和当天记录不会受到影响")
                            }
                            .confirmationDialog(
                                "替换今天的记录？",
                                isPresented: $showRetakeConfirm,
                                titleVisibility: .visible
                            ) {
                                if entry.kind == .photo {
                                    Button("重拍照片", role: .destructive) { showCamera = true }
                                    Button("从相册选择") {
                                        selectedPhoto = nil
                                        showPhotoPicker = true
                                    }
                                } else {
                                    Button("重拍照片", role: .destructive) { showCamera = true }
                                    Button("改为文字") { showTextSheet = true }
                                    Button("改为白板") {
                                        showSketchSheet = true
                                        sketchDrawing = PKDrawing()
                                    }
                                }
                                Button("取消", role: .cancel) {}
                            } message: {
                                Text("今天的记录将被替换")
                            }
                        }
                        if canEditToday {
                            if entry.kind == .photo {
                                HStack(spacing: 0) {
                                    Button("重拍") { showRetakeConfirm = true }
                                        .frame(maxWidth: .infinity)
                                    Divider().frame(height: 16).overlay(Color.white.opacity(0.15))
                                    PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                                        Text("换一张")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.62))
                            } else if entry.kind == .sketch {
                                Button("替换") { showRetakeConfirm = true }
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.62))
                            }
                        }
                    } else if canEditToday {
                        VStack(spacing: 18) {
                            VStack(spacing: 10) {
                                Image(systemName: "circle.dashed")
                                    .font(.system(size: 30, weight: .light))
                                    .foregroundStyle(.white.opacity(0.75))
                                Text("记录今天")
                                    .font(.system(size: 20, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.92))
                                Text("一张照片，留住此刻")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .background(Color.white.opacity(0.045))
                            .clipShape(RoundedRectangle(cornerRadius: 18))

                            Button {
                                showCamera = true
                            } label: {
                                Label("拍一张", systemImage: "camera.fill")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.white)
                            .foregroundStyle(.black)

                            HStack(spacing: 0) {
                                PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                                    Label("从相册选", systemImage: "photo.on.rectangle")
                                }
                                .frame(maxWidth: .infinity)

                                Divider()
                                    .frame(height: 18)
                                    .overlay(Color.white.opacity(0.15))

                                Button {
                                    showTextSheet = true
                                } label: {
                                    Label("写一句", systemImage: "text.alignleft")
                                }
                                .frame(maxWidth: .infinity)

                                Divider()
                                    .frame(height: 18)
                                    .overlay(Color.white.opacity(0.15))

                                Button {
                                    showSketchSheet = true
                                    sketchDrawing = PKDrawing()
                                } label: {
                                    Label("画一笔", systemImage: "paintbrush.fill")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.58))
                        }
                        .padding(.horizontal)
                    } else {
                        Text("今天已封存")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.4))
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
            }
            .background(Color.black)
            .scrollIndicators(.hidden)
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
        .sheet(isPresented: $showCaptionSheet) {
            TextNoteSheet(
                isPresented: $showCaptionSheet,
                text: $captionDraft,
                title: "今天的一句话"
            ) { text in
                saveCaption(text, targetDate: todayKey)
            } onCancel: {
                captionDraft = ""
            }
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

    private func saveCaption(_ text: String?, targetDate: String) {
        do {
            try store.updateCaption(text, for: targetDate, context: context)
            captionDraft = ""
            Task { await load() }
        } catch {
            saveErrorMessage = error.localizedDescription
            showSaveError = true
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

struct CaptionCardView: View {
    let caption: String?
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var hasCaption: Bool {
        guard let caption else { return false }
        return !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if hasCaption, let caption {
                Text("“\(caption)”")
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, perform: onEdit)

                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 30, height: 30)
                }
                .padding(.top, 4)
                .padding(.trailing, 4)
            } else {
                Button(action: onEdit) {
                    Text("写一句")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
        }
        .background(hasCaption ? Color.white.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct TextNoteSheet: View {
    @Binding var isPresented: Bool
    @Binding var text: String
    var title = "写下今天"
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SketchBoardSheet: View {
    @Binding var drawing: PKDrawing
    var onSavePNG: (Data) -> Void
    var onCancel: () -> Void
    @State private var inkColor = Color.black
    @State private var brushSize: CGFloat = 5
    @State private var isErasing = false

    init(drawing: Binding<PKDrawing>, onSave: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
        self._drawing = drawing
        self.onSavePNG = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                PencilCanvas(
                    drawing: $drawing,
                    color: inkColor,
                    width: brushSize,
                    isErasing: isErasing
                )
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.18))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(minHeight: 360)

                HStack(spacing: 14) {
                    ColorPicker("画笔", selection: $inkColor, supportsOpacity: false)
                        .labelsHidden()
                        .disabled(isErasing)

                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                    Slider(value: $brushSize, in: 1...18, step: 1)
                    Image(systemName: "circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                HStack(spacing: 12) {
                    Button {
                        isErasing.toggle()
                    } label: {
                        Label(isErasing ? "关闭橡皮擦" : "橡皮擦", systemImage: isErasing ? "pencil" : "eraser")
                    }
                    .buttonStyle(.bordered)

                    Button("清空", systemImage: "trash") {
                        drawing = PKDrawing()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                Text("用一笔留下今天的痕迹")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.black)
            .navigationTitle("白板补记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let img = drawing.image(
                            from: CGRect(x: 0, y: 0, width: 1080, height: 1440),
                            scale: UIScreen.main.scale
                        )
                        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1080, height: 1440))
                        let composed = renderer.image { _ in
                            UIColor.white.setFill()
                            UIRectFill(CGRect(x: 0, y: 0, width: 1080, height: 1440))
                            img.draw(in: CGRect(x: 0, y: 0, width: 1080, height: 1440))
                        }
                        if let data = composed.pngData() {
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
    var color: Color = .black
    var width: CGFloat = 5
    var isErasing = false

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .white
        canvas.tool = makeTool()
        canvas.alwaysBounceVertical = true
        canvas.allowsFingerDrawing = true
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
        uiView.tool = makeTool()
    }

    private func makeTool() -> PKTool {
        if isErasing {
            return PKEraserTool(.vector)
        }
        return PKInkingTool(.pen, color: UIColor(color), width: width)
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
