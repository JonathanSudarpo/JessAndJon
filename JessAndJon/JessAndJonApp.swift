import SwiftUI

@main
struct JessAndJonApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var firebaseService = FirebaseService.shared
    
    var body: some Scene {
        WindowGroup {
            if appState.isOnboarded {
                ContentView()
                    .environmentObject(appState)
                    .environmentObject(firebaseService)
            } else {
                OnboardingView()
                    .environmentObject(appState)
                    .environmentObject(firebaseService)
            }
        }
    }
}
