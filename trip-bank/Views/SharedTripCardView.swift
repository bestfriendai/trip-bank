import SwiftUI

struct SharedTripCardView: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover image or placeholder
            coverImage
                .frame(height: 200)
                .clipped()

            // Trip info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(trip.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Spacer()

                    // Role badge
                    roleBadge
                }

                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(trip.dateRangeString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    Label("\(trip.mediaItems.count)", systemImage: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !trip.moments.isEmpty {
                        Label("\(trip.moments.count)", systemImage: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }

    @ViewBuilder
    private var coverImage: some View {
        if let coverImageStorageId = trip.coverImageStorageId,
           let mediaItem = trip.mediaItems.first(where: { $0.storageId == coverImageStorageId }) {
            MediaImageView(mediaItem: mediaItem)
                .scaledToFill()
        } else {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    VStack {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 50))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
        }
    }

    @ViewBuilder
    private var roleBadge: some View {
        if let role = trip.userRole {
            HStack(spacing: 4) {
                Image(systemName: roleIcon(for: role))
                    .font(.caption2)
                Text(roleText(for: role))
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(roleColor(for: role))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(roleColor(for: role).opacity(0.15))
            .cornerRadius(6)
        }
    }

    private func roleIcon(for role: String) -> String {
        switch role {
        case "owner": return "crown.fill"
        case "collaborator": return "pencil.circle.fill"
        case "viewer": return "eye.fill"
        default: return "person.fill"
        }
    }

    private func roleText(for role: String) -> String {
        switch role {
        case "owner": return "Owner"
        case "collaborator": return "Can edit"
        case "viewer": return "View only"
        default: return "Guest"
        }
    }

    private func roleColor(for role: String) -> Color {
        switch role {
        case "owner": return .orange
        case "collaborator": return .blue
        case "viewer": return .gray
        default: return .gray
        }
    }
}
