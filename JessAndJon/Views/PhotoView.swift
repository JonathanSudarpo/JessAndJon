import SwiftUI
import PhotosUI

struct PhotoView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var firebaseService: FirebaseService
    
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var caption = ""
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var showNoPartnerAlert = false
    @State private var showProfile = false
    
    // Animation states
    @State private var pulseAnimation = false
    @State private var showConfetti = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title
                VStack(spacing: 4) {
                    Text("Send a Photo")
                        .font(.appHeadline)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("Share a moment with your love")
                        .font(.appCaption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.top, 16)
                
                // Photo preview area
                photoPreviewArea
                
                // Caption input
                if selectedImage != nil {
                    captionInput
                }
                
                // Action buttons
                actionButtons
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120) // Extra padding for tab bar
        }
        .scrollIndicators(.hidden)
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .sheet(isPresented: $showCamera) {
            CustomCameraView(image: $selectedImage)
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = uiImage
                }
            }
        }
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
        .alert("Connect with Partner", isPresented: $showNoPartnerAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Go to Profile") {
                showProfile = true
            }
        } message: {
            Text("You need to connect with a partner before you can send photos. Go to your profile to connect!")
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
                .environmentObject(appState)
                .environmentObject(firebaseService)
        }
    }
    
    // MARK: - Photo Preview Area
    private var photoPreviewArea: some View {
        ZStack {
            if let image = selectedImage {
                // Selected image preview
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(AppTheme.mainGradient, lineWidth: 3)
                    )
                    .shadow(color: AppTheme.accentPink.opacity(0.3), radius: 20, x: 0, y: 10)
                    .overlay(alignment: .topTrailing) {
                        Button(action: { selectedImage = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white, Color.black.opacity(0.5))
                                .padding(12)
                        }
                    }
            } else {
                // Placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(AppTheme.cardGradient)
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .shadow(color: AppTheme.accentPink.opacity(0.15), radius: 15, x: 0, y: 8)
                    
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.softGradient)
                                .frame(width: 100, height: 100)
                                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(AppTheme.mainGradient)
                        }
                        
                        VStack(spacing: 4) {
                            Text("Capture a moment")
                                .font(.appSubheadline)
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text("Take a photo or choose from library")
                                .font(.appCaption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        pulseAnimation = true
                    }
                }
            }
        }
    }
    
    // MARK: - Caption Input
    private var captionInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add a caption")
                .font(.appCaption)
                .foregroundColor(AppTheme.textSecondary)
            
            TextField("Say something sweet...", text: $caption)
                .font(.appBody)
                .foregroundColor(AppTheme.textPrimary) // Explicit text color for dark mode
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: AppTheme.accentPink.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .submitLabel(.done)
                .onChange(of: caption) { _, newValue in
                    // Limit to max length
                    if newValue.count > Validation.maxCaptionLength {
                        caption = String(newValue.prefix(Validation.maxCaptionLength))
                    }
                }
            
            Text("\(caption.count)/\(Validation.maxCaptionLength) characters")
                .font(.system(size: 11))
                .foregroundColor(caption.count > Validation.maxCaptionLength ? .red : AppTheme.textSecondary)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(), value: selectedImage != nil)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 16) {
            if selectedImage == nil {
                // Camera and gallery buttons
                HStack(spacing: 16) {
                    Button(action: {
                        // Check if camera is available (not available in simulator)
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            showCamera = true
                        } else {
                            // Camera not available (simulator) - use photo library instead
                            showImagePicker = true
                        }
                    }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.buttonGradient)
                                    .frame(width: 64, height: 64)
                                    .shadow(color: AppTheme.accentPink.opacity(0.4), radius: 10, x: 0, y: 5)
                                
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                            
                            Text("Camera")
                                .font(.appCaption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { showImagePicker = true }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.cardGradient)
                                    .frame(width: 64, height: 64)
                                    .shadow(color: AppTheme.accentPink.opacity(0.2), radius: 10, x: 0, y: 5)
                                    .overlay(
                                        Circle()
                                            .stroke(AppTheme.mainGradient, lineWidth: 2)
                                    )
                                
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 24))
                                    .foregroundStyle(AppTheme.mainGradient)
                            }
                            
                            Text("Gallery")
                                .font(.appCaption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Send button
                Button(action: sendPhoto) {
                    HStack(spacing: 8) {
                        if isSending {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Send to \(appState.partner?.name ?? "Partner")")
                            Image(systemName: "heart.fill")
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSending)
            }
        }
    }
    
    // MARK: - Success Overlay
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(AppTheme.buttonGradient)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                }
                .scaleEffect(showConfetti ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showConfetti)
                
                VStack(spacing: 8) {
                    Text("Sent with love! 💕")
                        .font(.appHeadline)
                        .foregroundColor(.white)
                    
                    Text("\(appState.partner?.name ?? "Your partner") will see this on their widget")
                        .font(.appBody)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
            )
        }
        .onAppear {
            showConfetti = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showSuccess = false
                    showConfetti = false
                }
            }
        }
    }
    
    // MARK: - Actions
    private func sendPhoto() {
        // Check if user has a partner
        guard appState.partner != nil else {
            showNoPartnerAlert = true
            return
        }
        
        guard let image = selectedImage,
              let currentUser = appState.currentUser else { return }
        
        isSending = true
        
        Task {
            do {
                var content = SharedContent(
                    senderId: currentUser.id,
                    senderName: currentUser.name,
                    contentType: .photo
                )
                content.imageData = image.jpegData(compressionQuality: 0.7)
                // Validate and sanitize caption
                content.caption = Validation.validateCaption(caption)
                
                try await firebaseService.sendContent(content)
                
                // Refresh partner content immediately after sending
                await MainActor.run {
                    firebaseService.refreshPartnerContent()
                    isSending = false
                    showSuccess = true
                    selectedImage = nil
                    caption = ""
                }
            } catch {
                await MainActor.run {
                    isSending = false
                }
            }
        }
    }
}

#Preview {
    PhotoView()
        .environmentObject(AppState())
        .environmentObject(FirebaseService.shared)
}
