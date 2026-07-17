import SwiftUI
import SwiftData
import Photos
import AVKit

struct ReviewView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var store = EntryStore()

    private let now = Date()
    @State private var isMonthRange = true
    @State private var entries: [DailyEntry] = []
    @State private var isGenerating = false
    @State private var progress: Double = 0
    @State private var videoURL: URL?

    private var year: Int { Calendar.current.component(.year, from: now) }
    private var month: Int { Calendar.current.component(.month, from: now) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        HStack(spacing: 8) {
                            ForEach([true, false], id: \.self) { isMonth in
                                Button(isMonth ? "本月" : "本年") {
                                    isMonthRange = isMonth; videoURL = nil
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(isMonthRange == isMonth ? Color.white : Color.white.opacity(0.1))
                                .foregroundStyle(isMonthRange == isMonth ? Color.black : Color.white.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        VStack(spacing: 8) {
                            row("已记录", "\(entries.count) 张照片")
                            row("预计时长", "约 \(Int((Double(entries.count) * 1.5).rounded())) 秒")
                        }
                        .padding().background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        if isGenerating {
                            VStack(spacing: 12) {
                                ProgressView().tint(.white).scaleEffect(1.5)
                                Text("生成中 \(Int(progress * 100))%")
                                    .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                                ProgressView(value: progress).tint(.white)
                            }.padding()
                        } else if let url = videoURL {
                            VideoPlayer(player: AVPlayer(url: url))
                                .frame(height: 300).clipShape(RoundedRectangle(cornerRadius: 16))
                            Button { saveToAlbum(url: url) } label: {
                                Label("保存到相册", systemImage: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(Color.white).foregroundStyle(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            Button("重新生成") { videoURL = nil }
                                .foregroundStyle(.white.opacity(0.4)).font(.subheadline)
                        } else {
                            Button { Task { await generate() } } label: {
                                Label("生成回顾视频", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(entries.isEmpty ? Color.white.opacity(0.3) : Color.white)
                                    .foregroundStyle(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .disabled(entries.isEmpty)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("回顾").navigationBarTitleDisplayMode(.large)
        }
        .task(id: isMonthRange) { load() }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value).foregroundStyle(.white.opacity(0.6))
        }.font(.subheadline)
    }

    private func load() {
        entries = isMonthRange
            ? store.entries(year: year, month: month, context: context)
            : store.entries(year: year, month: nil, context: context)
    }

    private func generate() async {
        isGenerating = true; progress = 0
        let assets = entries.compactMap { store.resolveAsset(identifier: $0.assetIdentifier) }
        guard !assets.isEmpty else { isGenerating = false; return }
        do {
            videoURL = try await VideoGenerator.generate(assets: assets) { p in
                Task { @MainActor in progress = p }
            }
        } catch { print("Video error:", error) }
        isGenerating = false
    }

    private func saveToAlbum(url: URL) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }
}
