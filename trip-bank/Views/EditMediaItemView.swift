import SwiftUI

// View for editing a media item's note and capture date
struct EditMediaItemView: View {
    let trip: Trip
    let mediaItem: MediaItem
    @EnvironmentObject var tripStore: TripStore
    @Environment(\.dismiss) var dismiss

    @State private var note: String
    @State private var captureDate: Date

    init(trip: Trip, mediaItem: MediaItem) {
        self.trip = trip
        self.mediaItem = mediaItem
        _note = State(initialValue: mediaItem.note ?? "")
        _captureDate = State(initialValue: mediaItem.captureDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    MediaImageView(mediaItem: mediaItem)
                        .scaledToFit()
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                }

                Section("Caption") {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                }

                Section("Date Taken") {
                    DatePicker("Capture Date", selection: $captureDate, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("Edit Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
        }
    }

    private func saveChanges() {
        var updatedMediaItem = mediaItem
        updatedMediaItem.note = note.isEmpty ? nil : note
        updatedMediaItem.captureDate = captureDate

        tripStore.updateMediaItem(in: trip.id, mediaItem: updatedMediaItem)
        dismiss()
    }
}

#Preview {
    EditMediaItemView(
        trip: Trip(title: "Test Trip"),
        mediaItem: MediaItem(type: .photo)
    )
    .environmentObject(TripStore())
}
