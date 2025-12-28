import SwiftUI
import AVKit

// View that displays video from Convex storage or remote URL
struct MediaVideoView: View {
    let mediaItem: MediaItem
    var isInExpandedView: Bool = false // Track if this is in expanded view

    @State private var videoURL: URL?
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var player: AVPlayer?
    @State private var loopObserver: NSObjectProtocol? // ✅ Store observer for cleanup
    @StateObject private var audioManager = VideoAudioManager.shared

    private var isMuted: Bool {
        // Canvas videos are muted when expanded view is active
        if !isInExpandedView && audioManager.isExpandedViewActive {
            return true
        }
        return !audioManager.isPlaying(videoId: mediaItem.id)
    }

    var body: some View {
        ZStack {
            if let url = videoURL, let player = player {
                VideoPlayer(player: player)
                    .disabled(true) // Disable default controls
                    .onAppear {
                        updatePlayerMuteState()
                        player.play()
                    }
                    .onDisappear {
                        cleanupPlayer()
                    }
                    // Continuously enforce mute state
                    .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { _ in
                        updatePlayerMuteState()
                    }
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
        .onChange(of: audioManager.currentlyPlayingVideoId) { oldValue, newValue in
            // Update mute state when another video starts/stops playing audio
            updatePlayerMuteState()
        }
        .onChange(of: audioManager.isExpandedViewActive) { oldValue, newValue in
            // Update mute state when expanded view opens/closes
            updatePlayerMuteState()
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

    private func toggleMute() {
        if isMuted {
            // Unmute this video (will mute all others via the manager)
            audioManager.requestAudioPlayback(for: mediaItem.id)
        } else {
            // Mute this video
            audioManager.stopAudioPlayback(for: mediaItem.id)
        }
        updatePlayerMuteState()
    }

    private func updatePlayerMuteState() {
        guard let player = player else { return }
        player.isMuted = isMuted
        // Also control volume to ensure no audio leaks through
        player.volume = isMuted ? 0.0 : 1.0
    }

    private func setupPlayer(url: URL) {
        // ✅ Clean up any existing player first
        cleanupPlayer()

        let player = AVPlayer(url: url)
        player.isMuted = true // Always start muted
        player.volume = 0.0 // Ensure no audio plays
        player.actionAtItemEnd = .none

        // ✅ Store observer reference for cleanup
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        self.player = player
    }

    // ✅ Proper cleanup to prevent memory leaks
    private func cleanupPlayer() {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        audioManager.stopAudioPlayback(for: mediaItem.id)
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
    @State private var loopObserver: NSObjectProtocol? // ✅ Store observer for cleanup

    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .disabled(true)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        cleanupPlayer()
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
        // ✅ Clean up existing player first
        cleanupPlayer()

        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none

        // ✅ Store observer reference for cleanup
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        self.player = player
    }

    // ✅ Proper cleanup to prevent memory leaks
    private func cleanupPlayer() {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }
}
