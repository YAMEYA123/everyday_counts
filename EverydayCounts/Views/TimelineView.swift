import SwiftUI
import SwiftData
import Photos

struct TimelineView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var store = EntryStore()
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var month = Calendar.current.component(.month, from: Date())
    @State private var entryMap: [String: DailyEntry] = [:]
    @State private var preview: DailyEntry?

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Button { prevMonth() } label: {
                            Image(systemName: "chevron.left").foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                        Text("\(year)年\(month)月").font(.headline).foregroundStyle(.white)
                        Spacer()
                        Button { nextMonth() } label: {
                            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal).padding(.vertical, 12)

                    let cols = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
                    LazyVGrid(columns: cols, spacing: 2) {
                        ForEach(["一","二","三","四","五","六","日"], id: \.self) {
                            Text($0).font(.caption2).foregroundStyle(.white.opacity(0.3))
                                .frame(maxWidth: .infinity)
                        }
                        ForEach(0..<firstWeekday, id: \.self) { _ in
                            Color.clear.aspectRatio(1, contentMode: .fit)
                        }
                        ForEach(1...daysInMonth, id: \.self) { day in
                            let key = String(format: "%04d-%02d-%02d", year, month, day)
                            DayCellView(day: day, entry: entryMap[key], isToday: key == todayKey, store: store)
                                .onTapGesture { if let e = entryMap[key] { preview = e } }
                        }
                    }
                    .padding(.horizontal)

                    Text("\(entryMap.count) / \(daysInMonth) 天已记录")
                        .font(.caption).foregroundStyle(.white.opacity(0.3)).padding(.top, 12)
                }
            }
            .background(Color.black)
            .navigationTitle("时间线")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(item: $preview) { LivePhotoFullscreen(entry: $0) }
        .task(id: "\(year)-\(month)") { await load() }
    }

    private func load() async {
        let entries = store.entries(year: year, month: month, context: context)
        entryMap = Dictionary(entries.map { ($0.date, $0) }, uniquingKeysWith: { _, last in last })
    }
    private func prevMonth() { if month == 1 { year -= 1; month = 12 } else { month -= 1 } }
    private func nextMonth() { if month == 12 { year += 1; month = 1 } else { month += 1 } }
}

struct DayCellView: View {
    let day: Int
    let entry: DailyEntry?
    let isToday: Bool
    let store: EntryStore
    @Environment(\.modelContext) private var context
    @State private var thumbnail: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                if let img = thumbnail {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.width).clipped()
                } else {
                    Color.white.opacity(0.05)
                    Text("\(day)").font(.system(size: 10)).foregroundStyle(.white.opacity(0.2))
                        .padding(3)
                }
                if entry != nil {
                    Text("\(day)").font(.system(size: 9)).foregroundStyle(.white.opacity(0.7)).padding(2)
                }
            }
            .frame(width: geo.size.width, height: geo.size.width)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(isToday ? RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.5), lineWidth: 1) : nil)
        }
        .aspectRatio(1, contentMode: .fit)
        .task(id: entry?.assetIdentifier) {
            guard let entry else { thumbnail = nil; return }
            guard let asset = await store.restoreIfNeeded(entry: entry, context: context)
            else { thumbnail = nil; return }
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .opportunistic
            opts.isNetworkAccessAllowed = false
            thumbnail = await withCheckedContinuation { cont in
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
        }
    }
}

extension DailyEntry: Identifiable {}
