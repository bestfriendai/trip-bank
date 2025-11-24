import SwiftUI

// Grid-based masonry layout calculator for 2-column layout
struct GridLayoutCalculator {

    // Constants
    static let numberOfColumns = 2
    static let sideMargin: CGFloat = 16
    static let columnSpacing: CGFloat = 10
    static let rowSpacing: CGFloat = 10 // Spacing between rows
    static let rowHeight: CGFloat = 100 // Base height for 1.0 row unit

    // Calculate pixel layouts from grid positions
    static func calculateLayout(for moments: [Moment], canvasWidth: CGFloat) -> [UUID: MomentLayout] {
        var layouts: [UUID: MomentLayout] = [:]

        guard canvasWidth > 0 else { return layouts }

        // Calculate column width
        let availableWidth = canvasWidth - (sideMargin * 2) - columnSpacing
        let columnWidth = availableWidth / CGFloat(numberOfColumns)

        for (index, moment) in moments.enumerated() {
            let gridPos = moment.gridPosition

            // Calculate pixel position from grid position
            let x = sideMargin + (CGFloat(gridPos.column) * (columnWidth + columnSpacing))
            let y = CGFloat(gridPos.row) * (rowHeight + rowSpacing)

            // Calculate size from grid dimensions
            let width = (CGFloat(gridPos.width) * columnWidth) + (CGFloat(gridPos.width - 1) * columnSpacing)
            let height = CGFloat(gridPos.height) * (rowHeight + rowSpacing) - rowSpacing

            layouts[moment.id] = MomentLayout(
                position: CGPoint(x: x, y: y),
                size: CGSize(width: width, height: height),
                zIndex: index
            )
        }

        return layouts
    }

    // Calculate next available grid position for a new moment
    static func calculateNextGridPosition(
        existingMoments: [Moment],
        momentSize: GridPosition
    ) -> GridPosition {
        // If no moments, start at top
        guard !existingMoments.isEmpty else {
            return GridPosition(column: 0, row: 0, width: momentSize.width, height: momentSize.height)
        }

        // Track column heights (where each column currently ends)
        var columnHeights: [Double] = [0, 0]

        // Calculate where each column ends based on existing moments
        for moment in existingMoments {
            let endRow = moment.gridPosition.row + moment.gridPosition.height

            if moment.gridPosition.width == 2 {
                // Full width moment - both columns end at same height
                columnHeights[0] = max(columnHeights[0], endRow)
                columnHeights[1] = max(columnHeights[1], endRow)
            } else {
                // Single column moment
                let col = moment.gridPosition.column
                columnHeights[col] = max(columnHeights[col], endRow)
            }
        }

        // Find best placement for new moment
        if momentSize.width == 2 {
            // Full width - must start after both columns are clear
            let maxHeight = columnHeights.max() ?? 0
            return GridPosition(column: 0, row: maxHeight, width: 2, height: momentSize.height)
        } else {
            // Single column - place in shortest column
            let shortestColumn = columnHeights[0] <= columnHeights[1] ? 0 : 1
            return GridPosition(
                column: shortestColumn,
                row: columnHeights[shortestColumn],
                width: 1,
                height: momentSize.height
            )
        }
    }

    // Reflow all moments to pack from top (used after drag/resize)
    // If pinnedMomentId is provided, that moment keeps its exact position and others reflow around it
    static func reflowMoments(_ moments: [Moment], pinnedMomentId: UUID? = nil) -> [Moment] {
        var reflowedMoments: [Moment] = []

        // Track occupied ranges in each column (to handle gaps properly)
        var columnRanges: [[ClosedRange<Double>]] = [[], []]

        // If there's a pinned moment, find it and track its space
        var pinnedMoment: Moment?
        var momentsToReflow: [Moment] = []

        for moment in moments {
            if moment.id == pinnedMomentId {
                pinnedMoment = moment
                // Reserve the pinned moment's exact range
                let startRow = moment.gridPosition.row
                let endRow = startRow + moment.gridPosition.height

                if moment.gridPosition.width == 2 {
                    // Full width - occupies both columns
                    columnRanges[0].append(startRow...endRow)
                    columnRanges[1].append(startRow...endRow)
                } else {
                    // Single column
                    let col = moment.gridPosition.column
                    columnRanges[col].append(startRow...endRow)
                }
            } else {
                momentsToReflow.append(moment)
            }
        }

        // Sort remaining moments by current row position (top to bottom)
        let sortedMoments = momentsToReflow.sorted { $0.gridPosition.row < $1.gridPosition.row }

        for var moment in sortedMoments {
            if moment.gridPosition.width == 2 {
                // Full width - find first spot where both columns are clear
                let placementRow = findNextAvailableRow(
                    height: moment.gridPosition.height,
                    columnRanges: [columnRanges[0] + columnRanges[1]], // Combined ranges
                    startSearchFrom: 0
                )

                moment.gridPosition.row = placementRow
                moment.gridPosition.column = 0

                // Add to both columns
                let endRow = placementRow + moment.gridPosition.height
                columnRanges[0].append(placementRow...endRow)
                columnRanges[1].append(placementRow...endRow)
            } else {
                // Single column - find which column can fit it earliest
                let row0 = findNextAvailableRow(
                    height: moment.gridPosition.height,
                    columnRanges: [columnRanges[0]],
                    startSearchFrom: 0
                )
                let row1 = findNextAvailableRow(
                    height: moment.gridPosition.height,
                    columnRanges: [columnRanges[1]],
                    startSearchFrom: 0
                )

                // Place in column that can fit it earliest
                if row0 <= row1 {
                    moment.gridPosition.column = 0
                    moment.gridPosition.row = row0
                    columnRanges[0].append(row0...(row0 + moment.gridPosition.height))
                } else {
                    moment.gridPosition.column = 1
                    moment.gridPosition.row = row1
                    columnRanges[1].append(row1...(row1 + moment.gridPosition.height))
                }
            }

            reflowedMoments.append(moment)
        }

        // Add pinned moment back in its original position
        if let pinned = pinnedMoment {
            reflowedMoments.append(pinned)
        }

        return reflowedMoments
    }

    // Helper: Find next available row in a column that can fit a moment of given height
    private static func findNextAvailableRow(height: Double, columnRanges: [[ClosedRange<Double>]], startSearchFrom: Double) -> Double {
        // Flatten all ranges from all columns (for full-width checks)
        let allRanges = columnRanges.flatMap { $0 }.sorted { $0.lowerBound < $1.lowerBound }

        if allRanges.isEmpty {
            return startSearchFrom
        }

        var searchRow = startSearchFrom

        for range in allRanges {
            // Check if we can fit before this range
            if searchRow + height <= range.lowerBound {
                return searchRow
            }
            // Otherwise, try after this range
            searchRow = max(searchRow, range.upperBound)
        }

        // No gaps found, place at the end
        return searchRow
    }
}

// Layout information for a single moment
struct MomentLayout {
    let position: CGPoint
    let size: CGSize
    let zIndex: Int
}
