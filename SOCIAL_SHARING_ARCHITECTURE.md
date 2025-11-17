# Social Sharing & Collaboration Architecture

**Last Updated:** November 16, 2024
**Status:** Planning Phase - **SIMPLIFIED VERSION**

---

## Table of Contents
1. [Product Vision](#product-vision)
2. [Permission Model](#permission-model)
3. [User Flows](#user-flows)
4. [Technical Architecture](#technical-architecture)
5. [Implementation Phases](#implementation-phases)
6. [Edge Cases & Challenges](#edge-cases--challenges)
7. [Viral Loop Optimization](#viral-loop-optimization)
8. [Decisions & Constraints](#decisions--constraints)

---

## Product Vision

Transform TripBank from a personal trip organizer into a **social, collaborative experience** with viral growth mechanics.

### Core Principles
- **Default Private**: Trips only visible to creator by default
- **Shareable Preview**: Text-based link sharing with beautiful web preview
- **Download to View**: Full interactive experience requires app download (viral loop)
- **Collaborative Editing**: Multiple users can co-create trip memories
- **Superior Alternative**: Beat Apple Shared Photo Album with better UX

### Viral Loop Mechanism
```
User creates trip → Shares preview link → Recipient sees beautiful snapshot
→ Downloads app to view full experience → Creates own trips → Loop continues
```

---

## Permission Model

### Three Permission Levels

#### **Owner** (Trip Creator)
- Full control over trip content (edit/delete moments, media)
- Manage all permissions (upgrade viewers to collaborators, remove access)
- Can delete the trip entirely
- Can transfer ownership to another user (future)
- Pays for storage (all media in trip)

#### **Collaborator** (Full Edit Access)
- **Add/edit/delete ANY moments and media** (not just their own)
- Can upgrade viewers to collaborators
- Cannot delete the trip itself
- Cannot remove the owner
- Full creative control alongside owner

#### **Viewer** (Read-Only, Default for Share Link)
- View the interactive canvas
- See all moments and media
- Click into expanded view, zoom images
- Cannot edit, add, or delete anything
- **This is the default role when joining via share link**

#### **Public Preview** (Pre-Download, Web-Only)
- Web-based static snapshot
- Shows 3-5 moments in beautiful layout
- No interaction beyond scrolling
- Strong CTA to download app
- Available to anyone with link

---

## User Flows

### **The Simple Flow: One Link for Everyone**

**Scenario:** Alice shares her Paris trip in a group chat

```
1. Alice creates "Paris 2024" trip

2. Alice taps "Share Trip"
   → App generates link: https://rewinded.app/t/paris-2024-xl8k
   → Shows trip code: "PARIS24"

3. Alice texts link to group chat (Bob, Carol, David)
   "Check out our Paris trip! 🗼✨
    https://rewinded.app/t/paris-2024-xl8k
    Code: PARIS24"

4. Bob clicks link (doesn't have app)
   → Opens Safari web preview:
      • Beautiful canvas snapshot
      • "24 photos • 8 moments • 3 days"
      • "Download Rewinded to view full trip"
      • Shows trip code: "PARIS24"

5. Bob taps "Download" → App Store → Installs app

6. Bob opens app → Signs in with Apple

7. Bob clicks the link AGAIN (now app is installed)
   → Universal Link works! ✅
   → App opens: "Join 'Paris 2024' as a viewer?" [Accept]

   (Alternative: Bob enters code "PARIS24" in app)

8. Bob accepts → Trip appears in "Shared with Me" as VIEWER

9. Bob can view but not edit

10. Alice opens "Manage Access"
    → Sees: Bob (Viewer)
    → Taps "Upgrade to Collaborator"
    → Bob can now edit!

11. Carol and David repeat steps 4-8
    → All join as viewers
    → Alice upgrades Carol to collaborator
    → David stays as viewer

Viral Loop Complete ✓: All users can create and share their own trips
```

---

## Technical Architecture

### A. Data Model Changes

#### Updated Table: `trips`
```typescript
{
  // Existing fields
  tripId: string,
  userId: string,              // DEPRECATED (keep for migration)
  ownerId: string,             // Trip owner (required)
  title: string,
  startDate: number,
  endDate: number,
  coverImageStorageId?: string,

  // NEW: Sharing fields
  shareSlug: string,           // "paris-2024-xl8k" (unique, URL-safe)
  shareCode: string,           // "PARIS24" (human-readable, 6-8 chars)
  shareLinkEnabled: boolean,   // Can people join via link?
  previewImageStorageId?: string, // Generated preview snapshot

  createdAt: number,
  updatedAt: number
}

// NEW Indexes:
// - by_shareSlug (lookup trip from URL)
// - by_shareCode (lookup trip from manual code entry)
```

#### New Table: `tripPermissions`
```typescript
{
  tripId: string,              // Foreign key to trips
  userId: string,              // Who has access (from users.clerkId)
  role: "owner" | "collaborator" | "viewer",
  grantedVia: "share_link" | "upgraded",
  invitedBy: string,           // userId who shared/upgraded
  acceptedAt: number,          // When user joined
  createdAt: number
}

// Indexes:
// - by_tripId (get all users with access)
// - by_userId (get all trips user has access to)
// - by_tripId_userId (check specific permission)
```

#### Enhanced Table: `users`
```typescript
{
  clerkId: string,             // Clerk user ID (primary key)
  email?: string,
  name?: string,
  imageUrl?: string,           // Avatar from Clerk
  phoneNumber?: string,        // From Clerk (future use)
  username?: string,           // Unique handle (future: @alice)
  createdAt: number
}
```

**What we REMOVED:**
- ❌ `invites` table (no longer needed!)
- ❌ `accessRequests` table (manual upgrades instead)
- ❌ Complex token matching logic
- ❌ Phone number matching system

---

### B. Backend Mutations & Queries (Simplified!)

#### 1. Share Link Generation
```typescript
export const generateShareLink = mutation({
  args: { tripId: v.string() },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);

    const trip = await ctx.db
      .query("trips")
      .withIndex("by_tripId", q => q.eq("tripId", args.tripId))
      .first();

    if (!trip) throw new Error("Trip not found");
    if (trip.ownerId !== userId) throw new Error("Unauthorized");

    // Generate slug + code if they don't exist
    if (!trip.shareSlug) {
      const slug = generateSlug(trip.title, trip.tripId);  // "paris-2024-xl8k"
      const code = generateCode();  // "PARIS24"

      await ctx.db.patch(trip._id, {
        shareSlug: slug,
        shareCode: code,
        shareLinkEnabled: true
      });

      return {
        url: `https://rewinded.app/t/${slug}`,
        code: code
      };
    }

    return {
      url: `https://rewinded.app/t/${trip.shareSlug}`,
      code: trip.shareCode
    };
  }
});

// Helper: Generate URL-safe slug
function generateSlug(title: string, tripId: string): string {
  const titleSlug = title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .substring(0, 20);
  const random = tripId.substring(0, 8);
  return `${titleSlug}-${random}`;
  // Example: "paris-2024-xl8k"
}

// Helper: Generate human-readable code
function generateCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No ambiguous chars
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
  // Example: "PARIS24" or "XY8K2P"
}
```

#### 2. Join Trip via Link (Always as Viewer)
```typescript
export const joinTripViaLink = mutation({
  args: {
    shareSlug: v.optional(v.string()),
    shareCode: v.optional(v.string())
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);

    if (!args.shareSlug && !args.shareCode) {
      throw new Error("Must provide either shareSlug or shareCode");
    }

    // Find trip by slug or code
    let trip;
    if (args.shareSlug) {
      trip = await ctx.db
        .query("trips")
        .withIndex("by_shareSlug", q => q.eq("shareSlug", args.shareSlug))
        .first();
    } else {
      trip = await ctx.db
        .query("trips")
        .withIndex("by_shareCode", q => q.eq("shareCode", args.shareCode))
        .first();
    }

    if (!trip) throw new Error("Trip not found");
    if (!trip.shareLinkEnabled) throw new Error("Trip sharing is disabled");

    // Check if user already has access
    const existingPermission = await ctx.db
      .query("tripPermissions")
      .withIndex("by_tripId_userId", q =>
        q.eq("tripId", trip.tripId).eq("userId", userId))
      .first();

    if (existingPermission) {
      return { tripId: trip.tripId, role: existingPermission.role };
    }

    // Grant viewer permission
    await ctx.db.insert("tripPermissions", {
      tripId: trip.tripId,
      userId: userId,
      role: "viewer",
      grantedVia: "share_link",
      invitedBy: trip.ownerId,
      acceptedAt: Date.now(),
      createdAt: Date.now()
    });

    return { tripId: trip.tripId, role: "viewer" };
  }
});
```

#### 3. Get Public Preview (No Auth)
```typescript
export const getPublicPreview = query({
  args: { shareSlug: v.string() },
  handler: async (ctx, args) => {
    // NO AUTH CHECK - public endpoint

    const trip = await ctx.db
      .query("trips")
      .withIndex("by_shareSlug", q => q.eq("shareSlug", args.shareSlug))
      .first();

    if (!trip || !trip.shareLinkEnabled) {
      throw new Error("Trip not found");
    }

    // Get preview moments (first 5)
    const moments = await ctx.db
      .query("moments")
      .withIndex("by_tripId", q => q.eq("tripId", trip.tripId))
      .take(5);

    // Get media items for preview
    const mediaItems = await ctx.db
      .query("mediaItems")
      .withIndex("by_tripId", q => q.eq("tripId", trip.tripId))
      .collect();

    // Get collaborators (for social proof)
    const permissions = await ctx.db
      .query("tripPermissions")
      .withIndex("by_tripId", q => q.eq("tripId", trip.tripId))
      .collect();

    const collaboratorUsers = await Promise.all(
      permissions.slice(0, 5).map(p =>
        ctx.db
          .query("users")
          .withIndex("by_clerkId", q => q.eq("clerkId", p.userId))
          .first()
      )
    );

    return {
      trip: {
        title: trip.title,
        shareCode: trip.shareCode,
        startDate: trip.startDate,
        endDate: trip.endDate,
        coverImageUrl: trip.coverImageStorageId
          ? await getFileUrl(ctx, trip.coverImageStorageId)
          : null,
        previewImageUrl: trip.previewImageStorageId
          ? await getFileUrl(ctx, trip.previewImageStorageId)
          : null
      },
      moments: await Promise.all(moments.map(async (m) => ({
        title: m.title,
        mediaCount: m.mediaItemIDs.length,
        thumbnailUrl: await getFirstMediaThumbnail(ctx, m.mediaItemIDs)
      }))),
      collaborators: collaboratorUsers
        .filter(u => u !== null)
        .map(u => ({
          name: u.name ?? "Unknown",
          imageUrl: u.imageUrl ?? null
        })),
      stats: {
        totalPhotos: mediaItems.length,
        totalMoments: moments.length,
        collaboratorCount: permissions.length,
        duration: formatDuration(trip.startDate, trip.endDate)
      }
    };
  }
});
```

#### 4. Get Shared Trips
```typescript
export const getSharedTrips = query({
  handler: async (ctx) => {
    const userId = await requireAuth(ctx);

    // Get all permissions for this user (except owner)
    const permissions = await ctx.db
      .query("tripPermissions")
      .withIndex("by_userId", q => q.eq("userId", userId))
      .filter(q => q.neq(q.field("role"), "owner"))
      .collect();

    // Fetch trip details
    const trips = await Promise.all(
      permissions.map(async (perm) => {
        const trip = await ctx.db
          .query("trips")
          .withIndex("by_tripId", q => q.eq("tripId", perm.tripId))
          .first();

        return {
          ...trip,
          userRole: perm.role,
          joinedAt: perm.acceptedAt
        };
      })
    );

    return trips.filter(t => t !== null);
  }
});
```

#### 5. Update Permission (Upgrade/Downgrade)
```typescript
export const updatePermission = mutation({
  args: {
    tripId: v.string(),
    userId: v.string(),
    newRole: v.union(v.literal("viewer"), v.literal("collaborator"))
  },
  handler: async (ctx, args) => {
    const currentUserId = await requireAuth(ctx);

    // Check if current user can manage permissions
    const canManage = await canUserManagePermissions(
      ctx,
      args.tripId,
      currentUserId
    );

    if (!canManage) {
      throw new Error("Only owner or collaborators can manage permissions");
    }

    // Find permission to update
    const permission = await ctx.db
      .query("tripPermissions")
      .withIndex("by_tripId_userId", q =>
        q.eq("tripId", args.tripId).eq("userId", args.userId))
      .first();

    if (!permission) throw new Error("User not found");
    if (permission.role === "owner") throw new Error("Cannot change owner role");

    // Update role
    await ctx.db.patch(permission._id, {
      role: args.newRole,
      grantedVia: args.newRole === "collaborator" ? "upgraded" : "share_link"
    });

    return { success: true };
  }
});

// Helper: Who can manage permissions?
async function canUserManagePermissions(
  ctx: QueryCtx | MutationCtx,
  tripId: string,
  userId: string
): Promise<boolean> {
  const trip = await ctx.db
    .query("trips")
    .withIndex("by_tripId", q => q.eq("tripId", tripId))
    .first();

  // Owner can always manage
  if (trip?.ownerId === userId) return true;

  // Collaborators can also manage
  const permission = await ctx.db
    .query("tripPermissions")
    .withIndex("by_tripId_userId", q =>
      q.eq("tripId", tripId).eq("userId", userId))
    .first();

  return permission?.role === "collaborator";
}
```

#### 6. Remove Access
```typescript
export const removeAccess = mutation({
  args: {
    tripId: v.string(),
    userId: v.string()
  },
  handler: async (ctx, args) => {
    const currentUserId = await requireAuth(ctx);

    const canManage = await canUserManagePermissions(
      ctx,
      args.tripId,
      currentUserId
    );

    if (!canManage) throw new Error("Unauthorized");

    const permission = await ctx.db
      .query("tripPermissions")
      .withIndex("by_tripId_userId", q =>
        q.eq("tripId", args.tripId).eq("userId", args.userId))
      .first();

    if (!permission) throw new Error("User not found");
    if (permission.role === "owner") throw new Error("Cannot remove owner");

    await ctx.db.delete(permission._id);

    return { success: true };
  }
});
```

#### 7. Get Trip Permissions
```typescript
export const getTripPermissions = query({
  args: { tripId: v.string() },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);

    // Check if user has access to this trip
    const hasAccess = await canUserView(ctx, args.tripId, userId);
    if (!hasAccess) throw new Error("Unauthorized");

    const permissions = await ctx.db
      .query("tripPermissions")
      .withIndex("by_tripId", q => q.eq("tripId", args.tripId))
      .collect();

    const usersWithPermissions = await Promise.all(
      permissions.map(async (perm) => {
        const user = await ctx.db
          .query("users")
          .withIndex("by_clerkId", q => q.eq("clerkId", perm.userId))
          .first();

        return {
          userId: perm.userId,
          role: perm.role,
          user: {
            name: user?.name ?? "Unknown",
            email: user?.email,
            imageUrl: user?.imageUrl
          },
          joinedAt: perm.acceptedAt,
          grantedVia: perm.grantedVia
        };
      })
    );

    return usersWithPermissions;
  }
});
```

---

### C. Shareable Link System

#### Link Format
```
https://rewinded.app/t/{shareSlug}
```

**Examples:**
- `https://rewinded.app/t/paris-2024-xl8k`
- `https://rewinded.app/t/cabo-trip-a7f9`
- `https://rewinded.app/t/nyc-weekend-b2d4`

**Trip Codes (for manual entry):**
- `PARIS24`
- `CABO8K`
- `NYC42D`

#### Share Flow
```
1. User taps "Share Trip" → Share sheet opens

2. App calls generateShareLink(tripId)
   → Returns: { url: "...", code: "PARIS24" }

3. Share sheet shows:
   ┌─────────────────────────────┐
   │ rewinded.app/t/paris-xl8k   │
   │ Code: PARIS24               │
   │ [ Copy Link ] [ Share... ]  │
   └─────────────────────────────┘

4. User taps "Share..." → Native iOS share sheet
   → Pre-filled message:
      "Check out my Paris trip! 🗼✨
       https://rewinded.app/t/paris-2024-xl8k"

5. User texts to group chat
```

---

### D. Web Preview Page

**Tech Stack:** Next.js or simple static site

**URL:** `https://rewinded.app/t/{shareSlug}`

**Page Structure:**
```html
<!DOCTYPE html>
<html>
<head>
  <title>Paris 2024 - Rewinded</title>

  <!-- Open Graph for link previews in Messages -->
  <meta property="og:title" content="Paris 2024" />
  <meta property="og:image" content="[preview snapshot URL]" />
  <meta property="og:description" content="24 photos • 8 moments • 3 days" />

  <!-- iOS Smart App Banner (helps if app already installed) -->
  <meta name="apple-itunes-app"
        content="app-id=XXXXXXX, app-argument=rewinded://t/paris-2024-xl8k">
</head>

<body>
  <div class="preview-container">
    <!-- Header -->
    <header>
      <img src="cover-image.jpg" class="cover" />
      <h1>Paris 2024</h1>
      <p class="dates">May 15-18, 2024</p>

      <!-- Collaborators -->
      <div class="collaborators">
        <img src="avatar1.jpg" class="avatar" />
        <img src="avatar2.jpg" class="avatar" />
        <span>Alice + 2 friends</span>
      </div>

      <!-- Stats -->
      <div class="stats">
        📷 24 photos • ✨ 8 moments • 📍 3 days
      </div>
    </header>

    <!-- Moment Grid Preview -->
    <div class="moment-grid">
      <!-- Show 4-6 moment cards -->
      <div class="moment-card">
        <img src="moment1.jpg" />
        <div class="title">Eiffel Tower Sunset</div>
      </div>

      <!-- Last 2 blurred -->
      <div class="moment-card locked">
        <img src="blurred.jpg" class="blur" />
        <div class="lock">🔒 Download to view more</div>
      </div>
    </div>

    <!-- Trip Code (prominent!) -->
    <div class="trip-code">
      <strong>Trip Code: PARIS24</strong>
      <p>You'll need this after downloading</p>
    </div>

    <!-- CTA -->
    <div class="cta">
      <button onclick="downloadApp()" class="primary">
        Download Rewinded to View Full Trip
      </button>
      <p class="hint">
        💡 After downloading, tap this link again<br/>
        or enter code <strong>PARIS24</strong>
      </p>
    </div>
  </div>

  <script>
    function downloadApp() {
      // Try to open app if installed (Universal Link)
      window.location = 'rewinded://t/paris-2024-xl8k';

      // Fallback to App Store after 500ms
      setTimeout(() => {
        window.location = 'https://apps.apple.com/app/rewinded/idXXXXXXX';
      }, 500);
    }
  </script>
</body>
</html>
```

---

### E. iOS Deep Linking

#### Universal Links Setup

**1. Associated Domains Entitlement:**
```xml
<!-- trip-bank.entitlements -->
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:rewinded.app</string>
</array>
```

**2. Apple App Site Association File:**
```json
// Host at: https://rewinded.app/.well-known/apple-app-site-association
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.com.yourcompany.rewinded",
        "paths": ["/t/*"]
      }
    ]
  }
}
```

**3. Handle Deep Links in App:**
```swift
// In TripBankApp.swift

// Handle custom scheme: rewinded://t/paris-2024-xl8k
.onOpenURL { url in
    if url.scheme == "rewinded", url.host == "t",
       let slug = url.pathComponents.last {
        handleTripShare(slug: slug)
    }
}

// Handle universal links: https://rewinded.app/t/paris-2024-xl8k
.onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
    guard let url = activity.webpageURL,
          url.host == "rewinded.app",
          url.pathComponents.count >= 3,
          url.pathComponents[1] == "t" else { return }

    let slug = url.pathComponents[2]
    handleTripShare(slug: slug)
}

func handleTripShare(slug: String) {
    Task {
        if !tripStore.isAuthenticated {
            // Store for after auth
            UserDefaults.standard.set(slug, forKey: "pendingTripSlug")
            showLogin = true
        } else {
            // Join immediately
            try await tripStore.joinTrip(shareSlug: slug)
        }
    }
}

// After authentication completes
.onChange(of: clerk.isAuthenticated) { isAuth in
    if isAuth, let slug = UserDefaults.standard.string(forKey: "pendingTripSlug") {
        Task {
            try await tripStore.joinTrip(shareSlug: slug)
            UserDefaults.standard.removeObject(forKey: "pendingTripSlug")
        }
    }
}
```

---

## iOS App Changes

### A. New UI Components

#### 1. Share Trip Sheet (Simplified!)
```swift
struct ShareTripView: View {
    let trip: Trip
    @State private var shareInfo: ShareInfo?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Share Trip")
                .font(.title2)
                .bold()

            if let info = shareInfo {
                VStack(spacing: 12) {
                    // URL
                    HStack {
                        Text(info.url)
                            .font(.caption)
                            .foregroundColor(.blue)

                        Spacer()

                        Button("Copy") {
                            UIPasteboard.general.string = info.url
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)

                    // Code
                    VStack(spacing: 4) {
                        Text("Trip Code")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(info.code)
                            .font(.title)
                            .bold()
                            .tracking(2)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)

                    Text("Anyone with this link can view your trip")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Native share button
                    ShareLink(
                        item: URL(string: info.url)!,
                        message: Text("Check out my \(trip.title) trip! ✨")
                    ) {
                        Label("Share Link", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if isLoading {
                ProgressView("Generating share link...")
            }
        }
        .padding()
        .task {
            await loadShareInfo()
        }
    }

    func loadShareInfo() async {
        isLoading = true
        do {
            shareInfo = try await ConvexClient.shared.generateShareLink(
                tripId: trip.id.uuidString
            )
        } catch {
            print("Error generating share link: \(error)")
        }
        isLoading = false
    }
}

struct ShareInfo {
    let url: String
    let code: String
}
```

#### 2. Join Trip View (Manual Code Entry)
```swift
struct JoinTripView: View {
    @State private var tripCode = ""
    @EnvironmentObject var tripStore: TripStore
    @State private var isJoining = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Join a Trip")
                .font(.title2)
                .bold()

            Text("Enter the trip code shared with you")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("Trip Code", text: $tripCode)
                .textInputAutocapitalization(.characters)
                .font(.title3)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)

            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button("Join Trip") {
                joinTrip()
            }
            .buttonStyle(.borderedProminent)
            .disabled(tripCode.isEmpty || isJoining)

            if isJoining {
                ProgressView()
            }
        }
        .padding()
    }

    func joinTrip() {
        isJoining = true
        error = nil

        Task {
            do {
                try await tripStore.joinTrip(shareCode: tripCode)
                // Navigate to trip
            } catch {
                self.error = "Invalid trip code"
            }
            isJoining = false
        }
    }
}
```

#### 3. Manage Access View
```swift
struct ManageAccessView: View {
    let trip: Trip
    @State private var permissions: [TripPermission] = []
    @EnvironmentObject var tripStore: TripStore

    var body: some View {
        List {
            // Owner section
            Section("Owner") {
                ForEach(ownerPermissions) { perm in
                    PermissionRow(permission: perm, canModify: false)
                }
            }

            // Collaborators section
            if !collaboratorPermissions.isEmpty {
                Section("Collaborators") {
                    ForEach(collaboratorPermissions) { perm in
                        PermissionRow(permission: perm, canModify: true) {
                            Menu {
                                Button("Change to Viewer") {
                                    updateRole(perm, to: .viewer)
                                }
                                Button("Remove Access", role: .destructive) {
                                    removeAccess(perm)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
            }

            // Viewers section
            if !viewerPermissions.isEmpty {
                Section("Viewers") {
                    ForEach(viewerPermissions) { perm in
                        PermissionRow(permission: perm, canModify: true) {
                            Menu {
                                Button("Upgrade to Collaborator") {
                                    updateRole(perm, to: .collaborator)
                                }
                                Button("Remove Access", role: .destructive) {
                                    removeAccess(perm)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Manage Access")
        .task {
            await loadPermissions()
        }
    }

    var ownerPermissions: [TripPermission] {
        permissions.filter { $0.role == .owner }
    }

    var collaboratorPermissions: [TripPermission] {
        permissions.filter { $0.role == .collaborator }
    }

    var viewerPermissions: [TripPermission] {
        permissions.filter { $0.role == .viewer }
    }

    func loadPermissions() async {
        do {
            permissions = try await tripStore.getTripPermissions(
                tripId: trip.id.uuidString
            )
        } catch {
            print("Error loading permissions: \(error)")
        }
    }

    func updateRole(_ permission: TripPermission, to newRole: PermissionRole) {
        Task {
            try await tripStore.updatePermission(
                tripId: trip.id.uuidString,
                userId: permission.userId,
                newRole: newRole
            )
            await loadPermissions()
        }
    }

    func removeAccess(_ permission: TripPermission) {
        Task {
            try await tripStore.removeAccess(
                tripId: trip.id.uuidString,
                userId: permission.userId
            )
            await loadPermissions()
        }
    }
}

struct PermissionRow<Actions: View>: View {
    let permission: TripPermission
    let canModify: Bool
    @ViewBuilder let actions: () -> Actions

    init(permission: TripPermission, canModify: Bool, @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }) {
        self.permission = permission
        self.canModify = canModify
        self.actions = actions
    }

    var body: some View {
        HStack {
            // Avatar
            if let imageUrl = permission.user.imageUrl {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image.resizable()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            }

            VStack(alignment: .leading) {
                Text(permission.user.name)
                    .font(.body)

                Text(roleText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if canModify {
                actions()
            } else {
                roleIcon
            }
        }
    }

    var roleText: String {
        switch permission.role {
        case .owner: return "Owner"
        case .collaborator: return "Can edit"
        case .viewer: return "Can view"
        }
    }

    var roleIcon: some View {
        switch permission.role {
        case .owner: return Image(systemName: "star.fill")
        case .collaborator: return Image(systemName: "pencil")
        case .viewer: return Image(systemName: "eye")
        }
    }
}
```

#### 4. Shared with Me Tab
```swift
// In ContentView.swift

enum Tab {
    case myTrips
    case sharedWithMe
}

@State private var selectedTab: Tab = .myTrips

var body: some View {
    NavigationStack {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Trips", selection: $selectedTab) {
                Text("My Trips").tag(Tab.myTrips)
                Text("Shared with Me").tag(Tab.sharedWithMe)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            if selectedTab == .myTrips {
                myTripsView
            } else {
                sharedTripsView
            }
        }
        .navigationTitle("Rewinded")
    }
}

var sharedTripsView: some View {
    List(sharedTrips) { trip in
        NavigationLink(destination: TripDetailView(trip: trip)) {
            VStack(alignment: .leading, spacing: 8) {
                Text(trip.title)
                    .font(.headline)

                HStack {
                    Image(systemName: trip.userRole == .collaborator ? "pencil" : "eye")
                        .font(.caption)

                    Text(trip.userRole == .collaborator ? "You can edit" : "View only")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
```

---

### B. File Structure

**New Files:**
```
trip-bank/Views/Sharing/
├── ShareTripView.swift           # Share sheet
├── JoinTripView.swift            # Manual code entry
├── ManageAccessView.swift        # Permission management
└── PermissionRow.swift           # Reusable permission row

trip-bank/Models/
├── Permission.swift              # Permission model
└── PermissionRole.swift          # Enum: owner, collaborator, viewer
```

**Modified Files:**
```
trip-bank/Models/
├── Trip.swift                    # Add shareSlug, shareCode, ownerId
├── TripStore.swift               # Add sharing methods

trip-bank/Services/
├── ConvexClient.swift            # Add sharing mutations

trip-bank/Views/
├── ContentView.swift             # Add "Shared with Me" tab
├── TripDetailView.swift          # Add share button, manage access
└── TripBankApp.swift             # Add deep link handling
```

---

## Permission Enforcement

### Backend
Every mutation that modifies trip data must check permissions:

```typescript
// Helper functions
async function canUserView(ctx, tripId: string, userId: string): Promise<boolean> {
  const trip = await getTripByIdquery(ctx, tripId);
  if (trip?.ownerId === userId) return true;

  const permission = await ctx.db
    .query("tripPermissions")
    .withIndex("by_tripId_userId", q =>
      q.eq("tripId", tripId).eq("userId", userId))
    .first();

  return permission !== null;
}

async function canUserEdit(ctx, tripId: string, userId: string): Promise<boolean> {
  const trip = await getTripById(ctx, tripId);
  if (trip?.ownerId === userId) return true;

  const permission = await ctx.db
    .query("tripPermissions")
    .withIndex("by_tripId_userId", q =>
      q.eq("tripId", tripId).eq("userId", userId))
    .first();

  return permission?.role === "collaborator";
}

// Use in all mutations
export const updateMoment = mutation({
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);
    const moment = await getMoment(ctx, args.momentId);

    if (!await canUserEdit(ctx, moment.tripId, userId)) {
      throw new Error("You don't have permission to edit this trip");
    }

    // Proceed with update...
  }
});
```

### iOS
Conditional UI based on permissions:

```swift
// In TripStore
func canEdit(trip: Trip) -> Bool {
    guard let currentUserId = currentUser?.clerkId else { return false }

    if trip.ownerId == currentUserId { return true }

    return trip.permissions.contains {
        $0.userId == currentUserId && $0.role == .collaborator
    }
}

// In views
if tripStore.canEdit(trip) {
    Button("Add Moment") { ... }
    Button("Edit") { ... }
    Button("Delete") { ... }
}
```

---

## Implementation Phases

### Phase 1: Core Permission System (Week 1-2)

**Backend:**
- [ ] Add `shareSlug` and `shareCode` to trips schema
- [ ] Add `tripPermissions` table to schema
- [ ] Add indexes: by_shareSlug, by_shareCode, by_tripId_userId
- [ ] Implement `canUserEdit()` and `canUserView()` helpers
- [ ] Update ALL mutations to check permissions
- [ ] Implement `getTripPermissions()` query
- [ ] Implement `getSharedTrips()` query

**iOS:**
- [ ] Update Trip model with shareSlug, shareCode, ownerId
- [ ] Create Permission.swift and PermissionRole.swift models
- [ ] Add permission checking methods to TripStore
- [ ] Update UI to conditionally show edit buttons

**Estimated Time:** 5-7 days

---

### Phase 2: Share Link Generation (Week 2-3)

**Backend:**
- [ ] Implement `generateShareLink()` mutation
- [ ] Implement slug + code generation logic
- [ ] Implement `joinTripViaLink()` mutation (by slug or code)
- [ ] Test link generation and joining

**iOS:**
- [ ] Create ShareTripView.swift
- [ ] Add "Share Trip" button to TripDetailView
- [ ] Implement share link generation
- [ ] Integrate native iOS ShareLink
- [ ] Create JoinTripView.swift for manual code entry
- [ ] Add deep link URL scheme (rewinded://)
- [ ] Test sharing flow

**Estimated Time:** 4-6 days

---

### Phase 3: Web Preview Page (Week 3-4)

**Web:**
- [ ] Set up Next.js project at rewinded.app
- [ ] Design preview page (match iOS aesthetic)
- [ ] Implement `getPublicPreview()` query
- [ ] Display trip title, dates, moments preview
- [ ] Show trip code prominently
- [ ] Add CTA button with App Store redirect
- [ ] Set up Universal Links (apple-app-site-association)
- [ ] Add Open Graph tags for rich previews
- [ ] Deploy to Vercel

**iOS:**
- [ ] Implement Universal Link handling
- [ ] Test deep linking: web → app
- [ ] Handle cold start (app not installed)
- [ ] Implement preview snapshot generation (optional)

**Estimated Time:** 6-8 days

---

### Phase 4: Permission Management (Week 4-5)

**Backend:**
- [ ] Implement `updatePermission()` mutation
- [ ] Implement `removeAccess()` mutation
- [ ] Add validation (can't remove owner, etc.)

**iOS:**
- [ ] Create ManageAccessView.swift
- [ ] Show list of users with access
- [ ] Implement "Upgrade to Collaborator" button
- [ ] Implement "Change to Viewer" button
- [ ] Implement "Remove Access" button
- [ ] Add collaborator avatars to TripDetailView header
- [ ] Test permission changes

**Estimated Time:** 4-6 days

---

### Phase 5: Shared with Me Tab (Week 5)

**Backend:**
- [ ] Ensure `getSharedTrips()` returns correct data

**iOS:**
- [ ] Add "Shared with Me" tab to ContentView
- [ ] Fetch and display shared trips
- [ ] Show role badges (viewer/collaborator)
- [ ] Handle navigation to shared trips

**Estimated Time:** 2-3 days

---

### Phase 6: Testing & Polish (Week 6)

- [ ] Test full flow: Share → Preview → Download → Join
- [ ] Test permission enforcement
- [ ] Test Universal Links on physical device
- [ ] Test manual code entry
- [ ] Test upgrade/downgrade permissions
- [ ] Optimize preview generation
- [ ] Add error handling
- [ ] Polish UI animations

**Estimated Time:** 4-6 days

---

**Total MVP Timeline:** 5-6 weeks

---

## Edge Cases & Challenges

### 1. Universal Link Cold Start
**Problem:** User clicks link before app is installed

**Solution:**
- Web preview prominently shows trip code
- After install, user can:
  - Click link again (Universal Link works now)
  - Or enter code manually in app

### 2. Storage Limits
**Decision:** 100 media items per trip (owner pays for storage)

### 3. Collaborator Abuse
**Mitigations:**
- Soft deletes with 30-day recovery (future)
- Only owner can delete trip
- Owner can demote/remove collaborators anytime

### 4. Who Can Upgrade?
**Decision:** Both owner AND collaborators can upgrade viewers
- More democratic
- Matches "full edit access" philosophy

---

## Viral Loop Optimization

### Preview Page Best Practices
- Show 4-6 best moments
- Blur last 2 moments with lock icon
- Display stats: "24 photos • 8 moments"
- Show collaborators for social proof
- **Prominently display trip code**
- Strong CTA: "Download Rewinded to View Full Trip"

### Share Message Template
```
Check out our Paris trip! 🗼✨
https://rewinded.app/t/paris-2024-xl8k

Tap the link after downloading, or enter code: PARIS24
```

---

## Decisions & Constraints

### Confirmed Decisions

1. **App Name:** Rewinded (domain: rewinded.app - purchased for $6)

2. **Sharing Model:** One link for everyone
   - Everyone joins as viewer by default
   - Manual upgrades to collaborator

3. **No Phone Matching:** Simplified flow
   - Rely on Universal Links + manual code entry
   - No complex invite matching

4. **Storage Limits:** 100 media items per trip

5. **Collaborator Permissions:**
   - Full edit access (any moment/media)
   - Can upgrade viewers to collaborators

6. **Permission Management:**
   - Owner + collaborators can manage permissions
   - Democratic model

---

## Success Metrics

- [ ] User can share trip via text
- [ ] Web preview loads in <2 seconds
- [ ] User can join via link OR code
- [ ] Permissions enforced on backend
- [ ] Collaborators can upgrade viewers
- [ ] Viral loop measured

**Target Conversion:**
- Preview → Download: >30%
- Download → Join: >70%
- Viewer → Collaborator: ~20%

---

**Document Version:** 2.0 (Simplified)
**Last Updated:** November 16, 2024
**Status:** Ready for Implementation
