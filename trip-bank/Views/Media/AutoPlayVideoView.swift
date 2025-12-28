import SwiftUI
import AVKit

// Auto-playing video view that loops and is muted by default
struct AutoPlayVideoView: View {
    let videoURL: URL
    @State private var player: AVPlayer?
    @State private var isMuted = true
    @State private var loopObserver: NSObjectProtocol? // ✅ Store observer for cleanup

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let player = player {
                VideoPlayer(player: player)
                    .disabled(true) // Disable default controls
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        cleanupPlayer()
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
                .accessibilityLabel(isMuted ? "Unmute video" : "Mute video")
            }
        }
        .onAppear {
            setupPlayer()
        }
    }

    private func setupPlayer() {
        // ✅ Clean up any existing player first
        cleanupPlayer()

        let player = AVPlayer(url: videoURL)
        player.isMuted = isMuted
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

// Simpler non-interactive auto-play video for collages
// ✅ FIXED: setupPlayer is now called via onAppear
struct CollageVideoView: View {
    let videoURL: URL
    @State private var player: AVPlayer?
    @State private var loopObserver: NSObjectProtocol? // ✅ Store observer for cleanup

    var body: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
                    .disabled(true)
            } else {
                // Show placeholder while player is initializing
                Color.gray.opacity(0.2)
            }
        }
        .onAppear {
            setupPlayer() // ✅ FIX: Actually call setupPlayer!
            player?.play()
        }
        .onDisappear {
            cleanupPlayer()
        }
    }

    private func setupPlayer() {
        // ✅ Clean up existing player first
        cleanupPlayer()

        let player = AVPlayer(url: videoURL)
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
