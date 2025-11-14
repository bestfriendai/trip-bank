import Foundation

// Moment represents a collection of photos/videos from a specific experience
// e.g., "Hiking to the waterfall", "Sunset at the beach", "Dinner in Lisbon"
struct Moment: Identifiable, Codable {
    let id: UUID
    var title: String
    var note: String? // Text description
    var mediaItemIDs: [UUID] // References to MediaItem IDs
    var timestamp: Date

    // Enhanced metadata from prompt requirements
    var date: Date? // When this moment happened
    var placeName: String? // "Golden Gate Bridge", "Louvre Museum"
    var eventName: String? // "Birthday celebration", "Wedding ceremony"
    var voiceNoteURL: String? // Path to audio file (future feature)

    // Visual layout properties for spatial canvas
    var gridPosition: GridPosition // Position and size in grid

    init(id: UUID = UUID(),
         title: String,
         note: String? = nil,
         mediaItemIDs: [UUID] = [],
         timestamp: Date = Date(),
         date: Date? = nil,
         placeName: String? = nil,
         eventName: String? = nil,
         voiceNoteURL: String? = nil,
         gridPosition: GridPosition) {
        self.id = id
        self.title = title
        self.note = note
        self.mediaItemIDs = mediaItemIDs
        self.timestamp = timestamp
        self.date = date
        self.placeName = placeName
        self.eventName = eventName
        self.voiceNoteURL = voiceNoteURL
        self.gridPosition = gridPosition
    }
}

// Grid position in 2-column masonry layout
struct GridPosition: Codable, Equatable {
    var column: Int // 0 = left, 1 = right
    var row: Double // 0, 0.5, 1, 1.5, 2, 2.5, 3, etc.
    var width: Int // 1 or 2 (columns)
    var height: Double // 1, 1.5, 2, 2.5, 3, etc. (rows)
}
