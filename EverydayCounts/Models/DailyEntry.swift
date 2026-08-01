import Foundation
import SwiftData

@Model
class DailyEntry {
    enum Kind: String, Codable, CaseIterable {
        case photo
        case text
        case sketch
    }

    var date: String
    var assetIdentifier: String
    // Optional for lightweight migration from the original photo-only schema.
    // Missing legacy values are treated as photo records.
    var kindRaw: String?
    var noteText: String?
    var sketchPath: String?
    var createdAt: Date

    init(
        date: String,
        assetIdentifier: String,
        kind: Kind = .photo,
        noteText: String? = nil,
        sketchPath: String? = nil
    ) {
        self.date = date
        self.assetIdentifier = assetIdentifier
        self.kindRaw = kind.rawValue
        self.noteText = noteText
        self.sketchPath = sketchPath
        self.createdAt = Date()
    }

    var kind: Kind {
        get { Kind(rawValue: kindRaw ?? Kind.photo.rawValue) ?? .photo }
        set { kindRaw = newValue.rawValue }
    }
}
