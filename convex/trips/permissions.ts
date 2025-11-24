import { QueryCtx, MutationCtx } from "../_generated/server";

// ============= PERMISSION HELPERS =============

// Check if user can view a trip (has any access)
export async function canUserView(
  ctx: QueryCtx | MutationCtx,
  tripId: string,
  userId: string
): Promise<boolean> {
  const trip = await ctx.db
    .query("trips")
    .withIndex("by_tripId", (q) => q.eq("tripId", tripId))
    .first();

  // Owner can always view
  if (trip?.ownerId === userId || trip?.userId === userId) return true;

  // Check if user has permission
  const permission = await ctx.db
    .query("tripPermissions")
    .withIndex("by_tripId_userId", (q) =>
      q.eq("tripId", tripId).eq("userId", userId)
    )
    .first();

  return permission !== null;
}

// Check if user can edit a trip (owner or collaborator)
export async function canUserEdit(
  ctx: QueryCtx | MutationCtx,
  tripId: string,
  userId: string
): Promise<boolean> {
  const trip = await ctx.db
    .query("trips")
    .withIndex("by_tripId", (q) => q.eq("tripId", tripId))
    .first();

  // Owner can always edit
  if (trip?.ownerId === userId || trip?.userId === userId) return true;

  // Check if user is a collaborator
  const permission = await ctx.db
    .query("tripPermissions")
    .withIndex("by_tripId_userId", (q) =>
      q.eq("tripId", tripId).eq("userId", userId)
    )
    .first();

  return permission?.role === "collaborator";
}

// Check if user is the owner of a trip
export async function isOwner(
  ctx: QueryCtx | MutationCtx,
  tripId: string,
  userId: string
): Promise<boolean> {
  const trip = await ctx.db
    .query("trips")
    .withIndex("by_tripId", (q) => q.eq("tripId", tripId))
    .first();

  return trip?.ownerId === userId || trip?.userId === userId;
}
