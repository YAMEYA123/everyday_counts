import Foundation
import Photos
import SwiftData
import UIKit
import AVFoundation
import WidgetKit

@MainActor
class EntryStore: ObservableObject {
    static let albumName = "Everyday Counts"

    private enum EntryStoreError: Error {
        case notEditable
        case writeFailure
    }

    // MARK: - Widget shared data

    private static let appGroupID = "group.com.yameya.everyday-counts"
    private static let thumbFilename = "widget_thumb.jpg"
    private static let checkedDateKey = "widget_checked_date"

    private static func writeWidgetData(date: String, imageData: Data?) {
        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(date, forKey: checkedDateKey)

        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let url = container.appendingPathComponent(thumbFilename)
            if let imageData,
               let img = UIImage(data: imageData),
               let resized = resizeImage(img, maxSide: 300),
               let jpeg = resized.jpegData(compressionQuality: 0.7) {
                try? jpeg.write(to: url, options: .atomic)
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func resizeImage(_ image: UIImage, maxSide: CGFloat) -> UIImage? {
        let size = image.size
        guard size.width > 0 && size.height > 0 else { return nil }
        let scale = min(maxSide / size.width, maxSide / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    // MARK: - Local media storage

    private static var backupDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("entries", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func backupURL(for date: String) -> URL {
        backupDir.appendingPathComponent("\(date).jpg")
    }

    private static func sketchURL(for date: String) -> URL {
        backupDir.appendingPathComponent("\(date).sketch.png")
    }

    private static func sketchURL(from path: String) -> URL {
        backupDir.appendingPathComponent(path)
    }

    private static func saveBackup(imageData: Data, date: String) {
        let data: Data
        if let img = UIImage(data: imageData),
           let resized = resizeImage(img, maxSide: 1500),
           let jpeg = resized.jpegData(compressionQuality: 0.75) {
            data = jpeg
        } else {
            data = imageData
        }
        try? data.write(to: backupURL(for: date), options: .atomic)
    }

    private static func loadBackup(for date: String) -> Data? {
        if let data = try? Data(contentsOf: backupURL(for: date)) {
            return data
        }

        let legacyURL = backupDir.appendingPathComponent("\(date).heic")
        return try? Data(contentsOf: legacyURL)
    }

    private static var liveVideoCacheDir: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("everyday-counts-live", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func safeAssetId(_ id: String) -> String {
        id.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
    }

    private static func liveMovieURL(for assetIdentifier: String) -> URL {
        liveVideoCacheDir.appendingPathComponent("\(safeAssetId(assetIdentifier)).mov")
    }

    // MARK: - Date helpers

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dateKey(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func dateFromKey(_ date: String) -> Date? {
        dateFormatter.date(from: date)
    }

    static func dayEnd(_ date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
    }

    /// 默认编辑窗口到本地时区当天 23:59:59。
    static func isEditable(date: String, now: Date = Date()) -> Bool {
        guard let targetDate = dateFromKey(date) else { return false }
        let cal = Calendar.current
        guard cal.isDate(targetDate, inSameDayAs: now) else { return false }
        return now <= dayEnd(targetDate)
    }

    /// 过去日期可用于“补记”，但仅当该天尚未记录任何内容。
    static func isMissedFillAllowed(date: String, now: Date = Date()) -> Bool {
        guard let targetDate = dateFromKey(date) else { return false }
        let cal = Calendar.current
        guard !isEditable(date: date, now: now) else { return false }
        return targetDate < cal.startOfDay(for: now)
    }

    func canEdit(date: String, now: Date = Date()) -> Bool {
        Self.isEditable(date: date, now: now)
    }

    func canFillMissed(for date: String, now: Date = Date(), context: ModelContext) -> Bool {
        guard Self.isMissedFillAllowed(date: date, now: now) else { return false }
        return entry(for: date, context: context) == nil
    }

    // MARK: - SwiftData helpers

    func entry(for date: String, context: ModelContext) -> DailyEntry? {
        let descriptor = FetchDescriptor<DailyEntry>(predicate: #Predicate { $0.date == date })
        return try? context.fetch(descriptor).first
    }

    func entries(year: Int, month: Int?, context: ModelContext) -> [DailyEntry] {
        let prefix = month.map { String(format: "%04d-%02d", year, $0) } ?? String(year)
        let descriptor = FetchDescriptor<DailyEntry>(
            predicate: #Predicate { $0.date.starts(with: prefix) },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Rebuild missing photo indexes from the app's system album.
    /// This recovers records after a reinstall or Bundle ID change without
    /// deleting or replacing anything in Photos.
    @discardableResult
    func rebuildEntriesFromAlbum(context: ModelContext) -> Int {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return 0 }

        let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var album: PHAssetCollection?
        albums.enumerateObjects { collection, _, stop in
            if collection.localizedTitle == Self.albumName {
                album = collection
                stop.pointee = true
            }
        }
        guard let album else { return 0 }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let assets = PHAsset.fetchAssets(in: album, options: options)
        var recovered = 0

        assets.enumerateObjects { asset, _, _ in
            guard let assetDate = asset.creationDate ?? asset.modificationDate else { return }
            let date = Self.dateKey(assetDate)
            guard self.entry(for: date, context: context) == nil else { return }

            context.insert(DailyEntry(
                date: date,
                assetIdentifier: asset.localIdentifier,
                kind: .photo
            ))
            recovered += 1
        }

        if recovered > 0 {
            try? context.save()
        }
        return recovered
    }

    func currentStreak(context: ModelContext) -> Int {
        let cal = Calendar.current
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        var streak = 0
        var checkDate = Date()

        let todayKey = f.string(from: checkDate)
        if entry(for: todayKey, context: context) == nil {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while true {
            let key = f.string(from: checkDate)
            if entry(for: key, context: context) != nil {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }

    private func removeExistingIfAny(date: String, context: ModelContext) {
        let descriptor = FetchDescriptor<DailyEntry>(predicate: #Predicate { $0.date == date })
        if let existing = try? context.fetch(descriptor) {
            existing.forEach { old in
                if old.kind == .photo,
                   let oldAsset = resolveAsset(identifier: old.assetIdentifier) {
                    Task { await self.removeFromAlbum(asset: oldAsset) }
                }
                if old.kind == .sketch {
                    removeLocalSketchFile(old.sketchPath)
                }
                context.delete(old)
            }
        }
    }

    private func removeLocalSketchFile(_ path: String?) {
        guard let path else { return }
        let url = Self.sketchURL(from: path)
        try? FileManager.default.removeItem(at: url)
    }

    private func removeWidgetThumbIfNeeded() {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) {
            let url = container.appendingPathComponent(Self.thumbFilename)
            try? FileManager.default.removeItem(at: url)
        }
    }

    func resolveAsset(identifier: String) -> PHAsset? {
        guard !identifier.isEmpty else { return nil }
        return PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
    }

    func isLivePhoto(asset: PHAsset) -> Bool {
        PHAssetResource.assetResources(for: asset).contains { $0.type == .pairedVideo }
    }

    func pairedMovieURL(for asset: PHAsset) async -> URL? {
        guard let resource = PHAssetResource.assetResources(for: asset)
            .first(where: { $0.type == .pairedVideo }) else {
            return nil
        }

        let cacheURL = Self.liveMovieURL(for: asset.localIdentifier)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: cacheURL.path),
           let size = attrs[.size] as? NSNumber,
           size.intValue > 0 {
            return cacheURL
        }
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            try? FileManager.default.removeItem(at: cacheURL)
        }

        do {
			let extractedURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                let options = PHAssetResourceRequestOptions()
                options.isNetworkAccessAllowed = true

                PHAssetResourceManager.default().writeData(for: resource, toFile: cacheURL, options: options) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: cacheURL)
                    }
                }
            }
            return extractedURL
        } catch {
            print("paired movie extract error:", error)
            return nil
        }
    }

    // MARK: - Save

    func saveLivePhoto(imageData: Data, videoURL: URL?, date: String, context: ModelContext) async throws -> String {
        guard canEdit(date: date) || canFillMissed(for: date, context: context) else {
            throw EntryStoreError.notEditable
        }

        if let existing = entry(for: date, context: context), canEdit(date: date) {
            removeExistingIfAny(date: date, context: context)
            removeLocalSketchFile(existing.sketchPath)
        }

        if !canEdit(date: date) && !canFillMissed(for: date, context: context) {
            throw EntryStoreError.notEditable
        }

		Self.saveBackup(imageData: imageData, date: date)
        Self.writeWidgetData(date: date, imageData: imageData)

        guard let album = await ensureAlbumExists() else {
            throw EntryStoreError.writeFailure
        }
        let assetID = try await writeToPhotoLibrary(imageData: imageData, videoURL: videoURL, album: album)
        let entry = DailyEntry(date: date, assetIdentifier: assetID, kind: .photo)
        context.insert(entry)
        try? context.save()
        return assetID
    }

    func saveText(_ text: String, date: String, context: ModelContext) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        guard canEdit(date: date) || canFillMissed(for: date, context: context) else { return }

        if let existing = entry(for: date, context: context), canEdit(date: date) {
            removeExistingIfAny(date: date, context: context)
            removeLocalSketchFile(existing.sketchPath)
        }

        Self.writeWidgetData(date: date, imageData: nil)
        removeWidgetThumbIfNeeded()
        let entry = DailyEntry(date: date, assetIdentifier: "", kind: .text, noteText: normalized)
        context.insert(entry)
        try? context.save()
    }

    func saveSketch(_ imageData: Data, date: String, context: ModelContext) throws {
        guard canEdit(date: date) || canFillMissed(for: date, context: context) else {
            throw EntryStoreError.notEditable
        }

        if let existing = entry(for: date, context: context), canEdit(date: date) {
            removeExistingIfAny(date: date, context: context)
            removeLocalSketchFile(existing.sketchPath)
        }

        let url = Self.sketchURL(for: date)
        try imageData.write(to: url, options: .atomic)
        Self.writeWidgetData(date: date, imageData: nil)
        removeWidgetThumbIfNeeded()

        let entry = DailyEntry(date: date, assetIdentifier: "", kind: .sketch, sketchPath: url.lastPathComponent)
        context.insert(entry)
        try? context.save()
    }

    func loadSketchImage(for entry: DailyEntry) -> UIImage? {
        guard entry.kind == .sketch else { return nil }
        if let path = entry.sketchPath {
            let url = Self.sketchURL(from: path)
            if let data = try? Data(contentsOf: url) {
                return UIImage(data: data)
            }
        }
        return nil
    }

    // MARK: - Album

    func ensureAlbumExists() async -> PHAssetCollection? {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status != .authorized && status != .limited {
            let granted = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            guard granted == .authorized || granted == .limited else { return nil }
        }

        let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var found: PHAssetCollection?
        albums.enumerateObjects { col, _, stop in
            if col.localizedTitle == Self.albumName { found = col; stop.pointee = true }
        }
        if let found { return found }

        var placeholder: PHObjectPlaceholder?
        try? await PHPhotoLibrary.shared().performChanges {
            placeholder = PHAssetCollectionChangeRequest
                .creationRequestForAssetCollection(withTitle: Self.albumName)
                .placeholderForCreatedAssetCollection
        }
        guard let id = placeholder?.localIdentifier else { return nil }
        return PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject
    }

    private func writeToPhotoLibrary(imageData: Data, videoURL: URL?, album: PHAssetCollection) async throws -> String {
        var assetID: String?
        try await PHPhotoLibrary.shared().performChanges {
            let req = PHAssetCreationRequest.forAsset()
            req.addResource(with: .photo, data: imageData, options: nil)
            if let videoURL = videoURL {
                let opts = PHAssetResourceCreationOptions()
                opts.shouldMoveFile = true
                req.addResource(with: .pairedVideo, fileURL: videoURL, options: opts)
            }
            if let ph = req.placeholderForCreatedAsset {
                assetID = ph.localIdentifier
                PHAssetCollectionChangeRequest(for: album)?.addAssets([ph] as NSArray)
            }
        }
        guard let id = assetID else { throw EntryStoreError.writeFailure }
        return id
    }

    /// Remove an asset from the "Everyday Counts" album without deleting it from the library.
    private func removeFromAlbum(asset: PHAsset) async {
        let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var target: PHAssetCollection?
        albums.enumerateObjects { col, _, stop in
            if col.localizedTitle == Self.albumName { target = col; stop.pointee = true }
        }
        guard let album = target else { return }
        try? await PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest(for: album)?.removeAssets([asset] as NSArray)
        }
    }

    // MARK: - Restore if deleted

    func restoreIfNeeded(entry: DailyEntry, context: ModelContext) async -> PHAsset? {
        guard entry.kind == .photo else { return nil }
        if let asset = resolveAsset(identifier: entry.assetIdentifier) { return asset }

        guard let backupData = Self.loadBackup(for: entry.date),
              let album = await ensureAlbumExists() else { return nil }

        guard let newID = try? await writeToPhotoLibrary(imageData: backupData, videoURL: nil, album: album)
        else { return nil }

        entry.assetIdentifier = newID
        try? context.save()
        return resolveAsset(identifier: newID)
    }
}
