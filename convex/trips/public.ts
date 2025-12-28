import { query } from "../_generated/server";
import { v } from "convex/values";

// ============= PUBLIC QUERIES =============

// Get public preview of a trip (for web preview page)
export const getPublicPreview = query({
  args: {
    shareSlug: v.optional(v.string()),
    shareCode: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    if (!args.shareSlug && !args.shareCode) {
      throw new Error("Either shareSlug or shareCode must be provided");
    }

    // Find trip by slug or code
    let trip;
    if (args.shareSlug) {
      trip = await ctx.db
        .query("trips")
        .withIndex("by_shareSlug", (q) => q.eq("shareSlug", args.shareSlug))
        .first();
    } else if (args.shareCode) {
      trip = await ctx.db
        .query("trips")
        .withIndex("by_shareCode", (q) => q.eq("shareCode", args.shareCode?.toUpperCase()))
        .first();
    }

    if (!trip) {
      return null;
    }

    // Check if sharing is enabled
    if (!trip.shareLinkEnabled) {
      return null;
    }

    // Get ALL moments for this trip to render the full canvas
    const moments = await ctx.db
      .query("moments")
      .withIndex("by_tripId", (q) => q.eq("tripId", trip.tripId))
      .collect();

    // Get media items for the moments
    const momentMediaItems = await Promise.all(
      moments.map(async (moment) => {
        const mediaItems = await ctx.db
          .query("mediaItems")
          .withIndex("by_tripId", (q) => q.eq("tripId", trip.tripId))
          .collect();

        // Filter to only media in this moment
        return mediaItems.filter((item) =>
          moment.mediaItemIDs.includes(item.mediaItemId)
        );
      })
    );

    // Get image URLs for each moment (up to 4 for collage)
    const momentsWithUrls = await Promise.all(
      moments.map(async (moment, index) => {
        const mediaItems = momentMediaItems[index] || [];
        const media: Array<{ url: string | null; type: "photo" | "video" }> = [];

        // Get URLs for first 4 media items (for collage display)
        for (const mediaItem of mediaItems.slice(0, 4)) {
          if (mediaItem.storageId) {
            try {
              const url = await ctx.storage.getUrl(mediaItem.storageId);
              media.push({ url, type: mediaItem.type });
            } catch (error) {
              console.error(`Failed to get URL for storage ID ${mediaItem.storageId}:`, error);
              media.push({ url: null, type: mediaItem.type });
            }
          }
        }

        return {
          momentId: moment.momentId,
          title: moment.title,
          gridPosition: moment.gridPosition,
          mediaCount: mediaItems.length,
          media,
        };
      })
    );

    // Get cover image URL
    let coverImageUrl: string | null = null;
    if (trip.coverImageStorageId) {
      try {
        coverImageUrl = await ctx.storage.getUrl(trip.coverImageStorageId);
      } catch (error) {
        console.error(`Failed to get cover image URL:`, error);
      }
    }

    // Get collaborators/permissions for this trip
    const permissions = await ctx.db
      .query("tripPermissions")
      .withIndex("by_tripId", (q) => q.eq("tripId", trip.tripId))
      .collect();

    // Get user info for each permission (SECURITY: Only expose non-sensitive data)
    const collaborators = await Promise.all(
      permissions.map(async (permission) => {
        const user = await ctx.db
          .query("users")
          .withIndex("by_clerkId", (q) => q.eq("clerkId", permission.userId))
          .first();

        // ✅ SECURITY FIX: Never expose userId or email to public endpoints
        return {
          role: permission.role,
          name: user?.name || null,
          imageUrl: user?.imageUrl || null,
          // ❌ REMOVED: userId, email - GDPR/Privacy violation
        };
      })
    );

    return {
      trip: {
        tripId: trip.tripId,
        title: trip.title,
        startDate: trip.startDate,
        endDate: trip.endDate,
        shareSlug: trip.shareSlug,
        shareCode: trip.shareCode,
        coverImageUrl,
      },
      moments: momentsWithUrls,
      totalMoments: moments.length,
      collaborators,
    };
  },
});
