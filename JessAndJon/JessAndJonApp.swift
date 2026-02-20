import SwiftUI
import FirebaseCore
import OSLog

@main
struct JessAndJonApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = AuthService.shared
    @State private var isAuthValidated = false // Track if we've validated auth state
    
    private let logger = Logger(subsystem: "com.jessandjon.app", category: "App")
    
    init() {
        logger.info("App initializing...")
        // Only configure Firebase if GoogleService-Info.plist is valid
        // Check if we have a real project ID (not placeholder)
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let projectId = plist["PROJECT_ID"] as? String,
           projectId != "your-project-id" && !projectId.isEmpty {
            logger.info("Firebase configured with project: \(projectId, privacy: .public)")
            FirebaseApp.configure()
        } else {
            // Firebase not configured - app will use local storage only
            logger.warning("Firebase not configured - using local storage only")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isAuthValidated {
                    rootView
                } else {
                    // Show loading while validating auth state
                    ZStack {
                        AppTheme.softGradient
                            .ignoresSafeArea()
                        
                        ProgressView()
                            .tint(AppTheme.accentPink)
                    }
                }
            }
            .environmentObject(appState)
            .environmentObject(firebaseService)
            .environmentObject(authService)
            .task {
                // Run this immediately when the view appears (before rendering)
                // Always set validated to true, even if validation fails or hangs
                // This ensures the app doesn't get stuck on loading screen
                do {
                    await validateAndSyncAuthState()
                } catch {
                    logger.error("Auth validation error: \(error.localizedDescription, privacy: .public)")
                }
                // Always proceed to show the app, even if validation failed
                isAuthValidated = true
            }
                .onAppear {
                    logger.info("App view appeared")
                    logger.info("Auth state - isAuthenticated: \(authService.isAuthenticated, privacy: .public)")
                    logger.info("App state - isOnboarded: \(appState.isOnboarded, privacy: .public)")
                    logger.info("Current user - ID: \(appState.currentUser?.id ?? "nil", privacy: .public), Name: \(appState.currentUser?.name ?? "nil", privacy: .public)")
                    logger.info("Current user - Partner ID: \(appState.currentUser?.partnerId ?? "nil", privacy: .public), Partner Code: \(appState.currentUser?.partnerCode ?? "nil", privacy: .public)")
                    logger.info("Partner - ID: \(appState.partner?.id ?? "nil", privacy: .public), Name: \(appState.partner?.name ?? "nil", privacy: .public)")
                    
                    // Set up real-time listener for partner content (instant updates)
                    if authService.isAuthenticated {
                        firebaseService.setupContentListener()
                        // Also refresh once to ensure widget is updated on launch
                        firebaseService.refreshPartnerContent()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    logger.info("App entering foreground - syncing data")
                    
                    // Sync user and partner data when app comes to foreground
                    if authService.isAuthenticated {
                        Task {
                            do {
                                let (user, partner) = try await firebaseService.syncUserAndPartner()
                                await MainActor.run {
                                    if let user = user {
                                        appState.saveUser(user)
                                    }
                                    // Explicitly set partner - if nil, clear it; if exists, save it
                                    if let partner = partner {
                                        appState.savePartner(partner)
                                    } else {
                                        appState.clearPartner()
                                    }
                                }
                            } catch {
                                logger.error("Failed to sync user/partner: \(error.localizedDescription, privacy: .public)")
                            }
                        }
                    }
                    
                    // Set up real-time listener for partner content (instant updates)
                    if authService.isAuthenticated {
                        firebaseService.setupContentListener()
                        // Also refresh once to ensure widget is updated when app comes to foreground
                        firebaseService.refreshPartnerContent()
                    }
                }
        }
    }
    
    // MARK: - Auth State Validation
    
    @MainActor
    private func validateAndSyncAuthState() async {
        logger.info("Validating auth state...")
        
        // Check if Firebase Auth user matches local user data
        // If not, it might be a fresh install or different device - sign out
        if authService.isAuthenticated,
           let firebaseUser = authService.currentUser {
            if let localUser = appState.currentUser {
                // Local user exists - check if it matches Firebase user
                if localUser.id != firebaseUser.uid {
                    logger.warning("Firebase user doesn't match local user - signing out")
                    try? authService.signOut()
                    appState.signOut()
                    firebaseService.clearAllContent()
                    return
                }
            } else {
                // Firebase user exists but no local user - might be fresh install (e.g., drag-drop to new simulator)
                // Try to sync from Firestore first
                logger.info("Firebase user exists but no local user - syncing from Firestore")
                do {
                    let (user, partner) = try await firebaseService.syncUserAndPartner()
                    if let user = user {
                        // User exists in Firestore - this is a real user, just missing local data
                        logger.info("User found in Firestore - restoring local data")
                        appState.saveUser(user)
                        // Explicitly set partner - if nil, clear it; if exists, save it
                        if let partner = partner {
                            appState.savePartner(partner)
                        } else {
                            appState.clearPartner()
                        }
                        // Restore onboarding status if user has a name
                        if !user.name.isEmpty {
                            appState.isOnboarded = true
                            UserDefaults.standard.set(true, forKey: "isOnboarded")
                        }
                    } else {
                        // No user in Firestore - this is likely a fresh install with stale Keychain
                        // Sign out to force fresh login
                        logger.info("No user in Firestore - treating as fresh install (stale Keychain)")
                        try? authService.signOut()
                        appState.signOut()
                        firebaseService.clearAllContent()
                    }
                } catch {
                    logger.error("Failed to sync user/partner: \(error.localizedDescription, privacy: .public)")
                    // If sync fails and no local user, sign out (fresh install)
                    logger.info("Sync failed and no local user - signing out")
                    try? authService.signOut()
                    appState.signOut()
                    firebaseService.clearAllContent()
                }
            }
            
            // Sync user and partner data from Firestore (if authenticated and user matches)
            if authService.isAuthenticated, appState.currentUser != nil {
                do {
                    let (user, partner) = try await firebaseService.syncUserAndPartner()
                    if let user = user {
                        appState.saveUser(user)
                    }
                    // Explicitly set partner - if nil, clear it; if exists, save it
                    if let partner = partner {
                        appState.savePartner(partner)
                    } else {
                        appState.clearPartner()
                    }
                } catch {
                    logger.error("Failed to sync user/partner: \(error.localizedDescription, privacy: .public)")
                    // If sync fails, it might mean the Firebase user exists but no corresponding Firestore user
                    // Or local data is corrupted. Treat as fresh install.
                    try? authService.signOut()
                    firebaseService.clearAllContent()
                    logger.info("Sync failed, signed out to force fresh login.")
                }
            }
        } else if appState.currentUser != nil {
            // If not authenticated by Firebase but we have a local user, clear local data
            // This can happen if Firebase Auth token expires or is revoked
            logger.warning("Not authenticated by Firebase but local user exists. Clearing local data.")
            appState.signOut()
            firebaseService.clearAllContent()
        }
    }
    
    // MARK: - Root View
    @ViewBuilder
    private var rootView: some View {
        // Use id modifier to force view refresh when auth/onboarding state changes
        Group {
            if authService.isAuthenticated {
                if appState.isOnboarded {
                    ContentView()
                        .environmentObject(appState)
                        .environmentObject(firebaseService)
                        .environmentObject(authService)
                        .onAppear {
                            logger.info("Showing ContentView")
                        }
                } else {
                    OnboardingView()
                        .environmentObject(appState)
                        .environmentObject(firebaseService)
                        .environmentObject(authService)
                        .onAppear {
                            logger.info("Showing OnboardingView")
                        }
                }
            } else {
                LoginView()
                    .environmentObject(authService)
                    .environmentObject(appState)
                    .environmentObject(firebaseService)
            }
        }
        .id("\(authService.isAuthenticated)-\(appState.isOnboarded)") // Force refresh on state change
    }
}
