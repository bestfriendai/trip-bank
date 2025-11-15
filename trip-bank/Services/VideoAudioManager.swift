import SwiftUI
import AVKit

// Global manager to ensure only one video plays audio at a time
@MainActor
class VideoAudioManager: ObservableObject {
    static let shared = VideoAudioManager()

    @Published private(set) var currentlyPlayingVideoId: UUID?
    @Published var isExpandedViewActive = false // Track if expanded moment view is open

    private init() {}

    func requestAudioPlayback(for videoId: UUID) {
        currentlyPlayingVideoId = videoId
    }

    func stopAudioPlayback(for videoId: UUID) {
        if currentlyPlayingVideoId == videoId {
            currentlyPlayingVideoId = nil
        }
    }

    func stopAllAudio() {
        currentlyPlayingVideoId = nil
    }

    func isPlaying(videoId: UUID) -> Bool {
        currentlyPlayingVideoId == videoId
    }
}
