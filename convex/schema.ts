import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  // User table for Clerk integration
  users: defineTable({
    clerkId: v.string(), // Clerk user ID
    email: v.optional(v.string()),
    name: v.optional(v.string()),
    imageUrl: v.optional(v.string()),
    createdAt: v.number(),
  }).index("by_clerkId", ["clerkId"]),

  trips: defineTable({
    // Core fields
    userId: v.string(), // Owner of the trip
    tripId: v.string(), // UUID from Swift
    title: v.string(),
    startDate: v.number(), // Timestamp
    endDate: v.number(), // Timestamp
    coverImageName: v.optional(v.string()),
    coverImageStorageId: v.optional(v.id("_storage")), // Convex file storage

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_tripId", ["tripId"])
    .index("by_userId", ["userId"])
    .index("by_userId_createdAt", ["userId", "createdAt"]),

  mediaItems: defineTable({
    // Core fields
    userId: v.string(), // Owner
    mediaItemId: v.string(), // UUID from Swift
    tripId: v.string(), // Reference to parent trip
    storageId: v.optional(v.id("_storage")), // Convex file storage ID
    imageURL: v.optional(v.string()),
    videoURL: v.optional(v.string()),
    type: v.union(v.literal("photo"), v.literal("video")),
    captureDate: v.optional(v.number()), // Timestamp
    note: v.optional(v.string()),
    timestamp: v.number(), // When added to trip

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_tripId", ["tripId"])
    .index("by_mediaItemId", ["mediaItemId"])
    .index("by_userId", ["userId"]),

  moments: defineTable({
    // Core fields
    userId: v.string(), // Owner
    momentId: v.string(), // UUID from Swift
    tripId: v.string(), // Reference to parent trip
    title: v.string(),
    note: v.optional(v.string()),
    mediaItemIDs: v.array(v.string()), // Array of UUID strings
    timestamp: v.number(),

    // Enhanced metadata
    date: v.optional(v.number()), // Timestamp
    placeName: v.optional(v.string()),
    eventName: v.optional(v.string()),
    voiceNoteURL: v.optional(v.string()),

    // Visual layout properties
    gridPosition: v.object({
      column: v.number(), // 0 = left, 1 = right
      row: v.number(), // 0, 0.5, 1, 1.5, 2, 2.5, 3, etc.
      width: v.number(), // 1 or 2 (columns)
      height: v.number(), // 1, 1.5, 2, 2.5, 3, etc. (rows)
    }),

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_tripId", ["tripId"])
    .index("by_momentId", ["momentId"])
    .index("by_userId", ["userId"]),
});
