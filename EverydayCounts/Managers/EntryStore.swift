import Foundation
import Photos
import SwiftData

@MainActor
class EntryStore: ObservableObject {
    static let albumName = "Everyday Counts"

    // MARK: - Local backup directory

    private static var backupDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("entries", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func backupURL(for date: String) -> URL {
        backupDir.appendingPathComponent("\(date).heic")
    }

    private static func saveBackup(imageData: Data, date: String) {
        try? imageData.write(to: backupURL(for: date), options: .atomic)
    }

    private static func loadBackup(for date: String) -> Data? {
        try? Data(contentsOf: backupURL(for: date))
    }

    // MARK: - SwiftData helpers

    func save(date: String, assetIdentifier: String, context: ModelContext) {
        let descriptor = FetchDescriptor<DailyEntry>(predicate: #Predicate { $0.date == date })
        if let existing = try? context.fetch(descriptor) {
            existing.forEach { context.delete($0) }
        }
        let entry = DailyEntry(date: date, assetIdentifier: assetIdentifier)
        context.insert(entry)
        try? context.save()
    }

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

    func resolveAsset(identifier: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
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
            if col.localizedTitle == EntryStore.albumName { found = col; stop.pointee = true }
        }
        if let found { return found }

        var placeholder: PHObjectPlaceholder?
        try? await PHPhotoLibrary.shared().performChanges {
            placeholder = PHAssetCollectionChangeRequest
                .creationRequestForAssetCollection(withTitle: EntryStore.albumName)
                .placeholderForCreatedAssetCollection
        }
        guard let id = placeholder?.localIdentifier else { return nil }
        return PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject
    }

    // MARK: - Save (with local backup)

    func saveLivePhoto(imageData: Data, videoURL: URL?, date: String, context: ModelContext) async throws -> String {
        // Always write a local backup so we can restore if the user deletes from Photos
        EntryStore.saveBackup(imageData: imageData, date: date)

        guard let album = await ensureAlbumExists() else {
            throw NSError(domain: "EntryStore", code: 1)
        }
        let assetID = try await writeToPhotoLibrary(imageData: imageData, videoURL: videoURL, album: album)
        save(date: date, assetIdentifier: assetID, context: context)
        return assetID
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
        guard let id = assetID else { throw NSError(domain: "EntryStore", code: 2) }
        return id
    }

    // MARK: - Restore if deleted

    /// Checks whether the PHAsset still exists; if deleted, re-saves from local backup.
    /// Returns the (possibly updated) asset identifier, or nil if backup is missing too.
    func restoreIfNeeded(entry: DailyEntry, context: ModelContext) async -> PHAsset? {
        if let asset = resolveAsset(identifier: entry.assetIdentifier) { return asset }

        // PHAsset gone — try local backup
        guard let backupData = EntryStore.loadBackup(for: entry.date),
              let album = await ensureAlbumExists() else { return nil }

        guard let newID = try? await writeToPhotoLibrary(imageData: backupData, videoURL: nil, album: album)
        else { return nil }

        save(date: entry.date, assetIdentifier: newID, context: context)
        return resolveAsset(identifier: newID)
    }
}
