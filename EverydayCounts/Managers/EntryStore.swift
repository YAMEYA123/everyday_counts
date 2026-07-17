import Foundation
import Photos
import SwiftData

@MainActor
class EntryStore: ObservableObject {
    static let albumName = "Everyday Counts"

    func save(date: String, assetIdentifier: String, context: ModelContext) {
        // Remove any existing entry for the same date to prevent duplicates
        let descriptor = FetchDescriptor<DailyEntry>(predicate: #Predicate { $0.date == date })
        if let existing = try? context.fetch(descriptor) {
            existing.forEach { context.delete($0) }
        }
        let entry = DailyEntry(date: date, assetIdentifier: assetIdentifier)
        context.insert(entry)
        try? context.save()
    }

    func entry(for date: String, context: ModelContext) -> DailyEntry? {
        let descriptor = FetchDescriptor<DailyEntry>(
            predicate: #Predicate { $0.date == date }
        )
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

    func ensureAlbumExists() async -> PHAssetCollection? {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        print("Photo library status:", status.rawValue)
        if status != .authorized && status != .limited {
            let granted = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            print("Photo library granted:", granted.rawValue)
            guard granted == .authorized || granted == .limited else {
                print("Photo library access denied")
                return nil
            }
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

    func saveLivePhoto(imageData: Data, videoURL: URL?, date: String, context: ModelContext) async throws -> String {
        guard let album = await ensureAlbumExists() else {
            throw NSError(domain: "EntryStore", code: 1)
        }
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
        save(date: date, assetIdentifier: id, context: context)
        return id
    }
}
