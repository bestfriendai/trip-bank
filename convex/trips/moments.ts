import { mutation, query } from "../_generated/server";
import { v } from "convex/values";
import { requireAuth } from "../auth";
import { canUserEdit } from "./permissions";

// ============= MOMENT MUTATIONS =============

// Add a moment to a trip
export const addMoment = mutation({
  args: {
    momentId: v.string(),
    tripId: v.string(),
    title: v.string(),
    note: v.optional(v.string()),
    mediaItemIDs: v.array(v.string()),
    timestamp: v.number(),
    date: v.optional(v.number()),
    placeName: v.optional(v.string()),
    voiceNoteURL: v.optional(v.string()),
    gridPosition: v.object({
      column: v.number(),
      row: v.number(),
      width: v.number(),
      height: v.number(),
    }),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);

    // Check permission to edit trip
    if (!(await canUserEdit(ctx, args.tripId, userId))) {
      throw new Error("You don't have permission to add moments to this trip");
    }

    const now = Date.now();

    const momentDocId = await ctx.db.insert("moments", {
      userId,
      momentId: args.momentId,
      tripId: args.tripId,
      title: args.title,
      note: args.note,
      mediaItemIDs: args.mediaItemIDs,
      timestamp: args.timestamp,
      date: args.date,
      placeName: args.placeName,
      voiceNoteURL: args.voiceNoteURL,
      gridPosition: args.gridPosition,
      createdAt: now,
      updatedAt: now,
    });

    return momentDocId;
  },
});

// Update a moment
export const updateMoment = mutation({
  args: {
    momentId: v.string(),
    title: v.optional(v.string()),
    note: v.optional(v.string()),
    mediaItemIDs: v.optional(v.array(v.string())),
    date: v.optional(v.number()),
    placeName: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);

    // Find the moment
    const moment = await ctx.db
      .query("moments")
      .withIndex("by_momentId", (q) => q.eq("momentId", args.momentId))
      .first();

    if (!moment) {
      throw new Error(`Moment not found: ${args.momentId}`);
    }

    // Check permission to edit trip
    if (!(await canUserEdit(ctx, moment.tripId, userId))) {
      throw new Error("You don't have permission to edit moments in this trip");
    }

    const updates: any = {
      updatedAt: Date.now(),
    };

    if (args.title !== undefined) updates.title = args.title;
    if (args.note !== undefined) updates.note = args.note;
    if (args.mediaItemIDs !== undefined) updates.mediaItemIDs = args.mediaItemIDs;
    if (args.date !== undefined) updates.date = args.date;
    if (args.placeName !== undefined) updates.placeName = args.placeName;

    await ctx.db.patch(moment._id, updates);
    return { success: true };
  },
});

// Delete a moment
export const deleteMoment = mutation({
  args: {
    momentId: v.string(),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);

    // Find the moment
    const moment = await ctx.db
      .query("moments")
      .withIndex("by_momentId", (q) => q.eq("momentId", args.momentId))
      .first();

    if (!moment) {
      throw new Error(`Moment not found: ${args.momentId}`);
    }

    // Check permission to edit trip
    if (!(await canUserEdit(ctx, moment.tripId, userId))) {
      throw new Error("You don't have permission to delete moments from this trip");
    }

    // Delete the moment
    await ctx.db.delete(moment._id);

    return { success: true };
  },
});

// Update moment grid position (for drag/resize operations)
export const updateMomentGridPosition = mutation({
  args: {
    momentId: v.string(),
    gridPosition: v.object({
      column: v.number(),
      row: v.number(),
      width: v.number(),
      height: v.number(),
    }),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);

    // Find the moment
    const moment = await ctx.db
      .query("moments")
      .withIndex("by_momentId", (q) => q.eq("momentId", args.momentId))
      .first();

    if (!moment) {
      throw new Error(`Moment not found: ${args.momentId}`);
    }

    // Check permission to edit trip
    if (!(await canUserEdit(ctx, moment.tripId, userId))) {
      throw new Error("You don't have permission to edit moments in this trip");
    }

    await ctx.db.patch(moment._id, {
      gridPosition: args.gridPosition,
      updatedAt: Date.now(),
    });

    return { success: true };
  },
});

// Batch update moment grid positions (for reflow operations)
// ✅ OPTIMIZED: Fixed N+1 query problem - now checks permission once
export const batchUpdateMomentGridPositions = mutation({
  args: {
    updates: v.array(
      v.object({
        momentId: v.string(),
        gridPosition: v.object({
          column: v.number(),
          row: v.number(),
          width: v.number(),
          height: v.number(),
        }),
      })
    ),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);
    const now = Date.now();

    if (args.updates.length === 0) {
      return { success: true };
    }

    // ✅ Fetch all moments in parallel (not sequentially)
    const moments = await Promise.all(
      args.updates.map((update) =>
        ctx.db
          .query("moments")
          .withIndex("by_momentId", (q) => q.eq("momentId", update.momentId))
          .first()
      )
    );

    // ✅ Validate all moments exist
    const validMoments = moments.filter((m): m is NonNullable<typeof m> => m !== null);
    if (validMoments.length !== args.updates.length) {
      const missingIds = args.updates
        .filter((_, i) => !moments[i])
        .map((u) => u.momentId);
      throw new Error(`Moments not found: ${missingIds.join(", ")}`);
    }

    // ✅ Verify all moments belong to the same trip (for permission check)
    const tripIds = [...new Set(validMoments.map((m) => m.tripId))];
    if (tripIds.length !== 1) {
      throw new Error("All moments must belong to the same trip");
    }

    // ✅ Check permission ONCE (not N times)
    const tripId = tripIds[0];
    if (!(await canUserEdit(ctx, tripId, userId))) {
      throw new Error("You don't have permission to edit moments in this trip");
    }

    // ✅ Batch update all moments in parallel
    await Promise.all(
      args.updates.map((update, index) =>
        ctx.db.patch(validMoments[index]._id, {
          gridPosition: update.gridPosition,
          updatedAt: now,
        })
      )
    );

    return { success: true };
  },
});

// ============= MOMENT QUERIES =============

// Get all moments for a trip
export const getMoments = query({
  args: {
    tripId: v.string(),
  },
  handler: async (ctx, args) => {
    const moments = await ctx.db
      .query("moments")
      .withIndex("by_tripId", (q) => q.eq("tripId", args.tripId))
      .collect();

    return moments;
  },
});
