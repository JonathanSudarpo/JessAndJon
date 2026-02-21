import SwiftUI
import OSLog

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var firebaseService: FirebaseService
    @StateObject private var authService = AuthService.shared
    
    private let logger = Logger(subsystem: "com.jessandjon.app", category: "OnboardingView")
    
    @State private var currentPage = 0
    @State private var userName = ""
    @State private var partnerCode = ""
    @State private var showCodeEntry = false
    @State private var generatedCode = ""
    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var skipAuth = false
    
    // Animation states
    @State private var heartScale = 1.0
    @State private var heartsVisible = false
    
    var body: some View {
        ZStack {
            // Animated background
            backgroundGradient
            
            // Floating hearts
            floatingHearts
            
            VStack {
                // Back button (show on all pages except welcome)
                if currentPage > 0 {
                    HStack {
                        Button(action: goBack) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Back")
                                    .font(.appBody)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.2))
                            )
                        }
                        .padding(.leading, 20)
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                }
                
                if currentPage == 0 {
                    welcomePage
                } else if currentPage == 1 {
                    // Only show login page if not already authenticated
                    if authService.isAuthenticated {
                        // Check if user already has a name - if so, skip to connect
                        let hasName = (appState.currentUser?.name.isEmpty == false) || 
                                     (authService.currentUser?.displayName?.isEmpty == false)
                        if hasName {
                            connectPage
                        } else {
                    namePage
                        }
                    } else {
                        loginPage
                    }
                } else if currentPage == 2 {
                    // Only show name page if user doesn't have a name
                    let hasName = (appState.currentUser?.name.isEmpty == false) || 
                                 (authService.currentUser?.displayName?.isEmpty == false)
                    if hasName {
                        // User has a name, skip to connect page
                        connectPage
                    } else {
                        namePage
                    }
                } else if currentPage == 3 {
                    connectPage
                }
            }
            .padding()
        }
        .alert("Connection Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Immediately check and set the correct page on appear
            if authService.isAuthenticated {
                let hasName = (appState.currentUser?.name.isEmpty == false) || 
                             (authService.currentUser?.displayName?.isEmpty == false)
                
                if hasName {
                    // User has a name - ensure they exist in Firestore and show connect page
                    if appState.currentUser?.partnerCode == nil {
                        // Need to create user in Firestore first
                        Task {
                            await ensureUserCreatedInFirestore()
                        }
                    } else {
                        // User exists in Firestore - go straight to connect page
                        currentPage = 3
                    }
                } else {
                    // No name - go to name page
                    currentPage = 2
                }
            }
        }
        .onChange(of: appState.currentUser?.name) { _, _ in
            // React to changes in user name (e.g., after handleAuthSuccess completes)
            checkAndUpdatePage()
        }
        .onChange(of: authService.currentUser?.displayName) { _, _ in
            // React to changes in Firebase Auth displayName
            checkAndUpdatePage()
        }
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.gradientStart.opacity(0.6),
                    AppTheme.gradientMid.opacity(0.4),
                    AppTheme.gradientEnd.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle pattern overlay
            GeometryReader { geo in
                ForEach(0..<20) { i in
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: CGFloat.random(in: 20...100))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                        .blur(radius: 10)
                }
            }
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Floating Hearts
    private var floatingHearts: some View {
        GeometryReader { geo in
            ForEach(0..<8) { index in
                FloatingHeart(delay: Double(index) * 0.3)
                    .position(
                        x: CGFloat.random(in: 50...(geo.size.width - 50)),
                        y: geo.size.height + 50
                    )
            }
        }
        .opacity(heartsVisible ? 1 : 0)
        .onAppear {
            withAnimation(.easeIn(duration: 1).delay(0.5)) {
                heartsVisible = true
            }
        }
    }
    
    // MARK: - Welcome Page
    private var welcomePage: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Animated heart logo
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.heartPink.opacity(0.4), Color.clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .scaleEffect(heartScale)
                
                // Heart icon
                Image(systemName: "heart.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.heartPink, AppTheme.heartRed],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(heartScale)
                    .shadow(color: AppTheme.heartRed.opacity(0.5), radius: 20, x: 0, y: 10)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    heartScale = 1.1
                }
            }
            
            VStack(spacing: 16) {
                Text("Lovance")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: AppTheme.accentPurple.opacity(0.5), radius: 10, x: 0, y: 5)
                
                Text("Stay connected with\nthe one you love 💕")
                    .font(.appSubheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.5)) {
                    // If already authenticated, skip login page
                    if authService.isAuthenticated {
                        currentPage = 2 // Go straight to name page
                    } else {
                        currentPage = 1 // Go to login page
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Text("Get Started")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            
            // Skip login option (for testing/development)
            Button(action: {
                skipAuth = true
                withAnimation(.spring(response: 0.5)) {
                    currentPage = 2 // Skip to name page
                }
            }) {
                Text("Continue without account")
                    .font(.appCaption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 8)
            
            Spacer()
                .frame(height: 40)
        }
    }
    
    // MARK: - Login Page
    private var loginPage: some View {
        LoginView()
            .environmentObject(authService)
            .environmentObject(appState)
            .environmentObject(firebaseService)
    }
    
    // MARK: - Name Page
    private var namePage: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 8) {
                Text("What's your name?")
                    .font(.appTitle)
                    .foregroundColor(.white)
                
                Text("So your partner knows it's you 💝")
                    .font(.appBody)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Name input
            VStack(spacing: 8) {
                TextField("Enter your name", text: $userName)
                    .font(.appHeadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppTheme.textPrimary) // Explicit text color for dark mode
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: AppTheme.accentPink.opacity(0.3), radius: 15, x: 0, y: 5)
                    )
                    .padding(.horizontal, 40)
                    .submitLabel(.done)
            }
            .onAppear {
                // Pre-populate name from Firebase Auth displayName if available and userName is empty
                if userName.isEmpty, let displayName = authService.currentUser?.displayName, !displayName.isEmpty {
                    userName = displayName
                }
                // Also check appState
                if userName.isEmpty, let appUserName = appState.currentUser?.name, !appUserName.isEmpty {
                    userName = appUserName
                }
            }
            
            Spacer()
                
                Button(action: {
                    Task {
                        await createUserAndContinue()
                    }
                }) {
                    HStack(spacing: 8) {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(userName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(userName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
            
            Spacer()
                .frame(height: 40)
        }
    }
    
    // MARK: - Connect Page
    private var connectPage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 8) {
                Text("Connect with your\npartner 💑")
                    .font(.appTitle)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            
            if !showCodeEntry {
                // Show generated code
                VStack(spacing: 16) {
                    Text("Share this code with your partner:")
                        .font(.appBody)
                        .foregroundColor(.white.opacity(0.9))
                    
                    // Code display
                    HStack(spacing: 8) {
                        ForEach(Array(generatedCode), id: \.self) { char in
                            Text(String(char))
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundColor(AppTheme.accentPurple)
                                .frame(width: 44, height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .shadow(color: AppTheme.accentPink.opacity(0.2), radius: 8, x: 0, y: 4)
                                )
                        }
                    }
                    
                    Button(action: {
                        UIPasteboard.general.string = generatedCode
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Code")
                        }
                        .font(.appCaption)
                        .foregroundColor(AppTheme.accentPurple)
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.95))
                        .shadow(color: AppTheme.accentPink.opacity(0.2), radius: 20, x: 0, y: 10)
                )
                
                Text("or")
                    .font(.appBody)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.vertical, 8)
                
                Button(action: {
                    withAnimation(.spring()) {
                        showCodeEntry = true
                    }
                }) {
                    Text("I have a code from my partner")
                }
                .buttonStyle(SecondaryButtonStyle())
                
            } else {
                // Enter partner's code
                VStack(spacing: 16) {
                    Text("Enter your partner's code:")
                        .font(.appBody)
                        .foregroundColor(.white.opacity(0.9))
                    
                    TextField("XXXXXX", text: $partnerCode)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textCase(.uppercase)
                        .foregroundColor(AppTheme.textPrimary) // Explicit text color for dark mode
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: AppTheme.accentPink.opacity(0.3), radius: 15, x: 0, y: 5)
                        )
                        .padding(.horizontal, 40)
                        .submitLabel(.done)
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            showCodeEntry = false
                        }
                    }) {
                        Text("← Share my code instead")
                            .font(.appCaption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.15))
                )
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                if showCodeEntry && partnerCode.count == 6 {
                    Button(action: {
                        Task {
                            await connectWithPartner()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isConnecting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Connect")
                                Image(systemName: "heart.fill")
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isConnecting)
                }
                
                Button(action: {
                    // Skip for now - can connect later
                    // Don't generate mock data - wait for real partner connection
                    appState.completeOnboarding()
                }) {
                    Text("Skip for now")
                        .font(.appCaption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
                .frame(height: 40)
        }
    }
    
    // MARK: - Actions
    
    private func checkAndUpdatePage() {
        // If user is already authenticated, skip login page and welcome page
        if authService.isAuthenticated {
            // Check if user already has a name set (partially onboarded)
            // First check appState, then check Firebase Auth displayName
            let hasName = (appState.currentUser?.name.isEmpty == false) || 
                         (authService.currentUser?.displayName?.isEmpty == false)
            
            if hasName {
                // User has a name - ensure they exist in Firestore (for partner code)
                // If they don't exist in Firestore yet, create them
                if appState.currentUser?.partnerCode == nil {
                    // User doesn't have a partner code yet - need to create in Firestore
                    Task {
                        await ensureUserCreatedInFirestore()
                    }
                } else {
                    // User exists in Firestore and has a partner code - go to connect page
                    if currentPage != 3 {
                        withAnimation {
                            currentPage = 3
                        }
                    }
                }
            } else {
                // Pre-populate name from Firebase Auth if available
                if let displayName = authService.currentUser?.displayName, !displayName.isEmpty {
                    userName = displayName
                }
                // Also check appState
                if userName.isEmpty, let appUserName = appState.currentUser?.name, !appUserName.isEmpty {
                    userName = appUserName
                }
                // No name yet, go to name page (but don't go back if already past it)
                if currentPage < 2 {
                    withAnimation {
                        currentPage = 2
                    }
                }
            }
        }
    }
    
    private func ensureUserCreatedInFirestore() async {
        // Get the name from displayName or appState
        let nameToUse: String = {
            if let displayName = authService.currentUser?.displayName, !displayName.isEmpty {
                return displayName
            } else if let appUserName = appState.currentUser?.name, !appUserName.isEmpty {
                return appUserName
            } else {
                return "User"
            }
        }()
        
        do {
            // Create user in Firestore (this will generate partner code)
            let user = try await firebaseService.createUser(name: nameToUse)
            await MainActor.run {
                appState.saveUser(user)
                generatedCode = user.partnerCode
                // Now go to connect page
                withAnimation {
                    currentPage = 3
                }
            }
        } catch {
            logger.error("Error creating user in Firestore: \(error.localizedDescription, privacy: .public)")
            // On error, still show connect page (user might already exist)
            await MainActor.run {
                if currentPage != 3 {
                    withAnimation {
                        currentPage = 3
                    }
                }
            }
        }
    }
    
    private func goBack() {
        if currentPage == 1 {
            // If on login page, sign out to go back to LoginView
            Task {
                do {
                    try authService.signOut()
                    appState.signOut()
                    firebaseService.clearAllContent()
                    // Root view will automatically show LoginView after sign out
                } catch {
                    logger.error("Error signing out: \(error.localizedDescription, privacy: .public)")
                    // If sign out fails, just go back to welcome page
                    await MainActor.run {
                        withAnimation {
                            currentPage = 0
                        }
                    }
                }
            }
        } else {
            // Otherwise, just go back one page
            withAnimation {
                currentPage = max(0, currentPage - 1)
            }
        }
    }
    
    private func createUserAndContinue() async {
        do {
            // If name is empty but we have displayName from Firebase Auth, use that
            let nameToUse = userName.trimmingCharacters(in: .whitespaces).isEmpty 
                ? (authService.currentUser?.displayName ?? "") 
                : userName.trimmingCharacters(in: .whitespaces)
            
            // Validation is handled in createUser, but trim whitespace first
            let user = try await firebaseService.createUser(name: nameToUse)
            appState.saveUser(user)
            generatedCode = user.partnerCode
            
            withAnimation(.spring(response: 0.5)) {
                currentPage = 3 // Go to connect page
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func connectWithPartner() async {
        guard let currentUser = appState.currentUser else { return }
        
        isConnecting = true
        defer { isConnecting = false }
        
        do {
            let codeToConnect = partnerCode.uppercased().trimmingCharacters(in: .whitespaces)
            
            if let partner = try await firebaseService.connectWithPartner(code: codeToConnect, currentUser: currentUser) {
                // Sync user and partner from Firestore to get updated state
                let (updatedUser, syncedPartner) = try await firebaseService.syncUserAndPartner()
                
                // Update app state with synced data
                await MainActor.run {
                    // Save partner to app state (which persists it)
                    if let syncedPartner = syncedPartner {
                        appState.savePartner(syncedPartner)
                    } else {
                        appState.savePartner(partner) // Fallback to the partner we just connected
                    }
                
                    // Update current user with partner ID
                    if let updatedUser = updatedUser {
                        appState.saveUser(updatedUser)
                    } else {
                        // Fallback: manually update
                        var userCopy = currentUser
                        userCopy.partnerId = partner.id
                        appState.saveUser(userCopy)
                    }
                    
                    // Refresh partner content to ensure widget updates
                    firebaseService.refreshPartnerContent()
                }
                
                // Complete onboarding
                withAnimation(.spring()) {
                    appState.completeOnboarding()
                }
            } else {
                errorMessage = "Couldn't find a partner with that code. Please check and try again."
                showError = true
            }
        } catch {
            // Provide user-friendly error messages
            if let nsError = error as NSError? {
                switch nsError.code {
                case -3:
                    errorMessage = "You already have a partner connected. Please disconnect your current partner first in your profile settings."
                case -4:
                    errorMessage = "This user is already connected to another partner."
                default:
                    errorMessage = error.localizedDescription
                }
            } else {
            errorMessage = error.localizedDescription
            }
            showError = true
        }
    }
}

// MARK: - Floating Heart Component
struct FloatingHeart: View {
    let delay: Double
    @State private var offsetY: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 1
    
    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: CGFloat.random(in: 16...32)))
            .foregroundColor(AppTheme.heartPink.opacity(0.6))
            .offset(y: offsetY)
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    .easeOut(duration: Double.random(in: 4...7))
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    offsetY = -800
                    opacity = 0
                    scale = 0.5
                }
            }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .environmentObject(FirebaseService.shared)
}
