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
    @State private var isNoteExpanded = false
    @State private var isZoomed = false
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

    // Get the latest version of the moment from the store
    private var currentMoment: Moment {
        if let trip = tripStore.trips.first(where: { $0.id == tripId }),
           let latestMoment = trip.moments.first(where: { $0.id == moment.id }) {
            return latestMoment
        }
        return moment // fallback to original
    }

    // Computed permission based on current trip state
    private var canEdit: Bool {
        guard let trip = tripStore.trips.first(where: { $0.id == tripId }) else { return false }
        return tripStore.canEdit(trip: trip)
    }


    var body: some View {
        ZStack {
            // Full-screen media background
            if !mediaItems.isEmpty {
                TabView(selection: $currentPhotoIndex) {
                    ForEach(mediaItems.indices, id: \.self) { index in
                        let mediaItem = mediaItems[index]
                        if mediaItem.type == .video {
                            MediaVideoView(mediaItem: mediaItem, isInExpandedView: true)
                                .id(mediaItem.id)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .tag(index)
                        } else {
                            ZoomableScrollView(isZoomed: $isZoomed) {
                                MediaImageView(mediaItem: mediaItem)
                                    .id(mediaItem.id)
                                    .scaledToFit()
                            }
                            .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .scrollDisabled(isZoomed) // Disable swiping when zoomed
                .ignoresSafeArea()
                .onChange(of: currentPhotoIndex) { _, _ in
                    // Reset zoom when changing photos
                    isZoomed = false
                }
            }

            // Custom page indicators (more visible)
            if mediaItems.count > 1 {
                VStack {
                    HStack(spacing: 8) {
                        ForEach(0..<mediaItems.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPhotoIndex ? Color.white : Color.white.opacity(0.5))
                                .frame(width: 8, height: 8)
                                .shadow(color: .black.opacity(0.3), radius: 2)
                        }
                    }
                    .padding(.top, 16)

                    Spacer()
                }
            }

            // Top controls overlay
            VStack {
                HStack {
                    // Only show edit menu if user can edit
                    if canEdit {
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
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                .padding()
                        }
                    }

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            .padding()
                    }
                }
                .padding(.top, 8)

                Spacer()
            }

            // Bottom content overlay with gradient
            VStack {
                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    // Title
                    Text(currentMoment.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                    // Metadata
                    HStack(spacing: 16) {
                        if let placeName = currentMoment.placeName {
                            Label(placeName, systemImage: "mappin.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.95))
                        }

                        if let date = currentMoment.date {
                            Label(formatDate(date), systemImage: "calendar")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.95))
                        }
                    }
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                    // Note
                    if let note = currentMoment.note, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                .lineLimit(isNoteExpanded ? nil : 3)
                                .padding(.top, 4)

                            // Show "more/less" button if text is long
                            if note.count > 100 {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        isNoteExpanded.toggle()
                                    }
                                }) {
                                    Text(isNoteExpanded ? "Show less" : "Read more")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .padding(.top, 80)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(0.4),
                            .black.opacity(0.7),
                            .black.opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                )
            }

            // Mute button for videos (bottom right)
            if isCurrentMediaVideo, let mediaItem = currentMediaItem {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MuteButton(videoId: mediaItem.id, isMuted: isMuted)
                            .padding(.trailing, 20)
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            // Permissions are now computed properties

            // Video audio management
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
                CreateMomentView(trip: trip, moment: currentMoment)
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
    }

    private func deleteMoment() {
        tripStore.deleteMoment(from: tripId, momentID: moment.id)
        isPresented = false
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
