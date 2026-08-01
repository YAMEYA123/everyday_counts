import SwiftUI
import SwiftData
import Photos
import PencilKit

struct TimelineView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var store = EntryStore()
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var month = Calendar.current.component(.month, from: Date())
    @Query(sort: [SortDescriptor<DailyEntry>(\.date)]) private var allEntries: [DailyEntry]
    @State private var preview: DailyEntry?

    @State private var fillDate: String?
    @State private var showFillAction = false
    @State private var showFillCamera = false
    @State private var showFillText = false
    @State private var showFillSketch = false
    @State private var noteDraft = ""
    @State private var sketchDrawing = PKDrawing()

    private var daysInMonth: Int {
        let comps = DateComponents(year: year, month: month)
        let date = Calendar.current.date(from: comps)!
        return Calendar.current.range(of: .day, in: .month, for: date)!.count
    }

    private var firstWeekday: Int {
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))!
        return (Calendar.current.component(.weekday, from: date) + 5) % 7
    }

    private var todayKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }

    private var weekdayLabels: [String] {
        ["一", "二", "三", "四", "五", "六", "日"]
    }

    private var blankIDs: [String] {
        (0..<firstWeekday).map { "blank-\($0)" }
    }

    private var calendarDays: [CalendarDayItem] {
        (1...daysInMonth).map { day in
            CalendarDayItem(id: "day-\(day)", day: day)
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    }

    private var entryMap: [String: DailyEntry] {
        let prefix = String(format: "%04d-%02d", year, month)
        let monthEntries = allEntries.filter { $0.date.hasPrefix(prefix) }
        return Dictionary(
            monthEntries.map { ($0.date, $0) },
            uniquingKeysWith: { _, last in last }
        )
    }

    private var previousMonthButton: some View {
        Button(action: prevMonth) {
            Image(systemName: "chevron.left")
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var nextMonthButton: some View {
        Button(action: nextMonth) {
            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var monthTitle: some View {
        Text(verbatim: "\(year)年\(month)月")
            .font(.headline)
            .foregroundStyle(.white)
    }

    private var calendarHeader: some View {
        HStack {
            previousMonthButton
            Spacer()
            monthTitle
            Spacer()
            nextMonthButton
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 2) {
            ForEach(weekdayLabels, id: \.self) { label in
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity)
            }
            ForEach(blankIDs, id: \.self) { _ in
                Color.clear.aspectRatio(1, contentMode: .fit)
            }
            ForEach(calendarDays) { item in
                let key = String(format: "%04d-%02d-%02d", year, month, item.day)
                DayCellView(
                    day: item.day,
                    dateKey: key,
                    entry: entryMap[key],
                    isToday: key == todayKey,
                    store: store,
                    onTap: handleCellTap
                )
            }
        }
        .padding(.horizontal)
    }

    private var timelineContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                calendarHeader
                calendarGrid
                Text("\(entryMap.count) / \(daysInMonth) 天已记录")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.top, 12)
            }
        }
    }

    var body: some View {
        NavigationStack {
            timelineContent
            .background(Color.black)
            .navigationTitle("时间线")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(item: $preview) { LivePhotoFullscreen(entry: $0) }
        .confirmationDialog("补记这一天", isPresented: $showFillAction, titleVisibility: .visible) {
            Button("拍照") { showFillCamera = true }
            Button("写文字") { showFillText = true }
            Button("白板") { showFillSketch = true; sketchDrawing = PKDrawing() }
            Button("取消", role: .cancel) {}
        } message: {
            if let fillDate {
                Text("补记到 \(fillDate)")
            } else {
                Text("选择补记方式")
            }
        }
        .fullScreenCover(isPresented: $showFillCamera) {
            if let date = fillDate {
                CameraView { imageData, movieURL in
                    Task { await savePhoto(imageData: imageData, movieURL: movieURL, targetDate: date) }
                }
            }
        }
        .sheet(isPresented: $showFillText) {
            TextNoteSheet(isPresented: $showFillText, text: $noteDraft) { text in
                saveText(text)
            } onCancel: {
                noteDraft = ""
            }
        }
        .sheet(isPresented: $showFillSketch) {
            SketchBoardSheet(drawing: $sketchDrawing) { png in
                showFillSketch = false
                saveSketch(png: png)
            } onCancel: {
                sketchDrawing = PKDrawing()
                showFillSketch = false
            }
        }
        .task { await load() }
        .onAppear { Task { await load() } }
        .onReceive(NotificationCenter.default.publisher(for: .everydayCountsTimelineNeedsRefresh)) { _ in
            Task { await load() }
        }
        .onChange(of: year) { _, _ in Task { await load() } }
        .onChange(of: month) { _, _ in Task { await load() } }
    }

    private func load() async {
        store.rebuildEntriesFromAlbum(context: context)
    }

    private func handleCellTap(dateKey: String, entry: DailyEntry?) {
        if let entry {
            preview = entry
            return
        }

        guard store.canFillMissed(for: dateKey, now: Date(), context: context) else { return }
        fillDate = dateKey
        noteDraft = ""
        showFillAction = true
    }

    private func savePhoto(imageData: Data, movieURL: URL?, targetDate: String) async {
        do {
            _ = try await store.saveLivePhoto(imageData: imageData, videoURL: movieURL, date: targetDate, context: context)
            await load()
        } catch {
            print("Save photo for fill failed:", error)
        }
        fillDate = nil
        showFillCamera = false
    }

    private func saveText(_ text: String) {
        guard let date = fillDate else { return }
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        store.saveText(normalized, date: date, context: context)
        noteDraft = ""
        fillDate = nil
        Task { await load() }
    }

    private func saveSketch(png: Data) {
        guard let date = fillDate else { return }
        do {
            try store.saveSketch(png, date: date, context: context)
            sketchDrawing = PKDrawing()
            fillDate = nil
            Task { await load() }
        } catch {
            print("Save sketch failed:", error)
        }
    }

    private func prevMonth() {
        if month == 1 { year -= 1; month = 12 } else { month -= 1 }
    }

    private func nextMonth() {
        if month == 12 { year += 1; month = 1 } else { month += 1 }
    }
}

private struct CalendarDayItem: Identifiable {
    let id: String
    let day: Int
}

struct DayCellView: View {
    let day: Int
    let dateKey: String
    let entry: DailyEntry?
    let isToday: Bool
    let store: EntryStore
    let onTap: (String, DailyEntry?) -> Void

    @Environment(\.modelContext) private var context
    @State private var photoThumb: UIImage?
    @State private var isLive = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                if let entry {
                    switch entry.kind {
                    case .photo:
                        if let img = photoThumb {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.width)
                                .clipped()
                        } else {
                            Color.white.opacity(0.08)
                        }
                    case .text:
                        Color.white.opacity(0.08)
                        VStack {
                            Spacer()
                            Text("✎")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(4)
                            Spacer()
                        }
                    case .sketch:
                        if let img = photoThumb {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.width)
                                .clipped()
                        } else {
                            Color.white.opacity(0.08)
                        }
                    }

                    Text("\(day)")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(2)
                } else {
                    Color.white.opacity(0.05)
                    Text("\(day)")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.2))
                        .padding(3)
                }

                if let entry {
                    if entry.kind == .photo && isLive {
                        Image(systemName: "livephoto")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(3)
                    }
                    if entry.kind == .text {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(3)
                    }
                    if entry.kind == .sketch {
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(3)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.width)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(isToday ? RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.5), lineWidth: 1) : nil)
            .onTapGesture { onTap(dateKey, entry) }
        }
        .aspectRatio(1, contentMode: .fit)
        .task(id: entry?.assetIdentifier) {
            guard let entry else { photoThumb = nil; isLive = false; return }
            switch entry.kind {
            case .photo:
                guard let asset = await store.restoreIfNeeded(entry: entry, context: context) else {
                    photoThumb = nil
                    isLive = false
                    return
                }
                isLive = store.isLivePhoto(asset: asset)
                let opts = PHImageRequestOptions()
                opts.deliveryMode = .opportunistic
                opts.isNetworkAccessAllowed = false
                photoThumb = await withCheckedContinuation { cont in
                    var resumed = false
                    PHImageManager.default().requestImage(
                        for: asset, targetSize: CGSize(width: 100, height: 100),
                        contentMode: .aspectFill, options: opts
                    ) { img, info in
                        let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                        guard !isDegraded, !resumed else { return }
                        resumed = true
                        cont.resume(returning: img)
                    }
                }
            case .text:
                photoThumb = nil
                isLive = false
            case .sketch:
                photoThumb = store.loadSketchImage(for: entry)
                isLive = false
            }
        }
    }
}

extension DailyEntry: Identifiable {}
