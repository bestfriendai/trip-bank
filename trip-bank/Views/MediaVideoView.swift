import SwiftUI
import AVKit

// View that displays video from Convex storage or remote URL
struct MediaVideoView: View {
    let mediaItem: MediaItem
    @State private var videoURL: URL?
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var player: AVPlayer?
    @State private var isMuted = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let url = videoURL, let player = player {
                VideoPlayer(player: player)
                    .disabled(true) // Disable default controls
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }

                // Mute/unmute button
                Button {
                    isMuted.toggle()
                    player.isMuted = isMuted
                } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Circle().fill(.black.opacity(0.5)))
                }
                .padding(8)
            } else if isLoading {
                ZStack {
                    Color.gray.opacity(0.1)
                    ProgressView()
                        .tint(.white)
                }
            } else if loadFailed {
                ZStack {
                    placeholderView
                    VStack {
                        Image(systemName: "video.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.gray.opacity(0.5))
                    }
                }
            } else {
                placeholderView
            }
        }
        .task {
            await loadVideo()
        }
        .onChange(of: videoURL) { oldValue, newValue in
            if let url = newValue {
                setupPlayer(url: url)
            }
        }
    }

    private func loadVideo() async {
        // Check if we already have a URL
        if let existingURL = mediaItem.videoURL {
            videoURL = existingURL
            return
        }

        // Try to load from Convex storage
        guard let storageId = mediaItem.storageId, !storageId.isEmpty else {
            return
        }

        isLoading = true

        do {
            let urlString = try await ConvexClient.shared.getFileUrl(storageId: storageId)

            // Check if task was cancelled
            try Task.checkCancellation()

            if let url = URL(string: urlString) {
                videoURL = url
            } else {
                loadFailed = true
            }
        } catch is CancellationError {
            // Task was cancelled (user navigated away), this is normal - don't log error
            return
        } catch {
            // Only log non-cancellation errors
            print("❌ Failed to load video URL from Convex: \(error)")
            loadFailed = true
        }

        isLoading = false
    }

    private func setupPlayer(url: URL) {
        let player = AVPlayer(url: url)
        player.isMuted = isMuted
        player.actionAtItemEnd = .none

        // Loop video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        self.player = player
    }

    private var placeholderView: some View {
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

// Simpler non-interactive video for collages
struct CollageMediaVideoView: View {
    let mediaItem: MediaItem
    @State private var videoURL: URL?
    @State private var isLoading = false
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .disabled(true)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else if isLoading {
                ZStack {
                    Color.gray.opacity(0.1)
                    ProgressView()
                        .tint(.white)
                }
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .task {
            await loadVideo()
        }
        .onChange(of: videoURL) { oldValue, newValue in
            if let url = newValue {
                setupPlayer(url: url)
            }
        }
    }

    private func loadVideo() async {
        // Check if we already have a URL
        if let existingURL = mediaItem.videoURL {
            videoURL = existingURL
            return
        }

        // Try to load from Convex storage
        guard let storageId = mediaItem.storageId, !storageId.isEmpty else {
            return
        }

        isLoading = true

        do {
            let urlString = try await ConvexClient.shared.getFileUrl(storageId: storageId)
            try Task.checkCancellation()

            if let url = URL(string: urlString) {
                videoURL = url
            }
        } catch is CancellationError {
            return
        } catch {
            print("❌ Failed to load video URL: \(error)")
        }

        isLoading = false
    }

    private func setupPlayer(url: URL) {
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none

        // Loop video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        self.player = player
    }
}
