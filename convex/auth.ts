import { Auth } from "convex/server";
import { QueryCtx, MutationCtx } from "./_generated/server";
import { mutation, query } from "./_generated/server";

// Helper to get authenticated user ID from Clerk
export async function getAuthUserId(
  ctx: QueryCtx | MutationCtx
): Promise<string | null> {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) {
    return null;
  }

  // Clerk provides the user ID in the subject field
  return identity.subject;
}

// Helper to require authentication
export async function requireAuth(
  ctx: QueryCtx | MutationCtx
): Promise<string> {
  const userId = await getAuthUserId(ctx);
  if (!userId) {
    throw new Error("Unauthorized: Must be logged in");
  }
  return userId;
}

// Helper to get or create user in database
export async function getOrCreateUser(ctx: MutationCtx) {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) {
    throw new Error("Unauthorized");
  }

  const clerkId = identity.subject;

  // Check if user exists
  const existingUser = await ctx.db
    .query("users")
    .withIndex("by_clerkId", (q) => q.eq("clerkId", clerkId))
    .first();

  if (existingUser) {
    return existingUser._id;
  }

  // Create new user
  const userId = await ctx.db.insert("users", {
    clerkId,
    email: identity.email,
    name: identity.name,
    imageUrl: identity.pictureUrl,
    createdAt: Date.now(),
  });

  return userId;
}

// Mutation to sync user from Clerk to Convex database
// Call this after user signs in to ensure they exist in the database
export const syncUser = mutation({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Unauthorized");
    }

    const clerkId = identity.subject;

    // Check if user exists
    const existingUser = await ctx.db
      .query("users")
      .withIndex("by_clerkId", (q) => q.eq("clerkId", clerkId))
      .first();

    if (existingUser) {
      // Update existing user with latest Clerk data
      await ctx.db.patch(existingUser._id, {
        email: identity.email,
        name: identity.name,
        imageUrl: identity.pictureUrl,
      });

      // Return updated user
      const user = await ctx.db.get(existingUser._id);
      return user;
    }

    // Create new user if doesn't exist
    const userId = await ctx.db.insert("users", {
      clerkId,
      email: identity.email,
      name: identity.name,
      imageUrl: identity.pictureUrl,
      createdAt: Date.now(),
    });

    // Return the user document
    const user = await ctx.db.get(userId);
    return user;
  },
});

// Query to get current user info
export const getCurrentUser = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      return null;
    }

    const user = await ctx.db
      .query("users")
      .withIndex("by_clerkId", (q) => q.eq("clerkId", identity.subject))
      .first();

    return user;
  },
});

// Mutation to delete user account and all associated data
export const deleteAccount = mutation({
  args: {},
  handler: async (ctx) => {
    const userId = await requireAuth(ctx);

    // 1. Get all trips owned by this user
    const ownedTrips = await ctx.db
      .query("trips")
      .withIndex("by_ownerId", (q) => q.eq("ownerId", userId))
      .collect();

    // 2. Delete all owned trips and their data
    for (const trip of ownedTrips) {
      // Delete moments for this trip
      const moments = await ctx.db
        .query("moments")
        .withIndex("by_tripId", (q) => q.eq("tripId", trip.tripId))
        .collect();

      for (const moment of moments) {
        await ctx.db.delete(moment._id);
      }

      // Delete media items for this trip
      const mediaItems = await ctx.db
        .query("mediaItems")
        .withIndex("by_tripId", (q) => q.eq("tripId", trip.tripId))
        .collect();

      for (const mediaItem of mediaItems) {
        // Delete from storage if exists
        if (mediaItem.storageId) {
          try {
            await ctx.storage.delete(mediaItem.storageId);
          } catch (error) {
            console.error(`Failed to delete storage file ${mediaItem.storageId}:`, error);
          }
        }
        if (mediaItem.thumbnailStorageId) {
          try {
            await ctx.storage.delete(mediaItem.thumbnailStorageId);
          } catch (error) {
            console.error(`Failed to delete thumbnail ${mediaItem.thumbnailStorageId}:`, error);
          }
        }
        await ctx.db.delete(mediaItem._id);
      }

      // Delete permissions for this trip
      const permissions = await ctx.db
        .query("tripPermissions")
        .withIndex("by_tripId", (q) => q.eq("tripId", trip.tripId))
        .collect();

      for (const permission of permissions) {
        await ctx.db.delete(permission._id);
      }

      // Delete the trip itself
      await ctx.db.delete(trip._id);
    }

    // 3. Delete all permissions where user is a member (not owner)
    const userPermissions = await ctx.db
      .query("tripPermissions")
      .withIndex("by_userId", (q) => q.eq("userId", userId))
      .collect();

    for (const permission of userPermissions) {
      await ctx.db.delete(permission._id);
    }

    // 4. Delete user record
    const user = await ctx.db
      .query("users")
      .withIndex("by_clerkId", (q) => q.eq("clerkId", userId))
      .first();

    if (user) {
      await ctx.db.delete(user._id);
    }

    return { success: true };
  },
});
