import Foundation
import SwiftData

@Model
class DailyEntry {
    var date: String
    var assetIdentifier: String
    var createdAt: Date

    init(date: String, assetIdentifier: String) {
        self.date = date
        self.assetIdentifier = assetIdentifier
        self.createdAt = Date()
    }
}
