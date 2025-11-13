import SwiftUI

struct NewTripView: View {
    let trip: Trip? // Optional: if provided, we're editing
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var tripStore: TripStore

    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isCreating = false
    @State private var showError = false

    private var isEditing: Bool {
        trip != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Trip Name", text: $title)
                } header: {
                    Text("Trip Details")
                }

                Section {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                } header: {
                    Text("Dates")
                }

                if isCreating {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Creating trip...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Trip" : "New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let trip = trip {
                    title = trip.title
                    startDate = trip.startDate
                    endDate = trip.endDate
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        if isEditing {
                            updateTrip()
                        } else {
                            createTrip()
                        }
                    }
                    .disabled(title.isEmpty || isCreating)
                }
            }
            .alert("Error Creating Trip", isPresented: $showError) {
                Button("OK", role: .cancel) {
                    showError = false
                }
            } message: {
                if let errorMessage = tripStore.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private func createTrip() {
        isCreating = true

        let newTrip = Trip(
            title: title,
            startDate: startDate,
            endDate: endDate
        )

        tripStore.addTrip(newTrip)

        // Give a brief moment for the backend call to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isCreating = false

            if tripStore.errorMessage != nil {
                showError = true
            } else {
                dismiss()
            }
        }
    }

    private func updateTrip() {
        guard let existingTrip = trip else { return }
        isCreating = true

        var updatedTrip = existingTrip
        updatedTrip.title = title
        updatedTrip.startDate = startDate
        updatedTrip.endDate = endDate

        tripStore.updateTrip(updatedTrip)

        // Give a brief moment for the backend call to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isCreating = false

            if tripStore.errorMessage != nil {
                showError = true
            } else {
                dismiss()
            }
        }
    }
}

#Preview {
    NewTripView(trip: nil)
        .environmentObject(TripStore())
}
