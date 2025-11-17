import { mutation } from "./_generated/server";

// Migration: Set ownerId for existing trips and create owner permissions
export const migrateExistingTrips = mutation({
  args: {},
  handler: async (ctx) => {
    const trips = await ctx.db.query("trips").collect();

    let migratedCount = 0;
    let permissionsCreated = 0;

    for (const trip of trips) {
      // Set ownerId if missing
      if (!trip.ownerId && trip.userId) {
        await ctx.db.patch(trip._id, {
          ownerId: trip.userId,
        });
        migratedCount++;
      }

      // Create owner permission if it doesn't exist
      if (trip.tripId && (trip.ownerId || trip.userId)) {
        const existingPermission = await ctx.db
          .query("tripPermissions")
          .withIndex("by_tripId_userId", (q) =>
            q.eq("tripId", trip.tripId).eq("userId", trip.ownerId || trip.userId)
          )
          .first();

        if (!existingPermission) {
          await ctx.db.insert("tripPermissions", {
            tripId: trip.tripId,
            userId: trip.ownerId || trip.userId,
            role: "owner",
            grantedVia: "share_link",
            invitedBy: trip.ownerId || trip.userId,
            acceptedAt: trip.createdAt,
            createdAt: Date.now(),
          });
          permissionsCreated++;
        }
      }
    }

    return {
      success: true,
      migratedTrips: migratedCount,
      permissionsCreated: permissionsCreated,
      totalTrips: trips.length,
    };
  },
});
