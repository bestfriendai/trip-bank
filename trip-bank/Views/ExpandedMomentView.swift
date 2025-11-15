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
                    TabView(selection: $currentPhotoIndex) {
                        ForEach(mediaItems.indices, id: \.self) { index in
                            let mediaItem = mediaItems[index]
                            if mediaItem.type == .video {
                                MediaVideoView(mediaItem: mediaItem)
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
