import Foundation
import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import OSLog

// MARK: - Authentication Service
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var currentUser: FirebaseAuth.User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private let logger = Logger(subsystem: "com.jessandjon.app", category: "AuthService")
    
    private init() {
        logger.info("AuthService initializing...")
        // Listen for auth state changes
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.logger.info("Auth state changed - user: \(user?.uid ?? "nil", privacy: .public)")
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                self?.logger.info("AuthService.isAuthenticated set to: \(user != nil, privacy: .public)")
                // Force objectWillChange to ensure SwiftUI updates
                self?.objectWillChange.send()
            }
        }
        
        // Check initial auth state
        if let currentUser = Auth.auth().currentUser {
            logger.info("Initial auth state - user found: \(currentUser.uid, privacy: .public)")
            self.currentUser = currentUser
            self.isAuthenticated = true
        } else {
            logger.info("Initial auth state - no user")
            self.isAuthenticated = false
        }
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Google Sign-In
    func signInWithGoogle() async throws {
        // Get CLIENT_ID from GoogleService-Info.plist (iOS client ID)
        // Firebase's default clientID might be the Web client, not iOS
        var clientID: String?
        
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let plistClientID = plist["CLIENT_ID"] as? String {
            clientID = plistClientID
            logger.info("Using CLIENT_ID from GoogleService-Info.plist")
        } else if let firebaseClientID = FirebaseApp.app()?.options.clientID {
            clientID = firebaseClientID
            logger.info("Using CLIENT_ID from Firebase")
        }
        
        guard let clientID = clientID else {
            logger.error("No CLIENT_ID found")
            throw AuthError.configurationError
        }
        
        logger.info("Configuring Google Sign-In")
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = await windowScene.windows.first,
              let rootViewController = await window.rootViewController else {
            throw AuthError.presentationError
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.tokenError
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: result.user.accessToken.tokenString)
            
            let authResult = try await Auth.auth().signIn(with: credential)
            logger.info("Firebase Google sign-in successful: \(authResult.user.uid, privacy: .public)")
            
            await MainActor.run {
                self.currentUser = authResult.user
                self.isAuthenticated = true
                self.logger.info("AuthService updated - isAuthenticated: \(self.isAuthenticated, privacy: .public)")
            }
        } catch {
            // Check if user cancelled the sign-in flow
            let errorDescription = (error as NSError).localizedDescription.lowercased()
            if errorDescription.contains("cancel") || 
               errorDescription.contains("cancelled") ||
               (error as NSError).code == -5 { // User cancelled error code
                throw AuthError.userCancelled
            }
            // Re-throw other errors
            throw error
        }
    }
    
    // MARK: - Email/Password Sign-In
    func signInWithEmail(email: String, password: String) async throws {
        logger.info("signInWithEmail called")
        let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
        logger.info("Firebase sign-in successful: \(authResult.user.uid, privacy: .public)")
        
        await MainActor.run {
            self.currentUser = authResult.user
            self.isAuthenticated = true
            self.logger.info("AuthService updated - isAuthenticated: \(self.isAuthenticated, privacy: .public)")
        }
    }
    
    // MARK: - Email/Password Sign-Up
    func signUpWithEmail(email: String, password: String, name: String) async throws {
        let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        
        // Update user profile with display name
        let changeRequest = authResult.user.createProfileChangeRequest()
        changeRequest.displayName = name
        try await changeRequest.commitChanges()
        
        await MainActor.run {
            self.currentUser = authResult.user
            self.isAuthenticated = true
        }
    }
    
    // MARK: - Sign Out
    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        
        currentUser = nil
        isAuthenticated = false
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError, Equatable {
    case configurationError
    case presentationError
    case tokenError
    case userNotFound
    case invalidCredentials
    case networkError
    case userCancelled
    
    var errorDescription: String? {
        switch self {
        case .configurationError:
            return "Firebase configuration error. Please check your GoogleService-Info.plist"
        case .presentationError:
            return "Unable to present sign-in screen"
        case .tokenError:
            return "Authentication token error"
        case .userNotFound:
            return "User not found"
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network error. Please check your connection"
        case .userCancelled:
            return nil // Don't show error for cancellation
        }
    }
}
