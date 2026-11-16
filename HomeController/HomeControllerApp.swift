import SwiftUI

@main
struct HomeControllerApp: App {
    @StateObject private var store = HomeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Wall-mounted: never let the screen auto-lock while the app is open.
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
    }
}
