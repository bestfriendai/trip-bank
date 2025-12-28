import SwiftUI

struct JoinTripView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var tripStore: TripStore
    @State private var tripCode = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var joinedTripId: String?

    var body: some View {
        // ✅ FIXED: Use NavigationStack instead of deprecated NavigationView
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Header Icon
                Image(systemName: "ticket.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(.blue)
                    .padding(.bottom, 8)
                    // ✅ ACCESSIBILITY: Mark as decorative
                    .accessibilityHidden(true)

                // Title & Description
                VStack(spacing: 12) {
                    Text("Join a Trip")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Enter the trip code to join")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                // Trip Code Input
                VStack(spacing: 12) {
                    TextField("TRIP CODE", text: $tripCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                        .disabled(isJoining)
                        // ✅ ACCESSIBILITY: Add descriptive label
                        .accessibilityLabel("Trip code")
                        .accessibilityHint("Enter the 6-character trip code shared with you")

                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(error)
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 40)

                // Join Button
                Button {
                    Task {
                        await joinTrip()
                    }
                } label: {
                    if isJoining {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Join Trip")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(tripCode.isEmpty || isJoining)
                .padding(.horizontal, 40)
                // ✅ ACCESSIBILITY: Add descriptive label
                .accessibilityLabel(isJoining ? "Joining trip" : "Join trip")
                .accessibilityHint(tripCode.isEmpty ? "Enter a trip code first" : "Double tap to join this trip")

                Spacer()

                // Info Text
                Text("Ask the trip owner for the trip code")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
            }
            .navigationTitle("Join Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func joinTrip() async {
        isJoining = true
        errorMessage = nil

        do {
            let response = try await ConvexClient.shared.joinTripViaLink(
                shareSlug: nil,
                shareCode: tripCode.uppercased()
            )

            if response.alreadyMember {
                errorMessage = "You're already a member of this trip"
            } else {
                // Success! Reload trips to show the newly joined trip
                await tripStore.loadTrips()
                dismiss()
            }
        } catch {
            if let convexError = error as? ConvexError {
                errorMessage = convexError.localizedDescription
            } else {
                errorMessage = "Invalid trip code. Please try again."
            }
            print("Error joining trip: \(error)")
        }

        isJoining = false
    }
}
