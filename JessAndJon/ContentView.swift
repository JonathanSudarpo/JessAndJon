import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var firebaseService: FirebaseService
    @State private var selectedTab = 0
    @State private var showPartnerWidget = false
    @State private var showProfile = false
    
    // Timer for periodic refresh (every 10 seconds)
    let refreshTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    // Timer for periodic user/partner sync (every 15 seconds) - for anniversary date, etc.
    let syncTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Background gradient
            AppTheme.softGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with partner widget preview
                headerView
                
                // Main content
                TabView(selection: $selectedTab) {
                    PhotoView()
                        .tag(0)
                    
                    NotesView()
                        .tag(1)
                    
                    StatusView()
                        .tag(2)
                    
                    MemoriesView()
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Custom tab bar
                customTabBar
            }
        }
        .sheet(isPresented: $showPartnerWidget) {
            PartnerWidgetView()
                .environmentObject(firebaseService)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
                .environmentObject(appState)
                .environmentObject(firebaseService)
        }
        .onAppear {
            // Set up real-time listener for instant updates
            firebaseService.setupContentListener()
        }
        .onChange(of: selectedTab) { _, newTab in
            // Refresh when switching tabs (listener handles real-time, but refresh ensures we have latest)
            firebaseService.refreshPartnerContent()
            
            // Sync user/partner data when switching to Memories tab (for anniversary date)
            if newTab == 3 { // Memories tab
                Task {
                    do {
                        let (user, partner) = try await firebaseService.syncUserAndPartner()
                        await MainActor.run {
                            if let user = user {
                                appState.saveUser(user)
                            }
                            if let partner = partner {
                                appState.savePartner(partner)
                            }
                        }
                    } catch {
                        // Silently fail - sync is best effort
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Re-setup listener when app comes to foreground
            firebaseService.setupContentListener()
        }
        .onReceive(refreshTimer) { _ in
            // Periodic refresh as backup (real-time listener should handle most updates)
            firebaseService.refreshPartnerContent()
        }
        .onReceive(syncTimer) { _ in
            // Periodic sync of user and partner data (for anniversary date, profile changes, etc.)
            Task {
                do {
                    let (user, partner) = try await firebaseService.syncUserAndPartner()
                    await MainActor.run {
                        if let user = user {
                            appState.saveUser(user)
                        }
                        if let partner = partner {
                            appState.savePartner(partner)
                        }
                    }
                } catch {
                    // Silently fail - periodic sync is best effort
                }
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lovance")
                        .font(.appTitle)
                        .foregroundStyle(AppTheme.mainGradient)
                    
                    HStack(spacing: 8) {
                        if let latest = firebaseService.partnerContent {
                            Text("\(latest.senderName) • \(latest.timestamp.timeAgo)")
                                .font(.appCaption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        
                        if let user = appState.currentUser, let anniversary = user.anniversaryDate {
                            Text("•")
                                .font(.appCaption)
                                .foregroundColor(AppTheme.textSecondary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.accentPink)
                                Text("\(Date().daysSince(anniversary))")
                                    .font(.appCaption)
                                    .foregroundColor(AppTheme.accentPink)
                            }
                        }
                        
                        // Streak display
                        let streak = firebaseService.getStreak()
                        if streak.currentStreak > 0 {
                            Text("•")
                                .font(.appCaption)
                                .foregroundColor(AppTheme.textSecondary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.heartRed)
                                
                                Text("\(streak.currentStreak)")
                                    .font(.appCaption)
                                    .foregroundColor(AppTheme.heartRed)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Profile button
                Button(action: { showProfile = true }) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.cardGradient)
                            .frame(width: 50, height: 50)
                            .shadow(color: AppTheme.accentPink.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        if let latest = firebaseService.partnerContent {
                            // Show status emoji if available, otherwise show heart symbol
                            if let emoji = latest.statusEmoji {
                                Text(emoji)
                                    .font(.system(size: 24))
                            } else {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(AppTheme.mainGradient)
                            }
                        } else {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(AppTheme.mainGradient)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Mini widget preview
            if let latest = firebaseService.partnerContent {
                miniWidgetPreview(content: latest)
                    .onTapGesture { showPartnerWidget = true }
            }
        }
    }
    
    // MARK: - Mini Widget Preview
    private func miniWidgetPreview(content: SharedContent) -> some View {
        HStack(spacing: 12) {
            // Content preview
            Group {
                switch content.contentType {
                case .photo:
                    if let imageData = content.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppTheme.softGradient)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(AppTheme.accentPink)
                            )
                    }
                case .note:
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.lavender.opacity(0.5))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "note.text")
                                .foregroundColor(AppTheme.accentPurple)
                        )
                case .drawing:
                    if let drawingData = content.drawingData, let uiImage = UIImage(data: drawingData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppTheme.lavender.opacity(0.5))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "pencil.tip")
                                    .foregroundColor(AppTheme.accentPurple)
                            )
                    }
                case .status:
                    if let emoji = content.statusEmoji {
                        Text(emoji)
                            .font(.system(size: 32))
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.accentPink)
                            .frame(width: 44, height: 44)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("From \(content.senderName)")
                    .font(.appCaption)
                    .foregroundColor(AppTheme.textSecondary)
                
                Group {
                    switch content.contentType {
                    case .photo:
                        Text(content.caption ?? "Sent a photo 📸")
                    case .note:
                        Text(content.noteText ?? "Sent a note")
                    case .drawing:
                        Text("Sent a drawing ✏️")
                    case .status:
                        Text(content.statusText ?? "")
                    }
                }
                .font(.appBody)
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: AppTheme.accentPink.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Custom Tab Bar
    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabBarItem(icon: "camera.fill", title: "Photo", tag: 0)
            tabBarItem(icon: "pencil.and.scribble", title: "Notes", tag: 1)
            tabBarItem(icon: "heart.text.square.fill", title: "Status", tag: 2)
            tabBarItem(icon: "memories", title: "Memories", tag: 3)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .background(
            Rectangle()
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    private func tabBarItem(icon: String, title: String, tag: Int) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                selectedTab = tag
            }
        }) {
            VStack(spacing: 4) {
                ZStack {
                    if selectedTab == tag {
                        Capsule()
                            .fill(AppTheme.mainGradient)
                            .frame(width: 60, height: 32)
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(selectedTab == tag ? .white : AppTheme.textSecondary)
                }
                .frame(height: 32)
                
                Text(title)
                    .font(.system(size: 11, weight: selectedTab == tag ? .semibold : .regular))
                    .foregroundColor(selectedTab == tag ? AppTheme.accentPurple : AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(FirebaseService.shared)
}
