import SwiftUI

// View that displays either a local image, Convex storage image, or remote URL
struct MediaImageView: View {
    let mediaItem: MediaItem
    @State private var imageURL: URL?
    @State private var isLoading = false
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let url = imageURL {
                // Load from URL (Convex storage or external)
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Color.gray.opacity(0.1)
                            ProgressView()
                                .tint(.white)
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure(let error):
                        ZStack {
                            placeholderImage
                            VStack {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.gray.opacity(0.5))
                            }
                        }
                        .onAppear {
                            print("Failed to load image: \(url)")
                            print("Error: \(error)")
                        }
                    @unknown default:
                        placeholderImage
                    }
                }
            } else if isLoading {
                ZStack {
                    Color.gray.opacity(0.1)
                    ProgressView()
                        .tint(.white)
                }
            } else {
                placeholderImage
            }
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        // Check if we already have a URL
        if let existingURL = mediaItem.imageURL {
            imageURL = existingURL
            return
        }

        // For videos, try to load thumbnail first
        let storageIdToLoad: String?
        if mediaItem.type == .video {
            storageIdToLoad = mediaItem.thumbnailStorageId ?? mediaItem.storageId
        } else {
            storageIdToLoad = mediaItem.storageId
        }

        // Try to load from Convex storage
        guard let storageId = storageIdToLoad, !storageId.isEmpty else {
            return
        }

        isLoading = true

        do {
            let urlString = try await ConvexClient.shared.getFileUrl(storageId: storageId)

            // Check if task was cancelled
            try Task.checkCancellation()

            if let url = URL(string: urlString) {
                imageURL = url
            } else {
                loadFailed = true
            }
        } catch is CancellationError {
            // Task was cancelled (user navigated away), this is normal - don't log error
            return
        } catch {
            // Only log non-cancellation errors
            print("❌ Failed to load image URL from Convex: \(error)")
            loadFailed = true
        }

        isLoading = false
    }

    private var placeholderImage: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.gray.opacity(0.3), .gray.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}
