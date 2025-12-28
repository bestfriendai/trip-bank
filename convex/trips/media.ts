import { mutation, query } from "../_generated/server";
import { v } from "convex/values";
import { requireAuth } from "../auth";
import { canUserEdit } from "./permissions";
import { STORAGE_LIMITS } from "../storage";

// ✅ Helper function to format bytes for user-friendly messages
function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`;
}

// ============= MEDIA MUTATIONS =============

// Add a media item to a trip
export const addMediaItem = mutation({
  args: {
    mediaItemId: v.string(),
    tripId: v.string(),
    storageId: v.optional(v.id("_storage")),
    thumbnailStorageId: v.optional(v.id("_storage")),
    imageURL: v.optional(v.string()),
    videoURL: v.optional(v.string()),
    type: v.union(v.literal("photo"), v.literal("video")),
    captureDate: v.optional(v.number()),
    note: v.optional(v.string()),
    timestamp: v.number(),
    fileSize: v.optional(v.number()), // Size in bytes
    thumbnailSize: v.optional(v.number()), // Thumbnail size in bytes
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);

    // Check permission to edit trip
    if (!(await canUserEdit(ctx, args.tripId, userId))) {
      throw new Error("You don't have permission to add media to this trip");
    }

    // Calculate file size once (used for both validation and storage update)
    const newFileSize = (args.fileSize || 0) + (args.thumbnailSize || 0);

    // Get user to check storage limit
    const user = await ctx.db
      .query("users")
      .withIndex("by_clerkId", (q) => q.eq("clerkId", userId))
      .first();

    if (user) {
      const tier = user.subscriptionTier || "free";
      const limit = STORAGE_LIMITS[tier];

      // ✅ Validate file size is non-negative
      if (newFileSize < 0) {
        throw new Error("Invalid file size");
      }

      // ✅ Re-fetch user to get latest storage value (reduces race window)
      const latestUser = await ctx.db.get(user._id);
      if (!latestUser) {
        throw new Error("User not found");
      }

      const currentUsage = latestUser.storageUsedBytes || 0;

      if (currentUsage + newFileSize > limit) {
        const remaining = Math.max(0, limit - currentUsage);
        const remainingFormatted = formatBytes(remaining);
        throw new Error(`Storage limit exceeded. You have ${remainingFormatted} remaining. Please upgrade to Pro for more storage.`);
      }

      // Note: Storage update is done atomically with the media insert below
    }

    const now = Date.now();

    const mediaItemDocId = await ctx.db.insert("mediaItems", {
      userId,
      mediaItemId: args.mediaItemId,
      tripId: args.tripId,
      storageId: args.storageId,
      thumbnailStorageId: args.thumbnailStorageId,
      imageURL: args.imageURL,
      videoURL: args.videoURL,
      type: args.type,
      captureDate: args.captureDate,
      note: args.note,
      timestamp: args.timestamp,
      fileSize: args.fileSize,
      thumbnailSize: args.thumbnailSize,
      createdAt: now,
      updatedAt: now,
    });

    // ✅ Update storage usage AFTER successful insert (more atomic)
    if (user) {
      // Re-fetch to get current value and update
      const freshUser = await ctx.db.get(user._id);
      if (freshUser) {
        await ctx.db.patch(user._id, {
          storageUsedBytes: (freshUser.storageUsedBytes || 0) + newFileSize,
        });
      }
    }

    // Automatically set cover image if this is the first photo added to the trip
    if (args.type === "photo" && args.storageId) {
      const trip = await ctx.db
        .query("trips")
        .withIndex("by_tripId", (q) => q.eq("tripId", args.tripId))
        .first();

      if (trip && !trip.coverImageStorageId) {
        await ctx.db.patch(trip._id, {
          coverImageStorageId: args.storageId,
          coverImageName: args.mediaItemId,
          updatedAt: now,
        });
      }
    }

    return mediaItemDocId;
  },
});

// Update a media item
export const updateMediaItem = mutation({
  args: {
    mediaItemId: v.string(),
    note: v.optional(v.string()),
    captureDate: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);

    // Find the media item
    const mediaItem = await ctx.db
      .query("mediaItems")
      .withIndex("by_mediaItemId", (q) => q.eq("mediaItemId", args.mediaItemId))
      .first();

    if (!mediaItem) {
      throw new Error(`Media item not found: ${args.mediaItemId}`);
    }

    // Check permission to edit trip
    if (!(await canUserEdit(ctx, mediaItem.tripId, userId))) {
      throw new Error("You don't have permission to edit media in this trip");
    }

    const updates: any = {
      updatedAt: Date.now(),
    };

    if (args.note !== undefined) updates.note = args.note;
    if (args.captureDate !== undefined) updates.captureDate = args.captureDate;

    await ctx.db.patch(mediaItem._id, updates);
    return { success: true };
  },
});

// Delete a media item
export const deleteMediaItem = mutation({
  args: {
    mediaItemId: v.string(),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);

    // Find the media item
    const mediaItem = await ctx.db
      .query("mediaItems")
      .withIndex("by_mediaItemId", (q) => q.eq("mediaItemId", args.mediaItemId))
      .first();

    if (!mediaItem) {
      throw new Error(`Media item not found: ${args.mediaItemId}`);
    }

    // Check permission to edit trip
    if (!(await canUserEdit(ctx, mediaItem.tripId, userId))) {
      throw new Error("You don't have permission to delete media from this trip");
    }

    // Remove this media item from all moments that reference it
    const moments = await ctx.db
      .query("moments")
      .withIndex("by_tripId", (q) => q.eq("tripId", mediaItem.tripId))
      .collect();

    for (const moment of moments) {
      if (moment.mediaItemIDs.includes(args.mediaItemId)) {
        const updatedMediaItemIDs = moment.mediaItemIDs.filter(
          (id) => id !== args.mediaItemId
        );
        await ctx.db.patch(moment._id, {
          mediaItemIDs: updatedMediaItemIDs,
          updatedAt: Date.now(),
        });
      }
    }

    // Calculate storage to reclaim
    const bytesToReclaim = (mediaItem.fileSize || 0) + (mediaItem.thumbnailSize || 0);

    // Delete file from storage if it exists
    if (mediaItem.storageId) {
      await ctx.storage.delete(mediaItem.storageId);
    }

    // Delete thumbnail from storage if it exists
    if (mediaItem.thumbnailStorageId) {
      await ctx.storage.delete(mediaItem.thumbnailStorageId);
    }

    // Reclaim storage for the media owner (not necessarily current user)
    if (bytesToReclaim > 0) {
      const mediaOwner = await ctx.db
        .query("users")
        .withIndex("by_clerkId", (q) => q.eq("clerkId", mediaItem.userId))
        .first();

      if (mediaOwner) {
        const currentUsage = mediaOwner.storageUsedBytes || 0;
        await ctx.db.patch(mediaOwner._id, {
          storageUsedBytes: Math.max(0, currentUsage - bytesToReclaim),
        });
      }
    }

    // Delete the media item
    await ctx.db.delete(mediaItem._id);

    return { success: true };
  },
});

// ============= MEDIA QUERIES =============

// Get all media items for a trip
export const getMediaItems = query({
  args: {
    tripId: v.string(),
  },
  handler: async (ctx, args) => {
    const mediaItems = await ctx.db
      .query("mediaItems")
      .withIndex("by_tripId", (q) => q.eq("tripId", args.tripId))
      .collect();

    return mediaItems;
  },
});
