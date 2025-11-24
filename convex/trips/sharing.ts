import { mutation, query } from "../_generated/server";
import { v } from "convex/values";
import { requireAuth } from "../auth";
import { canUserView, isOwner, canUserEdit } from "./permissions";

// ============= HELPER FUNCTIONS =============

// Helper function to generate a URL-safe slug
function generateSlug(title: string): string {
  // Convert title to lowercase, remove special chars, replace spaces with dashes
  const baseSlug = title
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .substring(0, 20); // Limit length

  // Add random suffix for uniqueness
  const randomSuffix = Math.random().toString(36).substring(2, 6);
  return `${baseSlug}-${randomSuffix}`;
}

// Helper function to generate a human-readable share code
function generateShareCode(title: string): string {
  // Take first word of title (up to 6 chars) + 2 random digits
  const firstWord = title.split(' ')[0].toUpperCase().substring(0, 6);
  const randomDigits = Math.floor(10 + Math.random() * 90); // 2 digits (10-99)
  return `${firstWord}${randomDigits}`;
}

// ============= SHARING MUTATIONS =============

// Generate share link for a trip (enables sharing)
export const generateShareLink = mutation({
  args: {
    tripId: v.string(),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);

    // Check if user is owner (only owner can enable sharing)
    if (!(await isOwner(ctx, args.tripId, userId))) {
      throw new Error("Only the trip owner can generate share links");
    }

    // Get the trip
    const trip = await ctx.db
      .query("trips")
      .withIndex("by_tripId", (q) => q.eq("tripId", args.tripId))
      .first();

    if (!trip) {
      throw new Error("Trip not found");
    }

    // If trip already has a share link, return existing
    if (trip.shareSlug && trip.shareCode) {
      return {
        shareSlug: trip.shareSlug,
        shareCode: trip.shareCode,
        url: `https://rewinded.app/trip/${trip.shareSlug}`,
      };
    }

    // Generate unique slug and code
    let shareSlug = generateSlug(trip.title);
    let shareCode = generateShareCode(trip.title);

    // Ensure slug is unique
    let existingSlug = await ctx.db
      .query("trips")
      .withIndex("by_shareSlug", (q) => q.eq("shareSlug", shareSlug))
      .first();

    while (existingSlug) {
      shareSlug = generateSlug(trip.title);
      existingSlug = await ctx.db
        .query("trips")
        .withIndex("by_shareSlug", (q) => q.eq("shareSlug", shareSlug))
        .first();
    }

    // Ensure code is unique
    let existingCode = await ctx.db
      .query("trips")
      .withIndex("by_shareCode", (q) => q.eq("shareCode", shareCode))
      .first();

    while (existingCode) {
      shareCode = generateShareCode(trip.title);
      existingCode = await ctx.db
        .query("trips")
        .withIndex("by_shareCode", (q) => q.eq("shareCode", shareCode))
        .first();
    }

    // Update trip with share link and enable sharing
    await ctx.db.patch(trip._id, {
      shareSlug,
      shareCode,
      shareLinkEnabled: true,
      updatedAt: Date.now(),
    });

    return {
      shareSlug,
      shareCode,
      url: `https://rewinded.app/trip/${shareSlug}`,
    };
  },
});

// Disable share link for a trip
export const disableShareLink = mutation({
  args: {
    tripId: v.string(),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);

    // Check if user is owner
    if (!(await isOwner(ctx, args.tripId, userId))) {
      throw new Error("Only the trip owner can disable share links");
    }

    // Get the trip
    const trip = await ctx.db
      .query("trips")
      .withIndex("by_tripId", (q) => q.eq("tripId", args.tripId))
      .first();

    if (!trip) {
      throw new Error("Trip not found");
    }

    // Disable sharing (keep slug/code for re-enabling)
    await ctx.db.patch(trip._id, {
      shareLinkEnabled: false,
      updatedAt: Date.now(),
    });

    return { success: true };
  },
});

// Join a trip via share link or code
export const joinTripViaLink = mutation({
  args: {
    // Either shareSlug or shareCode must be provided
    shareSlug: v.optional(v.string()),
    shareCode: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);

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
      throw new Error("Trip not found. Please check the link or code.");
    }

    // Check if sharing is enabled
    if (!trip.shareLinkEnabled) {
      throw new Error("This trip is no longer accepting new members");
    }

    // Check if user already has access
    const existingPermission = await ctx.db
      .query("tripPermissions")
      .withIndex("by_tripId_userId", (q) =>
        q.eq("tripId", trip.tripId).eq("userId", userId)
      )
      .first();

    if (existingPermission) {
      // User already has access, just return trip info
      return {
        tripId: trip.tripId,
        alreadyMember: true,
      };
    }

    // Create viewer permission for the user
    const now = Date.now();
    await ctx.db.insert("tripPermissions", {
      tripId: trip.tripId,
      userId,
      role: "viewer",
      grantedVia: "share_link",
      invitedBy: trip.ownerId || trip.userId,
      acceptedAt: now,
      createdAt: now,
    });

    return {
      tripId: trip.tripId,
      alreadyMember: false,
    };
  },
});

// Update a user's permission on a trip
export const updatePermission = mutation({
  args: {
    tripId: v.string(),
    userId: v.string(), // User whose permission to update
    newRole: v.union(v.literal("collaborator"), v.literal("viewer")),
  },
  handler: async (ctx, args) => {
    const currentUserId = await requireAuth(ctx);

    // Check if current user can manage permissions (owner or collaborator)
    const trip = await ctx.db
      .query("trips")
      .withIndex("by_tripId", (q) => q.eq("tripId", args.tripId))
      .first();

    if (!trip) {
      throw new Error("Trip not found");
    }

    // Only owner and collaborators can upgrade viewers
    const hasPermission = await isOwner(ctx, args.tripId, currentUserId) ||
                         await canUserEdit(ctx, args.tripId, currentUserId);

    if (!hasPermission) {
      throw new Error("You don't have permission to manage access for this trip");
    }

    // Can't change owner's role
    if (trip.ownerId === args.userId || trip.userId === args.userId) {
      throw new Error("Cannot change the owner's role");
    }

    // Find the permission to update
    const permission = await ctx.db
      .query("tripPermissions")
      .withIndex("by_tripId_userId", (q) =>
        q.eq("tripId", args.tripId).eq("userId", args.userId)
      )
      .first();

    if (!permission) {
      throw new Error("User does not have access to this trip");
    }

    // Update the permission
    await ctx.db.patch(permission._id, {
      role: args.newRole,
    });

    return { success: true };
  },
});

// Remove a user's access to a trip
export const removeAccess = mutation({
  args: {
    tripId: v.string(),
    userId: v.string(), // User to remove
  },
  handler: async (ctx, args) => {
    const currentUserId = await requireAuth(ctx);

    // Check if current user is the owner
    if (!(await isOwner(ctx, args.tripId, currentUserId))) {
      throw new Error("Only the trip owner can remove access");
    }

    const trip = await ctx.db
      .query("trips")
      .withIndex("by_tripId", (q) => q.eq("tripId", args.tripId))
      .first();

    if (!trip) {
      throw new Error("Trip not found");
    }

    // Can't remove owner
    if (trip.ownerId === args.userId || trip.userId === args.userId) {
      throw new Error("Cannot remove the owner from the trip");
    }

    // Find and delete the permission
    const permission = await ctx.db
      .query("tripPermissions")
      .withIndex("by_tripId_userId", (q) =>
        q.eq("tripId", args.tripId).eq("userId", args.userId)
      )
      .first();

    if (!permission) {
      throw new Error("User does not have access to this trip");
    }

    await ctx.db.delete(permission._id);

    return { success: true };
  },
});

// ============= SHARING QUERIES =============

// Get trips shared with the current user (where they're not the owner)
export const getSharedTrips = query({
  args: {},
  handler: async (ctx) => {
    const userId = await requireAuth(ctx);

    // Get all permissions for this user
    const permissions = await ctx.db
      .query("tripPermissions")
      .withIndex("by_userId", (q) => q.eq("userId", userId))
      .collect();

    // Get the trips for these permissions
    const trips = await Promise.all(
      permissions.map(async (permission) => {
        const trip = await ctx.db
          .query("trips")
          .withIndex("by_tripId", (q) => q.eq("tripId", permission.tripId))
          .first();

        if (!trip) return null;

        // Only return trips where user is NOT the owner
        if (trip.ownerId === userId || trip.userId === userId) {
          return null;
        }

        return {
          ...trip,
          userRole: permission.role,
          joinedAt: permission.acceptedAt,
        };
      })
    );

    // Filter out nulls and return
    return trips.filter((trip) => trip !== null);
  },
});

// Get all permissions for a trip (with user info)
export const getTripPermissions = query({
  args: {
    tripId: v.string(),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);

    // Check if user has access to view permissions
    if (!(await canUserView(ctx, args.tripId, userId))) {
      throw new Error("You don't have access to this trip");
    }

    // Get all permissions for this trip
    const permissions = await ctx.db
      .query("tripPermissions")
      .withIndex("by_tripId", (q) => q.eq("tripId", args.tripId))
      .collect();

    // Get user info for each permission
    const permissionsWithUserInfo = await Promise.all(
      permissions.map(async (permission) => {
        const user = await ctx.db
          .query("users")
          .withIndex("by_clerkId", (q) => q.eq("clerkId", permission.userId))
          .first();

        return {
          id: permission._id,
          userId: permission.userId,
          role: permission.role,
          grantedVia: permission.grantedVia,
          invitedBy: permission.invitedBy,
          acceptedAt: permission.acceptedAt,
          user: user ? {
            name: user.name || null,
            email: user.email || null,
            imageUrl: user.imageUrl || null,
          } : null,
        };
      })
    );

    return permissionsWithUserInfo;
  },
});
