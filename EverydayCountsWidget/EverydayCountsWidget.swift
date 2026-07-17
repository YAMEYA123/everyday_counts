import WidgetKit
import SwiftUI
import UIKit

private let appGroupID = "group.com.yameya.everyday-counts"
private let thumbFilename = "widget_thumb.jpg"

struct WidgetEntry: TimelineEntry {
    let date: Date
    let isTodayChecked: Bool
    let thumbnail: UIImage?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), isTodayChecked: false, thumbnail: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let e = makeEntry()
        // Refresh at midnight so the "未打卡" state resets for next day
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.day! += 1; comps.hour = 0; comps.minute = 1
        let midnight = Calendar.current.date(from: comps) ?? Date().addingTimeInterval(86400)
        completion(Timeline(entries: [e], policy: .after(midnight)))
    }

    private func makeEntry() -> WidgetEntry {
        let defaults = UserDefaults(suiteName: appGroupID)
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let todayKey = f.string(from: Date())
        let checkedDate = defaults?.string(forKey: "widget_checked_date") ?? ""
        let isTodayChecked = checkedDate == todayKey

        var thumb: UIImage?
        if isTodayChecked,
           let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let url = container.appendingPathComponent(thumbFilename)
            if let data = try? Data(contentsOf: url) { thumb = UIImage(data: data) }
        }
        return WidgetEntry(date: Date(), isTodayChecked: isTodayChecked, thumbnail: thumb)
    }
}

struct WidgetEntryView: View {
    let entry: WidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let img = entry.thumbnail {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .overlay(Color.black.opacity(0.2))
            } else {
                Color.black
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(dateLabel())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                if entry.isTodayChecked {
                    Label("已打卡", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.green)
                } else {
                    Label("还没拍今天", systemImage: "camera.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.65), .clear],
                    startPoint: .bottom, endPoint: .top
                )
            )
        }
        .containerBackground(.black, for: .widget)
    }

    private func dateLabel() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: entry.date)
    }
}

@main
struct EverydayCountsWidget: Widget {
    let kind = "EverydayCountsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Everyday Counts")
        .description("查看今日打卡状态")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
