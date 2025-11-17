import Foundation

struct TripPermission: Identifiable, Codable {
    let id: UUID
    var userId: String // Clerk user ID
    var role: PermissionRole
    var grantedVia: String // "share_link" or "upgraded"
    var invitedBy: String // User ID who invited
    var acceptedAt: Date // When they joined

    // User info (fetched from backend)
    var user: UserInfo?

    init(id: UUID = UUID(),
         userId: String,
         role: PermissionRole,
         grantedVia: String,
         invitedBy: String,
         acceptedAt: Date,
         user: UserInfo? = nil) {
        self.id = id
        self.userId = userId
        self.role = role
        self.grantedVia = grantedVia
        self.invitedBy = invitedBy
        self.acceptedAt = acceptedAt
        self.user = user
    }
}

struct UserInfo: Codable {
    var name: String?
    var email: String?
    var imageUrl: String?
}
