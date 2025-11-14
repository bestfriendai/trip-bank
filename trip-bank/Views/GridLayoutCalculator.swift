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

    // Map importance to default grid size
    static func gridSizeFromImportance(_ importance: MomentImportance) -> GridPosition {
        switch importance {
        case .small:
            return GridPosition(column: 0, row: 0, width: 1, height: 1.0)
        case .medium:
            return GridPosition(column: 0, row: 0, width: 1, height: 1.5)
        case .large:
            return GridPosition(column: 0, row: 0, width: 1, height: 2.0)
        case .hero:
            return GridPosition(column: 0, row: 0, width: 2, height: 2.0)
        }
    }

    // Reflow all moments to pack from top (used after drag/resize)
    static func reflowMoments(_ moments: [Moment]) -> [Moment] {
        var reflowedMoments: [Moment] = []
        var columnHeights: [Double] = [0, 0]

        // Sort by current row position (top to bottom)
        let sortedMoments = moments.sorted { $0.gridPosition.row < $1.gridPosition.row }

        for var moment in sortedMoments {
            if moment.gridPosition.width == 2 {
                // Full width - place after both columns are clear
                let maxHeight = columnHeights.max() ?? 0
                moment.gridPosition.row = maxHeight
                moment.gridPosition.column = 0

                // Update both columns
                let endRow = maxHeight + moment.gridPosition.height
                columnHeights[0] = endRow
                columnHeights[1] = endRow
            } else {
                // Single column - place in shortest column
                let shortestColumn = columnHeights[0] <= columnHeights[1] ? 0 : 1
                moment.gridPosition.column = shortestColumn
                moment.gridPosition.row = columnHeights[shortestColumn]

                // Update that column
                columnHeights[shortestColumn] += moment.gridPosition.height
            }

            reflowedMoments.append(moment)
        }

        return reflowedMoments
    }
}

// Layout information for a single moment
struct MomentLayout {
    let position: CGPoint
    let size: CGSize
    let zIndex: Int
}
