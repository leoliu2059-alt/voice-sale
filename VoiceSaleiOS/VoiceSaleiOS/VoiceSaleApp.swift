import SwiftUI

@main
struct VoiceSaleApp: App {
    @StateObject private var auth = SupabaseAuthStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .task {
                    await auth.restoreOrRefreshIfNeeded()
                }
                .onOpenURL { url in
                    Task {
                        await auth.handleAuthCallback(url)
                    }
                }
        }
    }
}
