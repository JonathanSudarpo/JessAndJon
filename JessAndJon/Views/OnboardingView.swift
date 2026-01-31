import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var firebaseService: FirebaseService
    
    @State private var currentPage = 0
    @State private var userName = ""
    @State private var partnerCode = ""
    @State private var showCodeEntry = false
    @State private var generatedCode = ""
    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorMessage = ""
    
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
                if currentPage == 0 {
                    welcomePage
                } else if currentPage == 1 {
                    namePage
                } else if currentPage == 2 {
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
                Text("Jess & Jon")
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
                    currentPage = 1
                }
            }) {
                HStack(spacing: 8) {
                    Text("Get Started")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            
            Spacer()
                .frame(height: 40)
        }
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
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: AppTheme.accentPink.opacity(0.3), radius: 15, x: 0, y: 5)
                    )
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: {
                    withAnimation(.spring(response: 0.5)) {
                        currentPage = 0
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.2))
                        )
                }
                
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
            }
            
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
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: AppTheme.accentPink.opacity(0.3), radius: 15, x: 0, y: 5)
                        )
                        .padding(.horizontal, 40)
                    
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
                    firebaseService.generateMockContent()
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
    
    private func createUserAndContinue() async {
        do {
            let user = try await firebaseService.createUser(name: userName.trimmingCharacters(in: .whitespaces))
            appState.saveUser(user)
            generatedCode = user.partnerCode
            
            withAnimation(.spring(response: 0.5)) {
                currentPage = 2
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
            if let partner = try await firebaseService.connectWithPartner(code: partnerCode.uppercased(), currentUser: currentUser) {
                appState.partner = partner
                
                // Generate some mock content for demo
                firebaseService.generateMockContent()
                
                // Complete onboarding
                withAnimation(.spring()) {
                    appState.completeOnboarding()
                }
            } else {
                errorMessage = "Couldn't find a partner with that code. Please check and try again."
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
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
