import { ConvexHttpClient } from "convex/browser";

const convexUrl = process.env.NEXT_PUBLIC_CONVEX_URL || "https://flippant-mongoose-94.convex.cloud";

export const convex = new ConvexHttpClient(convexUrl);
