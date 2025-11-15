import SwiftUI

// Full-screen expanded view of a moment
struct ExpandedMomentView: View {
    let moment: Moment
    let mediaItems: [MediaItem]
    let tripId: UUID
    @Binding var isPresented: Bool
    @EnvironmentObject var tripStore: TripStore

    @State private var currentPhotoIndex = 0
    @State private var showingEditMoment = false
    @State private var showingDeleteConfirmation = false
    @StateObject private var audioManager = VideoAudioManager.shared

    private var currentMediaItem: MediaItem? {
        guard !mediaItems.isEmpty, currentPhotoIndex < mediaItems.count else { return nil }
        return mediaItems[currentPhotoIndex]
    }

    private var isCurrentMediaVideo: Bool {
        currentMediaItem?.type == .video
    }

    private var isMuted: Bool {
        guard let mediaItem = currentMediaItem else { return true }
        return !audioManager.isPlaying(videoId: mediaItem.id)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with close and menu buttons
                HStack {
                    Menu {
                        Button {
                            showingEditMoment = true
                        } label: {
                            Label("Edit Moment", systemImage: "pencil")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Moment", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding()
                    }

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding()
                    }
                }

                // Media carousel (photos and videos)
                if !mediaItems.isEmpty {
                    ZStack(alignment: .bottomTrailing) {
                        TabView(selection: $currentPhotoIndex) {
                            ForEach(mediaItems.indices, id: \.self) { index in
                                let mediaItem = mediaItems[index]
                                if mediaItem.type == .video {
                                    MediaVideoView(mediaItem: mediaItem, isInExpandedView: true)
                                        .id(mediaItem.id)
                                        .scaledToFit()
                                        .tag(index)
                                } else {
                                    MediaImageView(mediaItem: mediaItem)
                                        .id(mediaItem.id)
                                        .scaledToFit()
                                        .tag(index)
                                }
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .always))
                        .frame(maxHeight: 500)

                        // Mute button for videos
                        if isCurrentMediaVideo, let mediaItem = currentMediaItem {
                            MuteButton(videoId: mediaItem.id, isMuted: isMuted)
                                .padding(16)
                        }
                    }
                }

                // Moment details
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text(moment.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    // Metadata
                    VStack(alignment: .leading, spacing: 8) {
                        if let placeName = moment.placeName {
                            Label(placeName, systemImage: "mappin.circle.fill")
                                .foregroundStyle(.white.opacity(0.9))
                        }

                        if let eventName = moment.eventName {
                            Label(eventName, systemImage: "star.fill")
                                .foregroundStyle(.white.opacity(0.9))
                        }

                        if let date = moment.date {
                            Label(formatDate(date), systemImage: "calendar")
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .font(.subheadline)

                    // Note
                    if let note = moment.note {
                        Text(note)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.top, 8)
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
        }
        .onAppear {
            // Mute all canvas videos when expanded view opens
            audioManager.isExpandedViewActive = true
            audioManager.stopAllAudio()
        }
        .onDisappear {
            // Re-enable canvas video audio when expanded view closes
            audioManager.isExpandedViewActive = false
            audioManager.stopAllAudio()
        }
        .sheet(isPresented: $showingEditMoment) {
            if let trip = tripStore.trips.first(where: { $0.id == tripId }) {
                CreateMomentView(trip: trip, moment: moment)
            }
        }
        .alert("Delete Moment?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteMoment()
            }
        } message: {
            Text("This will permanently delete this moment. The photos will remain in your trip.")
        }
        .transition(.scale.combined(with: .opacity))
    }

    private func deleteMoment() {
        tripStore.deleteMoment(from: tripId, momentID: moment.id)
        isPresented = false
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
