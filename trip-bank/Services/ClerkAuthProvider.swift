import Foundation
import Clerk
import ConvexMobile

/// Custom AuthProvider that integrates Clerk authentication with Convex
/// This reuses the existing Clerk authentication but adapts it for the Convex SDK
class ClerkAuthProvider: AuthProvider {
    typealias AuthData = String // JWT token

    // MARK: - AuthProvider Protocol Requirements

    /// Login method - Since Clerk handles auth separately, this just checks if we have a session
    func login() async throws -> String {
        guard let token = await getAuthToken() else {
            throw AuthError.noSession
        }
        return token
    }

    /// Logout - Clerk handles this in the UI, so we just clear the token
    func logout() async throws {
        // Clerk logout is handled by the UI (Clerk.shared.signOut())
        // Nothing to do here as we don't cache tokens
    }

    /// Login from cached credentials - Check if Clerk has an active session
    func loginFromCache() async throws -> String {
        guard let token = await getAuthToken() else {
            throw AuthError.noSession
        }
        return token
    }

    /// Extract ID token from auth data - In our case, the auth data IS the token
    func extractIdToken(from authData: String) -> String {
        return authData
    }

    // MARK: - Helper Methods

    /// Get auth token from Clerk (reuses existing logic from ConvexClient)
    private func getAuthToken() async -> String? {
        // Get token from Clerk with Convex template
        guard let session = await Clerk.shared.session else {
            print("❌ [ClerkAuthProvider] No Clerk session available")
            return nil
        }

        do {
            // Request token with Convex JWT template
            guard let tokenResource = try await session.getToken(.init(template: "convex")) else {
                print("❌ [ClerkAuthProvider] Token resource is nil - check if 'convex' JWT template exists in Clerk dashboard")
                return nil
            }
            print("✅ [ClerkAuthProvider] Got auth token successfully")
            return tokenResource.jwt
        } catch {
            print("❌ [ClerkAuthProvider] Failed to get Clerk token: \(error)")
            print("❌ [ClerkAuthProvider] Make sure 'convex' JWT template is configured in Clerk dashboard")
            return nil
        }
    }
}

// MARK: - Auth Errors

enum AuthError: Error, LocalizedError {
    case noSession
    case tokenExpired

    var errorDescription: String? {
        switch self {
        case .noSession:
            return "No active Clerk session. Please log in."
        case .tokenExpired:
            return "Authentication token has expired. Please log in again."
        }
    }
}
