import SwiftUI
import Clerk

@main
struct TripBankApp: App {
    @StateObject private var tripStore = TripStore()
    @State private var clerk = Clerk.shared
    @State private var pendingShareSlug: String?

    var body: some Scene {
        WindowGroup {
            ContentView(pendingShareSlug: $pendingShareSlug)
                .environmentObject(tripStore)
                .environment(\.clerk, clerk)
                .task {
                    clerk.configure(publishableKey: "pk_test_bWFnaWNhbC1sYWJyYWRvci0xNy5jbGVyay5hY2NvdW50cy5kZXYk")
                    try? await clerk.load()
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Handle Universal Links: https://rewinded.app/trip/{slug}
        if url.host == "rewinded.app" || url.host == "www.rewinded.app" {
            let pathComponents = url.pathComponents
            if pathComponents.count >= 3 && pathComponents[1] == "trip" {
                let slug = pathComponents[2]
                pendingShareSlug = slug
            }
        }
    }
}
