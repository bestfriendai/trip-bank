import SwiftUI

// View for managing (editing/deleting) media items in a trip
struct ManageMediaView: View {
    let trip: Trip
    @EnvironmentObject var tripStore: TripStore
    @Environment(\.dismiss) var dismiss

    @State private var selectedMediaItem: MediaItem?
    @State private var showingDeleteConfirmation = false
    @State private var showingEditSheet = false

    // Get the latest version of the trip from the store
    private var currentTrip: Trip {
        tripStore.trips.first(where: { $0.id == trip.id }) ?? trip
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if currentTrip.mediaItems.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100), spacing: 12)
                    ], spacing: 12) {
                        ForEach(currentTrip.mediaItems) { mediaItem in
                            MediaItemTile(mediaItem: mediaItem)
                                .contextMenu {
                                    Button {
                                        selectedMediaItem = mediaItem
                                        showingEditSheet = true
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        selectedMediaItem = mediaItem
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Manage Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Photo?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteSelectedMedia()
                }
            } message: {
                Text("This photo will be removed from all moments and permanently deleted.")
            }
            .sheet(isPresented: $showingEditSheet) {
                if let mediaItem = selectedMediaItem {
                    EditMediaItemView(trip: trip, mediaItem: mediaItem)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Photos Yet")
                .font(.headline)
            Text("Add photos to your trip to see them here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func deleteSelectedMedia() {
        guard let mediaItem = selectedMediaItem else { return }
        tripStore.deleteMediaItem(from: trip.id, mediaItemID: mediaItem.id)
    }
}

// Tile view for a media item in the grid
struct MediaItemTile: View {
    let mediaItem: MediaItem

    var body: some View {
        MediaImageView(mediaItem: mediaItem)
            .id(mediaItem.id)
            .scaledToFill()
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ManageMediaView(trip: Trip(title: "Test Trip"))
        .environmentObject(TripStore())
}
