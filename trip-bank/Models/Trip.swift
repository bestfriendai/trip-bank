import Foundation
import SwiftUI

struct Trip: Identifiable, Codable {
    let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var coverImageName: String?
    var coverImageStorageId: String?
    var mediaItems: [MediaItem]
    var moments: [Moment]

    // Sharing fields
    var ownerId: String? // Clerk user ID of the owner
    var shareSlug: String? // URL-safe slug for sharing
    var shareCode: String? // Human-readable code
    var shareLinkEnabled: Bool // Can people join via link?
    var previewImageStorageId: String? // Preview snapshot
    var permissions: [TripPermission] // Who has access to this trip
    var userRole: String? // Current user's role in this trip (for shared trips)
    var joinedAt: Double? // Timestamp when user joined (for shared trips)

    init(id: UUID = UUID(),
         title: String,
         startDate: Date = Date(),
         endDate: Date = Date(),
         coverImageName: String? = nil,
         coverImageStorageId: String? = nil,
         mediaItems: [MediaItem] = [],
         moments: [Moment] = [],
         ownerId: String? = nil,
         shareSlug: String? = nil,
         shareCode: String? = nil,
         shareLinkEnabled: Bool = false,
         previewImageStorageId: String? = nil,
         permissions: [TripPermission] = [],
         userRole: String? = nil,
         joinedAt: Double? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.coverImageName = coverImageName
        self.coverImageStorageId = coverImageStorageId
        self.mediaItems = mediaItems
        self.moments = moments
        self.ownerId = ownerId
        self.shareSlug = shareSlug
        self.shareCode = shareCode
        self.shareLinkEnabled = shareLinkEnabled
        self.previewImageStorageId = previewImageStorageId
        self.permissions = permissions
        self.userRole = userRole
        self.joinedAt = joinedAt
    }

    var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return formatter.string(from: startDate)
        } else {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
    }
}
