import SwiftUI
import PhotosUI
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var firebaseService: FirebaseService
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var editedName: String = ""
    @State private var showNameEditor = false
    @State private var showPartnerWidget = false
    @State private var showImagePicker = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var showSignOutAlert = false
    @State private var showDisconnectAlert = false
    @State private var isDisconnecting = false
    @State private var validationError: String? = nil
    @State private var showValidationError = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeader
                    
                    // Profile Picture Section
                    profilePictureSection
                    
                    // User Info Section
                    userInfoSection
                    
                    // Partner Section
                    if appState.partner != nil {
                        partnerSection
                    }
                    
                    // Settings Section
                    settingsSection
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(AppTheme.backgroundPrimary)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentPurple)
                }
            }
            .sheet(isPresented: $showPartnerWidget) {
                PartnerWidgetView()
                    .environmentObject(firebaseService)
            }
            .sheet(isPresented: $showNameEditor) {
                nameEditorSheet
            }
            .alert("Validation Error", isPresented: $showValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationError ?? "Invalid input")
            }
            .photosPicker(isPresented: $showImagePicker, selection: $selectedItem, matching: .images)
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    guard let newItem = newItem else { return }
                    
                    do {
                        guard let data = try? await newItem.loadTransferable(type: Data.self),
                              let uiImage = UIImage(data: data) else {
                            await MainActor.run {
                                validationError = "Failed to load image"
                                showValidationError = true
                            }
                            return
                        }
                        
                        // Show image immediately
                        await MainActor.run {
                            profileImage = uiImage
                        }
                        
                        // Save profile image to Firebase Storage (use profile path)
                        let imageUrl = try await firebaseService.uploadImage(uiImage, isProfileImage: true)
                        
                        // Update user profile in Firestore with image URL
                        guard var user = appState.currentUser else {
                            await MainActor.run {
                                validationError = "User not found"
                                showValidationError = true
                            }
                            return
                        }
                        
                        user.profileImageUrl = imageUrl
                        appState.saveUser(user)
                        
                        // Also update in Firestore so it syncs
                        try await firebaseService.updateUser(user)
                        
                        // Sync to ensure partner sees the update
                        try await firebaseService.syncUserAndPartner()
                        
                        await MainActor.run {
                            // Refresh user data to ensure profile image URL is loaded
                            if let updatedUser = appState.currentUser {
                                appState.saveUser(updatedUser)
                            }
                        }
                    } catch {
                        await MainActor.run {
                            validationError = "Error uploading profile image: \(error.localizedDescription)"
                            showValidationError = true
                            // Revert image on error
                            profileImage = nil
                        }
                    }
                }
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    // Sign out from Firebase Auth first
                    do {
                        try authService.signOut()
                    } catch {
                        // Log error but continue with local sign out
                        print("Error signing out from Firebase: \(error.localizedDescription)")
                    }
                    // Clear app state and content
                    appState.signOut()
                    firebaseService.clearAllContent()
                    dismiss()
                }
                   } message: {
                       Text("Are you sure you want to sign out? You'll need to log back in to continue.")
                   }
                   .alert("Disconnect Partner", isPresented: $showDisconnectAlert) {
                       Button("Cancel", role: .cancel) { }
                       Button("Disconnect", role: .destructive) {
                           disconnectPartner()
                       }
                   } message: {
                       Text("Are you sure you want to disconnect from \(appState.partner?.name ?? "your partner")? You'll need to connect again to share content.")
                   }
            .onAppear {
                if let user = appState.currentUser {
                    editedName = user.name
                    
                    // Load profile image if URL exists
                    if let profileImageUrl = user.profileImageUrl {
                        loadProfileImage(from: profileImageUrl)
                    }
                }
                
                // Sync user and partner data from Firestore
                Task {
                    do {
                        let (user, partner) = try await firebaseService.syncUserAndPartner()
                        await MainActor.run {
                            if let user = user {
                                appState.saveUser(user)
                                // Load profile image if URL exists
                                if let profileImageUrl = user.profileImageUrl {
                                    loadProfileImage(from: profileImageUrl)
                                }
                            }
                            if let partner = partner {
                                appState.savePartner(partner)
                            }
                        }
                    } catch {
                        print("Failed to sync user/partner: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 12) {
            Text("Your Profile")
                .font(.appHeadline)
                .foregroundColor(AppTheme.textPrimary)
            
            Text("Manage your account and settings")
                .font(.appCaption)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
    
    // MARK: - Profile Picture Section
    private var profilePictureSection: some View {
        VStack(spacing: 16) {
            ZStack {
                if let image = profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(AppTheme.mainGradient)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Text(appState.currentUser?.name.prefix(1).uppercased() ?? "?")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        )
                }
                
                // Edit button overlay
                Button(action: { showImagePicker = true }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 36, height: 36)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.accentPurple)
                    }
                }
                .offset(x: 40, y: 40)
            }
            
            Button(action: { showImagePicker = true }) {
                Text("Change Photo")
                    .font(.appCaption)
                    .foregroundColor(AppTheme.accentPurple)
            }
        }
    }
    
    // MARK: - Debug Section (for testing)
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug Info")
                .font(.appHeadline)
                .foregroundColor(AppTheme.textPrimary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Your ID: \(appState.currentUser?.id ?? "none")")
                    .font(.system(size: 12, design: .monospaced))
                Text("Your Partner Code: \(appState.currentUser?.partnerCode ?? "none")")
                    .font(.system(size: 12, design: .monospaced))
                Text("Your Partner ID: \(appState.currentUser?.partnerId ?? "none")")
                    .font(.system(size: 12, design: .monospaced))
                Text("Partner Name: \(appState.partner?.name ?? "none")")
                    .font(.system(size: 12, design: .monospaced))
                Text("Partner ID: \(appState.partner?.id ?? "none")")
                    .font(.system(size: 12, design: .monospaced))
            }
            .font(.appCaption)
            .foregroundColor(AppTheme.textSecondary)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
        }
    }
    
    // MARK: - User Info Section
    private var userInfoSection: some View {
        VStack(spacing: 16) {
            // Name
            profileRow(
                icon: "person.fill",
                title: "Name",
                value: appState.currentUser?.name ?? "Unknown",
                color: AppTheme.accentPink
            ) {
                showNameEditor = true
            }
            
            // Partner Code
            if let user = appState.currentUser {
                profileRow(
                    icon: "key.fill",
                    title: "Your Code",
                    value: user.partnerCode,
                    color: AppTheme.accentPurple
                ) {
                    UIPasteboard.general.string = user.partnerCode
                }
            }
        }
    }
    
    // MARK: - Partner Section
    private var partnerSection: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.vertical, 8)
            
            Button(action: { showPartnerWidget = true }) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.softGradient)
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "heart.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(AppTheme.mainGradient)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("View Partner's Content")
                            .font(.appSubheadline)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text("See all messages from \(appState.partner?.name ?? "your partner")")
                            .font(.appCaption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: AppTheme.accentPink.opacity(0.1), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(.plain)
            
            // Disconnect Partner Button
            Button(action: { showDisconnectAlert = true }) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "heart.slash.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Disconnect Partner")
                            .font(.appSubheadline)
                            .foregroundColor(.red)
                        
                        Text("Remove connection with \(appState.partner?.name ?? "your partner")")
                            .font(.appCaption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.red.opacity(0.1), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(.plain)
            .disabled(isDisconnecting)
        }
    }
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.vertical, 8)
            
            // Sign Out
            Button(action: { showSignOutAlert = true }) {
                HStack {
                    Image(systemName: "arrow.right.square")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.heartRed)
                        .frame(width: 24)
                    
                    Text("Sign Out")
                        .font(.appBody)
                        .foregroundColor(AppTheme.heartRed)
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: AppTheme.heartRed.opacity(0.1), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Profile Row
    private func profileRow(icon: String, title: String, value: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.appCaption)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Text(value)
                        .font(.appSubheadline)
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                Spacer()
                
                if title == "Name" {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)
                } else {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Name Editor Sheet
    private var nameEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Edit Your Name")
                        .font(.appHeadline)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("This is how your partner will see you")
                        .font(.appCaption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.top, 32)
                
                VStack(spacing: 8) {
                    TextField("Your name", text: $editedName)
                        .font(.appHeadline)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: AppTheme.accentPink.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                        .onChange(of: editedName) { _, newValue in
                            // Limit to max length
                            if newValue.count > Validation.maxNameLength {
                                editedName = String(newValue.prefix(Validation.maxNameLength))
                            }
                        }
                    
                    Text("\(editedName.count)/\(Validation.maxNameLength) characters")
                        .font(.appCaption)
                        .foregroundColor(editedName.count > Validation.maxNameLength ? .red : AppTheme.textSecondary)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                Button(action: saveName) {
                    Text("Save")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(editedName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
            .background(AppTheme.backgroundPrimary)
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showNameEditor = false
                        editedName = appState.currentUser?.name ?? ""
                    }
                    .foregroundColor(AppTheme.accentPurple)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadProfileImage(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        profileImage = image
                    }
                }
            } catch {
                print("Failed to load profile image: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Actions
    private func saveName() {
        guard var user = appState.currentUser else { return }
        
        // Validate and sanitize name
        do {
            let validatedName = try Validation.validateName(editedName)
            user.name = validatedName
            appState.saveUser(user)
            
            // Also save to Firestore so it syncs between devices
            Task {
                do {
                    try await firebaseService.updateUser(user)
                } catch {
                    print("Failed to save name to Firestore: \(error.localizedDescription)")
                }
            }
            showNameEditor = false
        } catch {
            // Show error to user
            validationError = error.localizedDescription
            showValidationError = true
        }
    }
    
    private func disconnectPartner() {
        guard let user = appState.currentUser else { return }
        
        isDisconnecting = true
        
        Task {
            do {
                try await firebaseService.disconnectPartner(currentUser: user)
                
                // Update local state
                await MainActor.run {
                    var updatedUser = user
                    updatedUser.partnerId = nil
                    appState.saveUser(updatedUser)
                    appState.partner = nil
                    isDisconnecting = false
                }
            } catch {
                await MainActor.run {
                    isDisconnecting = false
                    print("Failed to disconnect partner: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
        .environmentObject(FirebaseService.shared)
}
