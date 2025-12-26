# Codebase Improvement Blueprint

> **Generated:** December 2025
> **Platform Detected:** Multi-platform (iOS Native SwiftUI + Next.js Web + Convex Backend)
> **App Category:** Social/Travel Memory Sharing
> **App Name:** Rewinded (formerly TripBank)
> **Health Score:** 72/100

---

## Executive Summary

**Rewinded** is a well-architected multi-platform travel memory sharing application consisting of:
- **iOS Native App** (Swift/SwiftUI) - Primary client
- **Next.js Web App** (React 19, TypeScript) - Shared trip viewing & marketing
- **Convex Backend** - Real-time database, serverless functions, file storage

The codebase demonstrates solid fundamentals with real-time subscriptions, proper authentication via Clerk, and a permission-based sharing system. However, there are several areas requiring attention before production deployment, particularly around **security hardening**, **error handling**, **testing infrastructure**, and **CI/CD pipeline**.

### Key Strengths
- Clean separation of concerns between client and backend
- Real-time data synchronization using Convex subscriptions
- Proper authentication flow with Clerk integration
- Well-structured permission system (owner/collaborator/viewer)
- Storage quota management with subscription tiers

### Critical Areas for Improvement
1. **Security vulnerabilities** in file access and API endpoints
2. **Missing CI/CD pipeline** and automated testing
3. **Error handling inconsistencies** across the codebase
4. **Hardcoded API keys** in source code
5. **Missing input validation** in several mutations

---

## Critical Issues (P0 - Fix Before Deploy)

### 1. Hardcoded API Keys in Source Code

**Location:** `trip-bank/TripBankApp.swift:17-21`, `trip-bank/TripBankApp.swift:32-36`

**Severity:** CRITICAL

**Issue:** RevenueCat and Clerk API keys are hardcoded directly in the source code.

```swift
// CURRENT - trip-bank/TripBankApp.swift:17-21
#if DEBUG
Purchases.configure(withAPIKey: "test_KPzYsqSoDJNXtANifSJSBXjJwoA")
#else
Purchases.configure(withAPIKey: "appl_hRZHpYyZEwGkIoBpcPfJQCkTXdx")
#endif

// CURRENT - trip-bank/TripBankApp.swift:32-36
#if DEBUG
clerk.configure(publishableKey: "pk_test_bWFnaWNhbC1sYWJyYWRvci0xNy5jbGVyay5hY2NvdW50cy5kZXYk")
#else
clerk.configure(publishableKey: "pk_live_Y2xlcmsucmV3aW5kZWQuYXBwJA")
#endif
```

**Risk:** While Clerk publishable keys are designed to be public, RevenueCat API keys should be protected. More importantly, this pattern makes key rotation difficult and violates security best practices.

**Recommendation:** Use Xcode configuration files or a secure secrets management approach.

```swift
// RECOMMENDED - Config.swift (gitignored)
enum Config {
    static let revenueCatAPIKey: String = {
        #if DEBUG
        return Bundle.main.infoDictionary?["REVENUECAT_API_KEY_DEBUG"] as? String ?? ""
        #else
        return Bundle.main.infoDictionary?["REVENUECAT_API_KEY_PROD"] as? String ?? ""
        #endif
    }()

    static let clerkPublishableKey: String = {
        #if DEBUG
        return Bundle.main.infoDictionary?["CLERK_PUBLISHABLE_KEY_DEBUG"] as? String ?? ""
        #else
        return Bundle.main.infoDictionary?["CLERK_PUBLISHABLE_KEY_PROD"] as? String ?? ""
        #endif
    }()
}

// Usage in TripBankApp.swift
Purchases.configure(withAPIKey: Config.revenueCatAPIKey)
clerk.configure(publishableKey: Config.clerkPublishableKey)
```

**References:**
- [Apple - Managing Secrets in Xcode](https://developer.apple.com/documentation/xcode/adding-a-build-configuration-file-to-your-project)
- [RevenueCat - Security Best Practices](https://docs.revenuecat.com/docs/security)

---

### 2. Insecure File Access - Missing Ownership Verification

**Location:** `convex/files.ts:15-24`, `convex/files.ts:27-40`

**Severity:** CRITICAL

**Issue:** The `getFileUrl` query and `deleteFile` mutation lack ownership verification, allowing any authenticated user to access or delete any file.

```typescript
// CURRENT - convex/files.ts:15-24
export const getFileUrl = query({
  args: {
    storageId: v.id("_storage"),
  },
  handler: async (ctx, args) => {
    // Files are public once you have the storage ID
    // In a production app, you might want to verify ownership first
    return await ctx.storage.getUrl(args.storageId);
  },
});

// CURRENT - convex/files.ts:27-40
export const deleteFile = mutation({
  args: {
    storageId: v.id("_storage"),
  },
  handler: async (ctx, args) => {
    await requireAuth(ctx);
    // In production, verify the user owns this file
    // by checking mediaItems or trips table
    await ctx.storage.delete(args.storageId);
    return { success: true };
  },
});
```

**Risk:** Any authenticated user can access or delete any user's files if they know/guess the storage ID. This is an Insecure Direct Object Reference (IDOR) vulnerability.

**Recommendation:**

```typescript
// RECOMMENDED - convex/files.ts
import { requireAuth } from "./auth";

export const getFileUrl = query({
  args: {
    storageId: v.id("_storage"),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);

    // Verify the user has access to this file
    const mediaItem = await ctx.db
      .query("mediaItems")
      .filter((q) => q.eq(q.field("storageId"), args.storageId))
      .first();

    if (!mediaItem) {
      // Check if it's a trip cover image
      const trip = await ctx.db
        .query("trips")
        .filter((q) => q.eq(q.field("coverImageStorageId"), args.storageId))
        .first();

      if (!trip) {
        throw new Error("File not found");
      }

      // Verify user has access to the trip
      const hasAccess = await canUserView(ctx, trip.tripId, userId);
      if (!hasAccess) {
        throw new Error("Access denied");
      }
    } else {
      // Verify user has access to the trip containing this media
      const hasAccess = await canUserView(ctx, mediaItem.tripId, userId);
      if (!hasAccess) {
        throw new Error("Access denied");
      }
    }

    return await ctx.storage.getUrl(args.storageId);
  },
});

export const deleteFile = mutation({
  args: {
    storageId: v.id("_storage"),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);

    // Find the media item that owns this file
    const mediaItem = await ctx.db
      .query("mediaItems")
      .filter((q) => q.eq(q.field("storageId"), args.storageId))
      .first();

    if (!mediaItem) {
      throw new Error("File not found");
    }

    // Verify user can edit the trip (owner or collaborator)
    const canEdit = await canUserEdit(ctx, mediaItem.tripId, userId);
    if (!canEdit) {
      throw new Error("You don't have permission to delete this file");
    }

    await ctx.storage.delete(args.storageId);
    return { success: true };
  },
});
```

**References:**
- [OWASP - Insecure Direct Object References](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/05-Authorization_Testing/04-Testing_for_Insecure_Direct_Object_References)

---

### 3. Storage Usage Manipulation Vulnerability

**Location:** `convex/storage.ts:84-107`, `convex/storage.ts:109-135`

**Severity:** HIGH

**Issue:** The `addStorageUsage` and `subtractStorageUsage` mutations can be called directly by clients with arbitrary byte values, allowing users to manipulate their storage quota.

```typescript
// CURRENT - convex/storage.ts:84-107
export const addStorageUsage = mutation({
  args: {
    bytes: v.number(),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);
    // ... adds arbitrary bytes to user's storage
  },
});
```

**Risk:** A malicious user could call `subtractStorageUsage` with a large value to bypass storage limits, or manipulate their quota tracking.

**Recommendation:** These mutations should be internal only and called from other mutations that actually perform file operations:

```typescript
// RECOMMENDED - convex/storage.ts

// Internal helper - not exposed as a mutation
export async function updateStorageUsage(
  ctx: MutationCtx,
  userId: string,
  byteDelta: number
) {
  const user = await ctx.db
    .query("users")
    .withIndex("by_clerkId", (q) => q.eq("clerkId", userId))
    .first();

  if (!user) {
    throw new Error("User not found");
  }

  const currentUsage = user.storageUsedBytes || 0;
  const newUsage = Math.max(0, currentUsage + byteDelta);

  await ctx.db.patch(user._id, {
    storageUsedBytes: newUsage,
  });

  return newUsage;
}

// Remove the public addStorageUsage and subtractStorageUsage mutations
// Instead, update storage usage within the media upload/delete mutations
```

---

### 4. Missing Rate Limiting on Authentication Endpoints

**Location:** `convex/auth.ts`, `trip-bank/Services/ConvexClient.swift`

**Severity:** HIGH

**Issue:** No rate limiting is implemented on authentication or mutation endpoints, making the system vulnerable to brute force attacks and abuse.

**Recommendation:** Implement rate limiting at the Convex level or use Clerk's built-in rate limiting:

```typescript
// RECOMMENDED - convex/rateLimit.ts
import { v } from "convex/values";

// Simple in-memory rate limit tracking (for Convex)
const rateLimits = new Map<string, { count: number; resetAt: number }>();

export function checkRateLimit(
  identifier: string,
  maxRequests: number = 100,
  windowMs: number = 60000
): boolean {
  const now = Date.now();
  const limit = rateLimits.get(identifier);

  if (!limit || now > limit.resetAt) {
    rateLimits.set(identifier, { count: 1, resetAt: now + windowMs });
    return true;
  }

  if (limit.count >= maxRequests) {
    return false;
  }

  limit.count++;
  return true;
}

// Usage in mutations
export const joinTripViaLink = mutation({
  args: { ... },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);

    if (!checkRateLimit(`join-trip:${userId}`, 10, 60000)) {
      throw new Error("Too many requests. Please try again later.");
    }

    // ... rest of handler
  },
});
```

---

### 5. Subscription Tier Bypass Vulnerability

**Location:** `convex/storage.ts:178-204`

**Severity:** HIGH

**Issue:** The `updateSubscription` mutation allows any authenticated user to set their own subscription tier without verification from RevenueCat.

```typescript
// CURRENT - convex/storage.ts:178-204
export const updateSubscription = mutation({
  args: {
    tier: v.union(v.literal("free"), v.literal("pro")),
    expiresAt: v.optional(v.number()),
    revenueCatUserId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);
    // ... directly updates subscription without verification
  },
});
```

**Risk:** A user could call this mutation directly with `tier: "pro"` to bypass payment.

**Recommendation:** Implement server-side verification with RevenueCat webhooks or use Convex HTTP actions to verify purchases:

```typescript
// RECOMMENDED - Use RevenueCat webhooks
// 1. Set up a Convex HTTP action to receive RevenueCat webhooks
// 2. Verify the webhook signature
// 3. Only update subscription based on verified webhook data

import { httpAction } from "./_generated/server";

export const revenueCatWebhook = httpAction(async (ctx, request) => {
  // Verify webhook signature
  const signature = request.headers.get("X-RevenueCat-Signature");
  const body = await request.text();

  if (!verifyRevenueCatSignature(body, signature)) {
    return new Response("Invalid signature", { status: 401 });
  }

  const event = JSON.parse(body);

  // Process subscription events
  if (event.event.type === "INITIAL_PURCHASE" ||
      event.event.type === "RENEWAL") {
    await ctx.runMutation(internal.storage.internalUpdateSubscription, {
      revenueCatUserId: event.event.app_user_id,
      tier: "pro",
      expiresAt: new Date(event.event.expiration_at_ms).getTime(),
    });
  }

  return new Response("OK", { status: 200 });
});
```

---

## High Priority Issues (P1 - Fix This Sprint)

### 6. Missing Input Validation and Sanitization

**Location:** Multiple files including `convex/trips/trips.ts`, `convex/trips/moments.ts`

**Issue:** Trip titles, moment titles, and notes are not validated or sanitized.

```typescript
// CURRENT - No validation on title length or content
export const createTrip = mutation({
  args: {
    tripId: v.string(),
    title: v.string(), // No length limit, no sanitization
    // ...
  },
  // ...
});
```

**Recommendation:**

```typescript
// RECOMMENDED - Add validation
import { v } from "convex/values";

const TITLE_MAX_LENGTH = 100;
const NOTE_MAX_LENGTH = 5000;

function sanitizeText(text: string): string {
  return text.trim().slice(0, TITLE_MAX_LENGTH);
}

export const createTrip = mutation({
  args: {
    tripId: v.string(),
    title: v.string(),
    // ...
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);

    // Validate title
    const title = args.title.trim();
    if (title.length === 0) {
      throw new Error("Title is required");
    }
    if (title.length > TITLE_MAX_LENGTH) {
      throw new Error(`Title must be ${TITLE_MAX_LENGTH} characters or less`);
    }

    // Validate dates
    if (args.endDate < args.startDate) {
      throw new Error("End date must be after start date");
    }

    // ... rest of handler
  },
});
```

---

### 7. Missing Error Boundaries in iOS App

**Location:** `trip-bank/Views/Trip/ContentView.swift`, `trip-bank/Views/Trip/TripDetailView.swift`

**Issue:** No graceful error handling for network failures or Convex subscription errors.

```swift
// CURRENT - Errors logged but not shown to user
receiveCompletion: { completion in
    if case .failure(let error) = completion {
        print("❌ [TripStore] Subscription error: \(error)")
    }
}
```

**Recommendation:**

```swift
// RECOMMENDED - Add user-facing error handling
@MainActor
class TripStore: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingError = false  // Add this

    // Add error handling method
    func handleError(_ error: Error, context: String) {
        let userMessage: String

        if let convexError = error as? ConvexError {
            switch convexError {
            case .networkError:
                userMessage = "Unable to connect. Please check your internet connection."
            case .unauthorized:
                userMessage = "Your session has expired. Please sign in again."
            case .convexError(let message):
                userMessage = message
            default:
                userMessage = "Something went wrong. Please try again."
            }
        } else {
            userMessage = "Something went wrong. Please try again."
        }

        errorMessage = userMessage
        showingError = true

        // Log for debugging
        print("❌ [\(context)] \(error)")
    }
}

// In views, add error alert
.alert("Error", isPresented: $tripStore.showingError) {
    Button("OK") { tripStore.showingError = false }
    Button("Retry") { tripStore.retryLastAction() }
} message: {
    Text(tripStore.errorMessage ?? "Unknown error")
}
```

---

### 8. Web App Missing Security Headers

**Location:** `web/next.config.ts`

**Issue:** No security headers configured for the Next.js web app.

```typescript
// CURRENT - web/next.config.ts
const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: '*.convex.cloud',
      },
    ],
  },
}
```

**Recommendation:**

```typescript
// RECOMMENDED - web/next.config.ts
import type { NextConfig } from 'next'

const securityHeaders = [
  {
    key: 'X-DNS-Prefetch-Control',
    value: 'on'
  },
  {
    key: 'Strict-Transport-Security',
    value: 'max-age=63072000; includeSubDomains; preload'
  },
  {
    key: 'X-Frame-Options',
    value: 'SAMEORIGIN'
  },
  {
    key: 'X-Content-Type-Options',
    value: 'nosniff'
  },
  {
    key: 'Referrer-Policy',
    value: 'strict-origin-when-cross-origin'
  },
  {
    key: 'Permissions-Policy',
    value: 'camera=(), microphone=(), geolocation=()'
  },
  {
    key: 'Content-Security-Policy',
    value: `
      default-src 'self';
      script-src 'self' 'unsafe-eval' 'unsafe-inline';
      style-src 'self' 'unsafe-inline';
      img-src 'self' data: https://*.convex.cloud;
      font-src 'self';
      connect-src 'self' https://*.convex.cloud wss://*.convex.cloud;
      frame-ancestors 'none';
    `.replace(/\s+/g, ' ').trim()
  }
];

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: '*.convex.cloud',
      },
    ],
  },
  async headers() {
    return [
      {
        source: '/:path*',
        headers: securityHeaders,
      },
    ];
  },
}

export default nextConfig
```

---

### 9. Missing CI/CD Pipeline

**Location:** `.github/workflows/` (does not exist)

**Issue:** No CI/CD pipeline exists for automated testing, linting, or deployment.

**Recommendation:** Create GitHub Actions workflows:

```yaml
# RECOMMENDED - .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  lint-web:
    name: Lint Web App
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: web
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: web/package-lock.json
      - run: npm ci
      - run: npm run lint
      - run: npm run build

  lint-convex:
    name: Lint Convex Backend
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: convex
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npx tsc --noEmit

  # iOS build would require macOS runner and signing setup
  build-ios:
    name: Build iOS App
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.0.app
      - name: Build
        run: |
          xcodebuild -project trip-bank.xcodeproj \
            -scheme trip-bank \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -configuration Debug \
            build
```

---

### 10. Deprecated userId Field in Trips Schema

**Location:** `convex/schema.ts:22-25`

**Issue:** The schema has both deprecated `userId` and new `ownerId` fields, creating confusion and potential data inconsistency.

```typescript
// CURRENT - convex/schema.ts
trips: defineTable({
  userId: v.string(), // DEPRECATED - use ownerId instead (keep for migration)
  ownerId: v.optional(v.string()), // Trip owner (optional for migration)
  // ...
})
```

**Recommendation:** Create a migration to consolidate these fields:

```typescript
// RECOMMENDED - Migration script
// convex/migrations/consolidateOwnerId.ts

import { mutation } from "../_generated/server";

export const migrateOwnerIds = mutation({
  args: {},
  handler: async (ctx) => {
    // This should be run once by an admin
    const trips = await ctx.db.query("trips").collect();

    let migratedCount = 0;
    for (const trip of trips) {
      if (!trip.ownerId && trip.userId) {
        await ctx.db.patch(trip._id, {
          ownerId: trip.userId,
        });
        migratedCount++;
      }
    }

    return { migratedCount };
  },
});

// After migration, update schema to make ownerId required:
// ownerId: v.string(), // Required after migration
```

---

## Architecture Improvements

### Current Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   iOS App       │     │   Web App       │     │   Convex        │
│   (SwiftUI)     │     │   (Next.js)     │     │   Backend       │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ - TripStore     │     │ - Server        │     │ - Mutations     │
│ - ConvexClient  │────▶│   Components    │────▶│ - Queries       │
│ - Views         │     │ - API Routes    │     │ - File Storage  │
│ - Clerk Auth    │     │                 │     │ - Auth          │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                       │                       │
         └───────────────────────┴───────────────────────┘
                                 │
                         ┌───────▼───────┐
                         │    Clerk      │
                         │   (Auth)      │
                         └───────────────┘
```

### Recommended Improvements

1. **Add API Validation Layer**
```
┌─────────────────┐
│   Validation    │  <- Add Zod schemas for all inputs
│   Middleware    │
└─────────────────┘
```

2. **Implement Proper Error Types**
```typescript
// convex/errors.ts
export class AppError extends Error {
  constructor(
    message: string,
    public code: string,
    public statusCode: number = 400
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string, id: string) {
    super(`${resource} not found: ${id}`, 'NOT_FOUND', 404);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized') {
    super(message, 'UNAUTHORIZED', 401);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Access denied') {
    super(message, 'FORBIDDEN', 403);
  }
}
```

3. **Add Logging Infrastructure**
```typescript
// convex/lib/logger.ts
type LogLevel = 'debug' | 'info' | 'warn' | 'error';

interface LogEntry {
  level: LogLevel;
  message: string;
  context?: Record<string, unknown>;
  timestamp: number;
  userId?: string;
}

export function log(
  level: LogLevel,
  message: string,
  context?: Record<string, unknown>
) {
  const entry: LogEntry = {
    level,
    message,
    context,
    timestamp: Date.now(),
  };

  // In production, send to logging service
  console.log(JSON.stringify(entry));
}
```

---

## Dependency Updates

### Web App (web/package.json)

| Package | Current | Recommended | Notes |
|---------|---------|-------------|-------|
| next | 16.0.7 | 16.0.7 | Latest |
| react | 19.2.0 | 19.2.0 | Latest |
| convex | 1.29.1 | 1.29.1 | Latest |
| typescript | 5.9.3 | 5.9.3 | Latest |

**Missing Dependencies to Add:**
```json
{
  "devDependencies": {
    "eslint": "^9.0.0",
    "eslint-config-next": "^16.0.0",
    "@types/react-dom": "^19.0.0",
    "prettier": "^3.4.0"
  }
}
```

### Convex Backend (package.json)

| Package | Current | Recommended | Notes |
|---------|---------|-------------|-------|
| convex | 1.16.0 | 1.29.1 | **Update recommended** |
| @clerk/backend | 1.0.0 | 1.0.0 | Latest |

---

## UI/UX Enhancements

### iOS App

#### 1. Add Haptic Feedback

```swift
// RECOMMENDED - Add haptic feedback for actions
import UIKit

extension View {
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// Usage in TripCardView
Button {
    hapticFeedback(.light)
    showingTripDetail = true
} label: {
    TripCardContent(trip: trip)
}
```

#### 2. Add Pull-to-Refresh

```swift
// RECOMMENDED - Add pull to refresh
ScrollView {
    LazyVStack(spacing: 16) {
        ForEach(tripStore.trips) { trip in
            // ...
        }
    }
}
.refreshable {
    await tripStore.loadTrips()
}
```

#### 3. Improve Empty States

The current empty state in `TripDetailView.swift:301-354` is good but could include:
- Animated illustrations
- Progressive disclosure of features
- Quick action buttons

### Web App

#### 1. Add Loading Skeletons

```tsx
// RECOMMENDED - web/components/TripSkeleton.tsx
export function TripSkeleton() {
  return (
    <div className="animate-pulse">
      <div className="h-64 bg-gray-200 rounded-3xl mb-4" />
      <div className="h-6 bg-gray-200 rounded w-3/4 mb-2" />
      <div className="h-4 bg-gray-200 rounded w-1/2" />
    </div>
  );
}
```

#### 2. Improve Accessibility

```tsx
// CURRENT - web/app/trip/[slug]/page.tsx
<img src={url} alt={alt} className={className} />

// RECOMMENDED - Add proper alt text and loading states
<Image
  src={url}
  alt={`Photo from ${moment.title}`}
  className={className}
  loading="lazy"
  placeholder="blur"
  blurDataURL="data:image/jpeg;base64,..."
/>
```

---

## Performance Optimizations

### 1. iOS - Implement Image Caching

**Location:** `trip-bank/Services/ConvexClient.swift:559-581`

```swift
// CURRENT - Images compressed but not cached locally
private func compressImage(_ image: UIImage, maxDimension: CGFloat = 1024, quality: CGFloat = 0.8) -> Data?

// RECOMMENDED - Add local caching
import Foundation

actor ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private lazy var cacheDirectory: URL = {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("ImageCache")
    }()

    func image(for key: String) async -> UIImage? {
        // Check memory cache first
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }

        // Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key.md5Hash)
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            cache.setObject(image, forKey: key as NSString)
            return image
        }

        return nil
    }

    func store(_ image: UIImage, for key: String) async {
        cache.setObject(image, forKey: key as NSString)

        // Store to disk asynchronously
        let fileURL = cacheDirectory.appendingPathComponent(key.md5Hash)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL)
        }
    }
}
```

### 2. Web - Add Image Optimization

```tsx
// RECOMMENDED - Use Next.js Image component properly
// web/app/trip/[slug]/page.tsx

import Image from 'next/image';

function MediaItem({ url, type, alt, className, priority = false }) {
  if (type === "video") {
    return (
      <video
        src={url}
        className={className}
        controls={false}
        muted
        playsInline
        loop
        autoPlay
        preload="metadata"
      />
    );
  }

  return (
    <Image
      src={url}
      alt={alt}
      fill
      className={`${className} object-cover`}
      sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
      priority={priority}
      placeholder="blur"
      blurDataURL="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBD..."
    />
  );
}
```

### 3. Convex - Optimize Queries

```typescript
// CURRENT - N+1 query pattern in getPublicPreview
// convex/trips/public.ts:47-59
const momentMediaItems = await Promise.all(
  moments.map(async (moment) => {
    const mediaItems = await ctx.db
      .query("mediaItems")
      .withIndex("by_tripId", (q) => q.eq("tripId", trip.tripId))
      .collect();
    // This fetches ALL media items for EACH moment!
    return mediaItems.filter((item) =>
      moment.mediaItemIDs.includes(item.mediaItemId)
    );
  })
);

// RECOMMENDED - Fetch once, then filter
const allMediaItems = await ctx.db
  .query("mediaItems")
  .withIndex("by_tripId", (q) => q.eq("tripId", trip.tripId))
  .collect();

const mediaItemMap = new Map(
  allMediaItems.map(item => [item.mediaItemId, item])
);

const momentMediaItems = moments.map(moment =>
  moment.mediaItemIDs
    .map(id => mediaItemMap.get(id))
    .filter(Boolean)
);
```

---

## Testing Improvements

### Current State: No Tests

The codebase has **zero automated tests**. This is a critical gap for production readiness.

### Recommended Testing Strategy

#### 1. Convex Backend Tests

```typescript
// convex/__tests__/trips.test.ts
import { convexTest } from "convex-test";
import { expect, test, describe } from "vitest";
import { api } from "../_generated/api";

describe("trips", () => {
  test("createTrip creates a trip with correct data", async () => {
    const t = convexTest();

    // Mock authentication
    const userId = "user_123";
    t.withIdentity({ subject: userId });

    const tripId = await t.mutation(api.trips.trips.createTrip, {
      tripId: "trip-uuid",
      title: "Paris Vacation",
      startDate: Date.now(),
      endDate: Date.now() + 86400000,
    });

    expect(tripId).toBeDefined();

    // Verify the trip was created
    const trip = await t.query(api.trips.trips.getTrip, {
      tripId: "trip-uuid",
    });

    expect(trip?.trip.title).toBe("Paris Vacation");
    expect(trip?.trip.ownerId).toBe(userId);
  });

  test("deleteTrip requires owner permission", async () => {
    const t = convexTest();

    // Create trip as user_123
    t.withIdentity({ subject: "user_123" });
    await t.mutation(api.trips.trips.createTrip, {
      tripId: "trip-uuid",
      title: "My Trip",
      startDate: Date.now(),
      endDate: Date.now() + 86400000,
    });

    // Try to delete as user_456
    t.withIdentity({ subject: "user_456" });

    await expect(
      t.mutation(api.trips.trips.deleteTrip, { tripId: "trip-uuid" })
    ).rejects.toThrow("Only the trip owner can delete the trip");
  });
});
```

#### 2. iOS Unit Tests

```swift
// trip-bankTests/TripStoreTests.swift
import XCTest
@testable import trip_bank

final class TripStoreTests: XCTestCase {
    var sut: TripStore!

    override func setUp() {
        super.setUp()
        sut = TripStore()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testCanEditReturnsTrueForOwner() {
        // Given
        let trip = Trip(
            id: UUID(),
            title: "Test Trip",
            startDate: Date(),
            endDate: Date(),
            ownerId: "user_123"
        )

        // When/Then
        // Would need to mock Clerk.shared.user?.id
        XCTAssertTrue(sut.canEdit(trip: trip))
    }

    func testCanEditReturnsFalseForViewer() {
        let trip = Trip(
            id: UUID(),
            title: "Test Trip",
            startDate: Date(),
            endDate: Date(),
            ownerId: "other_user",
            userRole: "viewer"
        )

        XCTAssertFalse(sut.canEdit(trip: trip))
    }
}
```

#### 3. E2E Tests for Web

```typescript
// web/e2e/trip-preview.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Trip Preview Page', () => {
  test('displays trip information correctly', async ({ page }) => {
    await page.goto('/trip/test-slug');

    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    await expect(page.getByText('moments')).toBeVisible();
  });

  test('shows 404 for invalid trip', async ({ page }) => {
    await page.goto('/trip/nonexistent-trip');

    await expect(page.getByText('Trip Not Found')).toBeVisible();
  });

  test('open in app button works', async ({ page }) => {
    await page.goto('/trip/test-slug');

    const button = page.getByRole('link', { name: /open in app/i });
    await expect(button).toBeVisible();
  });
});
```

---

## Production Readiness Checklist

### Security
- [ ] Remove hardcoded API keys from source code
- [ ] Implement file ownership verification
- [ ] Add rate limiting to mutations
- [ ] Secure subscription update endpoint
- [ ] Add security headers to web app
- [ ] Implement CSRF protection
- [ ] Add input validation to all mutations
- [ ] Run security audit (npm audit, dependency check)

### Performance
- [ ] Implement image caching on iOS
- [ ] Add Next.js Image optimization
- [ ] Fix N+1 query in public preview
- [ ] Add database indexes review
- [ ] Implement lazy loading for media
- [ ] Add bundle analysis for web

### Reliability
- [ ] Add error boundaries in iOS app
- [ ] Add error boundaries in web app
- [ ] Implement retry logic for network failures
- [ ] Add health check endpoints
- [ ] Set up error monitoring (Sentry)
- [ ] Add logging infrastructure

### Testing
- [ ] Add Convex backend unit tests
- [ ] Add iOS unit tests
- [ ] Add iOS UI tests
- [ ] Add web E2E tests
- [ ] Set up test coverage reporting
- [ ] Add visual regression tests

### DevOps
- [ ] Create CI/CD pipeline
- [ ] Set up staging environment
- [ ] Document deployment process
- [ ] Add rollback procedures
- [ ] Set up monitoring/alerting
- [ ] Configure backup strategy

### Documentation
- [ ] Update README with setup instructions
- [ ] Add API documentation
- [ ] Document architecture decisions
- [ ] Create runbook for common issues
- [ ] Add contributing guidelines

### Accessibility
- [ ] Add proper alt text to all images
- [ ] Test with VoiceOver (iOS)
- [ ] Test with screen readers (web)
- [ ] Verify color contrast ratios
- [ ] Add skip links to web app

---

## Priority Matrix

| Issue | Impact | Effort | Priority |
|-------|--------|--------|----------|
| Hardcoded API keys | High | Low | P0 |
| File access security | Critical | Medium | P0 |
| Storage manipulation | High | Low | P0 |
| Rate limiting | High | Medium | P0 |
| Subscription bypass | High | Medium | P0 |
| Input validation | Medium | Low | P1 |
| Error handling | Medium | Medium | P1 |
| Security headers | Medium | Low | P1 |
| CI/CD pipeline | High | Medium | P1 |
| Schema migration | Low | Low | P1 |
| Testing infrastructure | High | High | P1 |
| Performance optimization | Medium | Medium | P2 |
| Accessibility | Medium | Medium | P2 |
| Documentation | Low | Low | P2 |

---

## Implementation Roadmap

### Week 1: Critical Security Fixes
1. Move API keys to secure configuration
2. Implement file ownership verification
3. Secure subscription update endpoint
4. Add basic rate limiting

### Week 2: Security Hardening
1. Add input validation to all mutations
2. Add security headers to web app
3. Run security audit and fix vulnerabilities
4. Set up error monitoring (Sentry)

### Week 3: Testing Foundation
1. Set up testing infrastructure
2. Add critical path unit tests
3. Add Convex backend tests
4. Add basic E2E tests

### Week 4: CI/CD & DevOps
1. Create GitHub Actions CI pipeline
2. Set up staging environment
3. Add deployment automation
4. Document deployment procedures

### Week 5: Performance & Polish
1. Implement image caching
2. Optimize database queries
3. Add loading states and skeletons
4. Improve error messaging

### Week 6: Final Review
1. Complete accessibility audit
2. Final security review
3. Load testing
4. Documentation completion

---

## Resources & References

### Security
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Convex Security Best Practices](https://docs.convex.dev/production/security)
- [Apple App Security Guide](https://developer.apple.com/documentation/security)

### iOS Development
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [SwiftUI Best Practices](https://developer.apple.com/documentation/swiftui)

### Web Development
- [Next.js 15 Documentation](https://nextjs.org/docs)
- [React 19 Documentation](https://react.dev/)
- [Tailwind CSS v4](https://tailwindcss.com/docs)

### Backend
- [Convex Documentation](https://docs.convex.dev/)
- [Clerk Documentation](https://clerk.com/docs)
- [RevenueCat Documentation](https://docs.revenuecat.com/)

### Testing
- [Vitest](https://vitest.dev/)
- [Playwright](https://playwright.dev/)
- [XCTest](https://developer.apple.com/documentation/xctest)

---

*Report generated by Claude Code - December 2025*
