import SwiftUI

// Main grid-based canvas view for displaying trip moments
struct TripCanvasView: View {
    let tripId: UUID
    @EnvironmentObject var tripStore: TripStore
    @State private var selectedMoment: Moment?
    @State private var showingExpandedMoment = false
    @State private var canvasSize: CGSize = .zero
    @State private var appearingMoments: Set<UUID> = []

    // Drag state
    @State private var draggingMoment: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartPosition: CGPoint = .zero

    // Resize state
    @State private var showingResizePicker = false
    @State private var resizingMoment: Moment?
    @State private var previewWidth: Double = 1
    @State private var previewHeight: Double = 1.5

    // Get the latest version of the trip from the store
    private var trip: Trip {
        tripStore.trips.first(where: { $0.id == tripId }) ?? Trip(id: tripId, title: "Unknown")
    }

    private var momentLayouts: [UUID: MomentLayout] {
        GridLayoutCalculator.calculateLayout(for: trip.moments, canvasWidth: canvasSize.width)
    }

    private var sortedMoments: [Moment] {
        trip.moments.sorted { $0.gridPosition.row < $1.gridPosition.row }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Only render if canvas has valid size
                    if canvasSize.width > 0 && canvasSize.height > 0 {
                        // Grid overlay (debug - can remove later)
                        gridOverlay

                        // Moments on canvas
                        ForEach(Array(trip.moments.enumerated()), id: \.element.id) { index, moment in
                            if let layout = momentLayouts[moment.id],
                               layout.size.width > 0,
                               layout.size.height > 0 {
                                momentCardView(for: moment, at: index, with: layout)
                            }
                        }
                    }
                }
                .frame(
                    width: geometry.size.width,
                    height: max(geometry.size.height, canvasContentHeight)
                )
            }
            .onAppear {
                if geometry.size.width > 0 && geometry.size.height > 0 {
                    canvasSize = geometry.size
                }

                // Trigger staggered entrance animations
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    for moment in trip.moments {
                        appearingMoments.insert(moment.id)
                    }
                }
            }
            .onChange(of: geometry.size) { _, newSize in
                if newSize.width > 0 && newSize.height > 0 {
                    canvasSize = newSize
                }
            }
            .onChange(of: trip.moments.count) { _, _ in
                // Add any new moments to the appearing set
                for moment in trip.moments {
                    if !appearingMoments.contains(moment.id) {
                        appearingMoments.insert(moment.id)
                    }
                }
            }
        }
        .overlay {
            if showingExpandedMoment, let moment = selectedMoment {
                ExpandedMomentView(
                    moment: moment,
                    mediaItems: mediaItemsForMoment(moment),
                    tripId: tripId,
                    isPresented: $showingExpandedMoment
                )
            }
        }
        .overlay {
            if showingResizePicker, let moment = resizingMoment {
                resizePickerOverlay(for: moment)
            }
        }
    }

    // MARK: - Resize Picker Overlay

    @ViewBuilder
    private func resizePickerOverlay(for moment: Moment) -> some View {
        ZStack {
            // Dark background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    finishResizing(moment)
                }

            VStack(spacing: 30) {
                Text("Resize '\(moment.title)'")
                    .font(.headline)
                    .foregroundStyle(.white)

                MomentSizePicker(
                    width: $previewWidth,
                    height: $previewHeight,
                    onChange: { updatePreviewSize(for: moment) }
                )
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Done button
                Button(action: {
                    finishResizing(moment)
                }) {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            .padding(30)
        }
    }

    // MARK: - Grid Overlay (for debugging)

    @ViewBuilder
    private var gridOverlay: some View {
        Canvas { context, size in
            let columnWidth = (canvasSize.width - (GridLayoutCalculator.sideMargin * 2) - GridLayoutCalculator.columnSpacing) / CGFloat(GridLayoutCalculator.numberOfColumns)

            // Draw column divider
            let dividerX = GridLayoutCalculator.sideMargin + columnWidth + (GridLayoutCalculator.columnSpacing / 2)
            var path = Path()
            path.move(to: CGPoint(x: dividerX, y: 0))
            path.addLine(to: CGPoint(x: dividerX, y: canvasContentHeight))

            context.stroke(
                path,
                with: .color(.white.opacity(0.1)),
                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
            )

            // Draw row lines every 0.5 rows
            for rowIndex in stride(from: 0, to: 20, by: 0.5) {
                let y = CGFloat(rowIndex) * (GridLayoutCalculator.rowHeight + GridLayoutCalculator.rowSpacing)
                var rowPath = Path()
                rowPath.move(to: CGPoint(x: 0, y: y))
                rowPath.addLine(to: CGPoint(x: canvasSize.width, y: y))

                context.stroke(
                    rowPath,
                    with: .color(.white.opacity(0.05)),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 2])
                )
            }
        }
    }

    private var canvasContentHeight: CGFloat {
        let maxY = momentLayouts.values.map { $0.position.y + $0.size.height }.max() ?? 0
        return maxY + 100 // Add bottom padding
    }

    private func mediaItemsForMoment(_ moment: Moment) -> [MediaItem] {
        trip.mediaItems.filter { moment.mediaItemIDs.contains($0.id) }
    }

    // MARK: - Moment Card View

    @ViewBuilder
    private func momentCardView(for moment: Moment, at index: Int, with layout: MomentLayout) -> some View {
        let isDragging = draggingMoment == moment.id
        let isOtherBeingDragged = draggingMoment != nil && draggingMoment != moment.id

        MomentCardView(
            moment: moment,
            mediaItems: mediaItemsForMoment(moment),
            size: layout.size,
            onTap: {
                guard draggingMoment == nil else { return }
                selectedMoment = moment
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showingExpandedMoment = true
                }
            }
        )
        .position(
            x: layout.position.x + layout.size.width / 2,
            y: layout.position.y + layout.size.height / 2
        )
        .offset(isDragging ? dragOffset : .zero)
        .scaleEffect(isDragging ? 1.03 : 1.0)
        .opacity(isOtherBeingDragged ? 0.3 : (appearingMoments.contains(moment.id) ? 1.0 : 0.0))
        .shadow(
            color: .black.opacity(isDragging ? 0.4 : 0),
            radius: isDragging ? 20 : 0,
            x: 0,
            y: isDragging ? 10 : 0
        )
        .zIndex(isDragging ? 1000 : Double(layout.zIndex))
        .animation(
            isDragging ? nil : .spring(response: 0.6, dampingFraction: 0.75).delay(Double(index) * 0.1),
            value: appearingMoments
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    startDragging(moment, at: layout.position)
                }
        )
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    guard draggingMoment == moment.id else { return }
                    dragOffset = value.translation
                }
                .onEnded { value in
                    guard draggingMoment == moment.id else { return }
                    handleDragEnd(value, for: moment)
                }
        )
        .onTapGesture(count: 2) {
            // Double-tap to resize
            resizingMoment = moment
            previewWidth = Double(moment.gridPosition.width)
            previewHeight = moment.gridPosition.height
            showingResizePicker = true
        }
    }

    // MARK: - Drag Handlers

    private func startDragging(_ moment: Moment, at position: CGPoint) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            draggingMoment = moment.id
            dragOffset = .zero
            dragStartPosition = position
        }
    }

    private func handleDragEnd(_ value: DragGesture.Value, for moment: Moment) {
        // Calculate final position after drag
        let finalPosition = CGPoint(
            x: dragStartPosition.x + value.translation.width,
            y: dragStartPosition.y + value.translation.height
        )

        // Convert to grid position
        let newGridPosition = pixelToGridPosition(finalPosition, momentSize: moment.gridPosition)

        // Update moment locally (optimistic) and reflow
        var reflowedMoments: [Moment] = []
        if let tripIndex = tripStore.trips.firstIndex(where: { $0.id == tripId }),
           let momentIndex = tripStore.trips[tripIndex].moments.firstIndex(where: { $0.id == moment.id }) {

            // Update this moment's position
            tripStore.trips[tripIndex].moments[momentIndex].gridPosition = newGridPosition

            // Reflow all moments to pack from top
            reflowedMoments = GridLayoutCalculator.reflowMoments(tripStore.trips[tripIndex].moments)
            tripStore.trips[tripIndex].moments = reflowedMoments
        }

        // Save ALL reflowed moments to backend
        Task {
            do {
                _ = try await ConvexClient.shared.batchUpdateMomentGridPositions(moments: reflowedMoments)
            } catch {
                print("❌ Failed to update moment positions: \(error)")
            }
        }

        // Reset drag state
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            draggingMoment = nil
            dragOffset = .zero
        }

        // Haptic feedback for drop
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    // MARK: - Grid Conversion

    private func pixelToGridPosition(_ pixel: CGPoint, momentSize: GridPosition) -> GridPosition {
        // Determine column (0 or 1)
        let columnWidth = (canvasSize.width - (GridLayoutCalculator.sideMargin * 2) - GridLayoutCalculator.columnSpacing) / CGFloat(GridLayoutCalculator.numberOfColumns)
        let midPoint = canvasSize.width / 2

        let column: Int
        if momentSize.width == 2 {
            // Full width always column 0
            column = 0
        } else {
            // Snap to nearest column
            column = pixel.x < midPoint ? 0 : 1
        }

        // Determine row (snap to 0.5 increments)
        let rawRow = pixel.y / (GridLayoutCalculator.rowHeight + GridLayoutCalculator.rowSpacing)
        let snappedRow = (rawRow * 2).rounded() / 2 // Snap to 0.5 increments
        let row = max(0, snappedRow)

        return GridPosition(
            column: column,
            row: row,
            width: momentSize.width,
            height: momentSize.height
        )
    }

    // MARK: - Resize Handlers

    private func updatePreviewSize(for moment: Moment) {
        // Update moment size locally in real-time
        if let tripIndex = tripStore.trips.firstIndex(where: { $0.id == tripId }),
           let momentIndex = tripStore.trips[tripIndex].moments.firstIndex(where: { $0.id == moment.id }) {

            // Update this moment's size
            var updatedPosition = tripStore.trips[tripIndex].moments[momentIndex].gridPosition
            updatedPosition.width = Int(previewWidth)
            updatedPosition.height = previewHeight
            tripStore.trips[tripIndex].moments[momentIndex].gridPosition = updatedPosition

            // Reflow all moments to pack from top
            let reflowedMoments = GridLayoutCalculator.reflowMoments(tripStore.trips[tripIndex].moments)
            tripStore.trips[tripIndex].moments = reflowedMoments
        }
    }

    private func finishResizing(_ moment: Moment) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Save ALL reflowed moments to backend
        Task {
            do {
                // Get all reflowed moments
                if let tripIndex = tripStore.trips.firstIndex(where: { $0.id == tripId }) {
                    let reflowedMoments = tripStore.trips[tripIndex].moments

                    _ = try await ConvexClient.shared.batchUpdateMomentGridPositions(moments: reflowedMoments)
                }
            } catch {
                print("❌ Failed to update moment sizes: \(error)")
            }
        }

        // Close picker
        showingResizePicker = false
        resizingMoment = nil
    }
}

#Preview {
    let sampleTrip = Trip(
        title: "Japan Adventure",
        startDate: Date(),
        endDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
        moments: [
            Moment(
                title: "Tokyo Tower at Night",
                note: "Incredible city views",
                mediaItemIDs: [],
                placeName: "Tokyo Tower",
                importance: .hero,
                gridPosition: GridPosition(column: 0, row: 0, width: 2, height: 2.0)
            ),
            Moment(
                title: "Ramen in Shibuya",
                note: "Best meal of the trip",
                mediaItemIDs: [],
                placeName: "Shibuya",
                importance: .medium,
                gridPosition: GridPosition(column: 0, row: 2.0, width: 1, height: 1.5)
            ),
            Moment(
                title: "Temple Visit",
                note: "Peaceful and beautiful",
                mediaItemIDs: [],
                placeName: "Senso-ji",
                importance: .large,
                gridPosition: GridPosition(column: 1, row: 2.0, width: 1, height: 2.0)
            )
        ]
    )

    let store = TripStore()
    store.trips = [sampleTrip]

    return TripCanvasView(tripId: sampleTrip.id)
        .environmentObject(store)
}
