import SwiftUI
import OSLog
import FirebaseAuth

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var firebaseService: FirebaseService
    
    private let logger = Logger(subsystem: "com.jessandjon.app", category: "LoginView")
    
    @State private var showEmailLogin = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            VStack(spacing: 24) {
                Spacer()
                
                // Logo
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(AppTheme.mainGradient)
                
                Text("Welcome to Lovance")
                    .font(.appTitle)
                    .foregroundColor(.white)
                
                Text("Sign in to continue")
                    .font(.appBody)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                // Login Options
                VStack(spacing: 16) {
                    // Google Sign-In
                    Button(action: signInWithGoogle) {
                        HStack {
                            Image(systemName: "globe")
                                .font(.system(size: 18))
                            Text("Continue with Google")
                                .font(.appButton)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.2))
                        )
                    }
                    .disabled(isLoading)
                    
                    // Email/Password
                    Button(action: { showEmailLogin = true }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 18))
                            Text("Continue with Email")
                                .font(.appButton)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.2))
                        )
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                    .frame(height: 40)
            }
        }
        .sheet(isPresented: $showEmailLogin) {
            emailLoginSheet
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            logger.info("LoginView appeared")
            logger.info("AuthService.isAuthenticated: \(authService.isAuthenticated, privacy: .public)")
            logger.info("AuthService.currentUser: \(authService.currentUser?.uid ?? "nil", privacy: .public)")
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.gradientStart.opacity(0.8),
                    AppTheme.gradientMid.opacity(0.6),
                    AppTheme.gradientEnd.opacity(0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Email Login Sheet
    private var emailLoginSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(isSignUp ? "Create Account" : "Sign In")
                        .font(.appHeadline)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text(isSignUp ? "Create your Lovance account" : "Sign in to your account")
                        .font(.appCaption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.top, 32)
                
                if isSignUp {
                    TextField("Your Name", text: $name)
                        .textContentType(.name)
                        .autocapitalization(.words)
                        .foregroundColor(AppTheme.textPrimary) // Explicit text color for dark mode
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: AppTheme.accentPink.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                        .submitLabel(.next)
                }
                
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .foregroundColor(AppTheme.textPrimary) // Explicit text color for dark mode
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: AppTheme.accentPink.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .submitLabel(.next)
                
                SecureField("Password", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
                    .foregroundColor(AppTheme.textPrimary) // Explicit text color for dark mode
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: AppTheme.accentPink.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .submitLabel(.done)
                
                Button(action: {
                    Task {
                        await handleEmailAuth()
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(isSignUp ? "Sign Up" : "Sign In")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isLoading || email.isEmpty || password.isEmpty || (isSignUp && name.isEmpty))
                .opacity((isLoading || email.isEmpty || password.isEmpty || (isSignUp && name.isEmpty)) ? 0.6 : 1)
                
                Button(action: {
                    isSignUp.toggle()
                }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.appCaption)
                        .foregroundColor(AppTheme.accentPurple)
                }
                
                Spacer()
            }
            .padding(.horizontal, 40)
            .background(AppTheme.backgroundPrimary)
            .onTapGesture {
                // Dismiss keyboard when tapping outside
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .navigationTitle(isSignUp ? "Sign Up" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showEmailLogin = false
                    }
                    .foregroundColor(AppTheme.accentPurple)
                }
            }
        }
    }
    
    // MARK: - Actions
    private func signInWithGoogle() {
        logger.info("signInWithGoogle button tapped")
        isLoading = true
        Task {
            logger.info("Starting Google Sign-In task")
            do {
                logger.info("Calling authService.signInWithGoogle()")
                try await authService.signInWithGoogle()
                logger.info("Google Sign-In successful, calling handleAuthSuccess()")
                await handleAuthSuccess()
            } catch let error as AuthError {
                logger.error("Caught AuthError: \(error.localizedDescription ?? "unknown", privacy: .public)")
                await MainActor.run {
                    isLoading = false
                    // Only show error if it's not a user cancellation
                    if error != .userCancelled, let errorDescription = error.errorDescription {
                        errorMessage = errorDescription
                        showError = true
                    }
                    // If user cancelled, just silently reset - no error shown
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    // Check if it's a cancellation error
                    let errorDescription = error.localizedDescription.lowercased()
                    if errorDescription.contains("cancel") || errorDescription.contains("cancelled") {
                        // Silently handle cancellation - don't show error
                        return
                    }
                    // Show other errors
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func handleEmailAuth() async {
        logger.info("handleEmailAuth called - isSignUp: \(isSignUp, privacy: .public)")
        isLoading = true
        do {
            if isSignUp {
                logger.info("Calling signUpWithEmail")
                try await authService.signUpWithEmail(email: email, password: password, name: name)
            } else {
                logger.info("Calling signInWithEmail")
                try await authService.signInWithEmail(email: email, password: password)
            }
            logger.info("Email auth successful, calling handleAuthSuccess()")
            await handleAuthSuccess()
        } catch {
            logger.error("Email auth error: \(error.localizedDescription, privacy: .public)")
            await MainActor.run {
                // Provide user-friendly error messages
                let errorDesc = error.localizedDescription.lowercased()
                logger.info("Error description (lowercased): \(errorDesc, privacy: .public)")
                var friendlyMessage: String?
                
                // First, try to get Firebase Auth error code
                if let nsError = error as NSError?,
                   let authErrorCode = AuthErrorCode(_bridgedNSError: nsError) {
                    logger.info("Firebase Auth error code: \(authErrorCode.code.rawValue, privacy: .public)")
                    switch authErrorCode.code {
                    case .userNotFound:
                        friendlyMessage = "No account found with this email. Try signing up instead!"
                    case .wrongPassword:
                        friendlyMessage = "Incorrect password. Please try again."
                    case .invalidEmail:
                        friendlyMessage = "Invalid email address. Please check and try again."
                    case .userDisabled:
                        friendlyMessage = "This account has been disabled. Please contact support."
                    case .networkError:
                        friendlyMessage = "Network error. Please check your connection and try again."
                    case .tooManyRequests:
                        friendlyMessage = "Too many failed attempts. Please try again later."
                    case .invalidCredential:
                        // Invalid credential usually means wrong password when user exists
                        friendlyMessage = "Incorrect password. Please try again."
                    default:
                        logger.info("Unhandled error code: \(authErrorCode.code.rawValue, privacy: .public)")
                        break
                    }
                } else {
                    logger.info("Could not extract AuthErrorCode from error")
                }
                
                // If no friendly message yet, check error description for common patterns
                // Check more specific patterns first
                if friendlyMessage == nil {
                    // Check for "supplied auth credential" errors
                    // This error can mean user doesn't exist OR wrong password
                    // Only show "user not found" if it's specifically a userNotFound error code
                    // Otherwise, it might be a wrong password issue
                    if errorDesc.contains("supplied auth credential") || 
                       (errorDesc.contains("supplied") && errorDesc.contains("credential")) ||
                       (errorDesc.contains("credential") && (errorDesc.contains("malformed") || errorDesc.contains("expired"))) {
                        logger.info("Matched 'supplied auth credential' pattern")
                        // Check if this is actually a wrong password by checking the error code
                        // If it's not userNotFound, it's likely wrong password
                        if let nsError = error as NSError?,
                           let authErrorCode = AuthErrorCode(_bridgedNSError: nsError),
                           authErrorCode.code == .userNotFound {
                            friendlyMessage = "No account found with this email. Try signing up instead!"
                        } else {
                            // Likely wrong password, not user not found
                            friendlyMessage = "Incorrect email or password. Please try again."
                        }
                    } 
                    // Check for user not found errors
                    else if errorDesc.contains("user") && (errorDesc.contains("not found") || errorDesc.contains("does not exist")) {
                        friendlyMessage = "No account found with this email. Try signing up instead!"
                    } 
                    // Check for password errors
                    else if errorDesc.contains("password") || errorDesc.contains("wrong password") || errorDesc.contains("incorrect password") {
                        friendlyMessage = "Incorrect password. Please try again."
                    } 
                    // Check for invalid credential errors
                    else if errorDesc.contains("credential") && errorDesc.contains("invalid") {
                        friendlyMessage = "Invalid email or password. Please try again or sign up if you don't have an account."
                    } 
                    // Check for invalid email
                    else if errorDesc.contains("email") && errorDesc.contains("invalid") {
                        friendlyMessage = "Invalid email address. Please check and try again."
                    } 
                    // Fallback to original error message
                    else {
                        friendlyMessage = error.localizedDescription
                    }
                }
                
                errorMessage = friendlyMessage ?? error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }
    
    private func handleAuthSuccess() async {
        logger.info("handleAuthSuccess called")
        // Create or update user in Firestore
        guard let firebaseUser = authService.currentUser else {
            logger.error("No Firebase user found in authService")
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        logger.info("Firebase user found: \(firebaseUser.uid, privacy: .public)")
        
        // Clear old local data when signing in with a new Firebase user
        // This ensures we don't mix old local data with new Firebase auth
        await MainActor.run {
            // Check if this is a different user than what's stored locally
            if let existingUser = appState.currentUser,
               existingUser.id != firebaseUser.uid {
                logger.info("Different user detected - clearing old local data")
                appState.signOut() // This clears all local data
                firebaseService.clearAllContent() // Clear any mock/sample content
            } else if appState.currentUser == nil {
                // First time signing in - clear any leftover mock data
                logger.info("First sign-in - clearing any existing mock data")
                firebaseService.clearAllContent()
            }
        }
        
        // Sync user from Firestore to get accurate onboarding status
        // This ensures we know if the user has completed onboarding (has a name in Firestore)
        do {
            let (syncedUser, syncedPartner) = try await firebaseService.syncUserAndPartner()
            
            await MainActor.run {
                if let syncedUser = syncedUser {
                    // User exists in Firestore - they've completed onboarding
                    logger.info("User found in Firestore - onboarding completed")
                    appState.saveUser(syncedUser)
                    
                    if let syncedPartner = syncedPartner {
                        appState.savePartner(syncedPartner)
                    }
                    
                    // User has a name in Firestore, so they've completed onboarding
                    appState.isOnboarded = true
                    UserDefaults.standard.set(true, forKey: "isOnboarded")
                } else {
                    // User doesn't exist in Firestore - new user, needs onboarding
                    logger.info("User not found in Firestore - new user, needs onboarding")
                    
                    // Determine the user's name
                    let userName: String = {
                        if let displayName = firebaseUser.displayName, !displayName.isEmpty {
                            return displayName
                        } else if !name.isEmpty {
                            return name
                        } else {
                            return "User"
                        }
                    }()
                    
                    // Create new user locally (will be saved to Firestore during onboarding)
                    let appUser = AppUser(id: firebaseUser.uid, name: userName)
                    appState.saveUser(appUser)
                    
                    // New user - needs onboarding
                    appState.isOnboarded = false
                    UserDefaults.standard.set(false, forKey: "isOnboarded")
                }
            }
        } catch {
            logger.error("Error syncing user from Firestore: \(error.localizedDescription, privacy: .public)")
            // On error, assume new user
            await MainActor.run {
                let userName: String = {
                    if let displayName = firebaseUser.displayName, !displayName.isEmpty {
                        return displayName
                    } else if !name.isEmpty {
                        return name
                    } else {
                        return "User"
                    }
                }()
                
                let appUser = AppUser(id: firebaseUser.uid, name: userName)
                appState.saveUser(appUser)
                appState.isOnboarded = false
                UserDefaults.standard.set(false, forKey: "isOnboarded")
            }
        }
        
        await MainActor.run {
            isLoading = false
            
            // Verify auth state
            logger.info("After handleAuthSuccess:")
            logger.info("  - authService.isAuthenticated: \(authService.isAuthenticated, privacy: .public)")
            logger.info("  - authService.currentUser: \(authService.currentUser?.uid ?? "nil", privacy: .public)")
            logger.info("  - appState.isOnboarded: \(appState.isOnboarded, privacy: .public)")
            logger.info("  - appState.currentUser?.id: \(appState.currentUser?.id ?? "nil", privacy: .public)")
            
            // Force view update by triggering objectWillChange
            authService.objectWillChange.send()
            appState.objectWillChange.send()
            
            // Safety check: Only fix state if we have a valid authenticated Firebase user
            // This function (handleAuthSuccess) is ONLY called after successful sign-in,
            // so if we have a Firebase user here, sign-in definitely succeeded.
            // This fixes a race condition where the auth state listener might not have fired yet.
            if !authService.isAuthenticated && authService.currentUser != nil {
                logger.warning("State sync issue: isAuthenticated is false but Firebase user exists")
                logger.warning("  - Firebase user: \(firebaseUser.uid, privacy: .public)")
                logger.warning("  - This is safe to fix because handleAuthSuccess only runs after successful sign-in")
                authService.isAuthenticated = true
                authService.objectWillChange.send()
            } else if !authService.isAuthenticated && authService.currentUser == nil {
                logger.error("ERROR: Sign-in appeared to succeed but no Firebase user found!")
                logger.error("  - This should not happen - sign-in may have actually failed")
                // Don't set isAuthenticated to true if we don't have a user
                // This ensures we stay on login screen if sign-in actually failed
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService.shared)
        .environmentObject(AppState())
        .environmentObject(FirebaseService.shared)
}
