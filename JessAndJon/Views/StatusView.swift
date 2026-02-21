import SwiftUI

struct StatusView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var firebaseService: FirebaseService
    
    @State private var selectedStatus: StatusOption?
    @State private var customStatus = ""
    @State private var customEmoji = "💭"
    @State private var showCustomInput = false
    @State private var showEmojiPicker = false
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var animatingStatusId: UUID?
    @State private var showNoPartnerAlert = false
    @State private var showProfile = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title
                VStack(spacing: 4) {
                    Text("Set Your Status")
                        .font(.appHeadline)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("Let them know how you're feeling")
                        .font(.appCaption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.top, 20)
                
                // Current status preview
                if let status = selectedStatus {
                    currentStatusPreview(status: status)
                }
                
                // Status options grid
                statusGrid
                
                // Custom status option
                customStatusSection
                
                // Send button
                if selectedStatus != nil || !customStatus.isEmpty {
                    sendButton
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
        }
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView(selectedEmoji: $customEmoji)
        }
        .alert("Connect with Partner", isPresented: $showNoPartnerAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Go to Profile") {
                showProfile = true
            }
        } message: {
            Text("You need to connect with a partner before you can update your status. Go to your profile to connect!")
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
                .environmentObject(appState)
                .environmentObject(firebaseService)
        }
    }
    
    // MARK: - Current Status Preview
    private func currentStatusPreview(status: StatusOption) -> some View {
        VStack(spacing: 16) {
            ZStack {
                // Animated background rings
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(status.color.opacity(0.2 - Double(i) * 0.05), lineWidth: 2)
                        .frame(width: CGFloat(140 + i * 30), height: CGFloat(140 + i * 30))
                        .scaleEffect(animatingStatusId == status.id ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                            value: animatingStatusId
                        )
                }
                
                // Main circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [status.color.opacity(0.3), status.color.opacity(0.1)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                
                Text(status.emoji)
                    .font(.system(size: 64))
            }
            
            Text(status.text)
                .font(.appHeadline)
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.vertical, 20)
        .onAppear {
            animatingStatusId = status.id
        }
        .onChange(of: selectedStatus?.id) { _, newValue in
            animatingStatusId = newValue
        }
    }
    
    // MARK: - Status Grid
    private var statusGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(StatusOption.options) { status in
                statusButton(status: status)
            }
        }
    }
    
    private func statusButton(status: StatusOption) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                selectedStatus = status
                customStatus = ""
                showCustomInput = false
            }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(selectedStatus?.id == status.id ? status.color.opacity(0.2) : AppTheme.blush.opacity(0.5))
                        .frame(width: 64, height: 64)
                    
                    if selectedStatus?.id == status.id {
                        Circle()
                            .stroke(status.color, lineWidth: 3)
                            .frame(width: 64, height: 64)
                    }
                    
                    Text(status.emoji)
                        .font(.system(size: 32))
                }
                
                Text(status.text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(selectedStatus?.id == status.id ? status.color : AppTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(
                        color: selectedStatus?.id == status.id ? status.color.opacity(0.3) : AppTheme.accentPink.opacity(0.08),
                        radius: selectedStatus?.id == status.id ? 12 : 6,
                        x: 0,
                        y: selectedStatus?.id == status.id ? 6 : 3
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(selectedStatus?.id == status.id ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: selectedStatus?.id)
    }
    
    // MARK: - Custom Status Section
    private var customStatusSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                withAnimation(.spring()) {
                    showCustomInput.toggle()
                    if showCustomInput {
                        selectedStatus = nil
                    }
                }
            }) {
                HStack {
                    Image(systemName: showCustomInput ? "minus.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 20))
                    Text("Custom status")
                        .font(.appBody)
                }
                .foregroundColor(AppTheme.accentPurple)
            }
            .buttonStyle(.plain)
            
            if showCustomInput {
                HStack(spacing: 12) {
                    // Emoji selector - clickable
                    Button(action: {
                        showEmojiPicker = true
                    }) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.softGradient)
                            .frame(width: 50, height: 50)
                            
                            Text(customEmoji)
                            .font(.system(size: 24))
                        }
                    }
                    .buttonStyle(.plain)
                    
                    VStack(alignment: .leading, spacing: 4) {
                    TextField("What's on your mind?", text: $customStatus)
                        .font(.appBody)
                            .foregroundColor(AppTheme.textPrimary) // Explicit text color for dark mode
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: AppTheme.accentPink.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                            .submitLabel(.done)
                            .onChange(of: customStatus) { _, newValue in
                                // Limit to max length
                                if newValue.count > Validation.maxStatusTextLength {
                                    customStatus = String(newValue.prefix(Validation.maxStatusTextLength))
                                }
                            }
                        
                        Text("\(customStatus.count)/\(Validation.maxStatusTextLength) characters")
                            .font(.system(size: 11))
                            .foregroundColor(customStatus.count > Validation.maxStatusTextLength ? .red : AppTheme.textSecondary)
                            .padding(.leading, 4)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Send Button
    private var sendButton: some View {
        Button(action: sendStatus) {
            HStack(spacing: 8) {
                if isSending {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Update Status")
                    Image(systemName: "sparkles")
                }
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isSending)
        .padding(.top, 8)
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
                    
                    Text(selectedStatus?.emoji ?? customEmoji)
                        .font(.system(size: 44))
                }
                
                VStack(spacing: 8) {
                    Text("Status updated! ✨")
                        .font(.appHeadline)
                        .foregroundColor(.white)
                    
                    Text("\(appState.partner?.name ?? "Your partner") can see your status now")
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showSuccess = false
                }
            }
        }
    }
    
    // MARK: - Actions
    private func sendStatus() {
        // Check if user has a partner
        guard appState.partner != nil else {
            showNoPartnerAlert = true
            return
        }
        
        guard let currentUser = appState.currentUser,
              selectedStatus != nil || !customStatus.isEmpty else { return }
        
        isSending = true
        
        Task {
            do {
                var content = SharedContent(
                    senderId: currentUser.id,
                    senderName: currentUser.name,
                    contentType: .status
                )
                
                if let status = selectedStatus {
                    content.statusEmoji = status.emoji
                    content.statusText = status.text
                } else {
                    content.statusEmoji = customEmoji
                    // Validate and sanitize custom status text
                    content.statusText = Validation.validateStatusText(customStatus)
                }
                
                try await firebaseService.sendContent(content)
                
                // Refresh partner content immediately after sending
                await MainActor.run {
                    firebaseService.refreshPartnerContent()
                    isSending = false
                    showSuccess = true
                    // Clear custom status fields
                    customStatus = ""
                    customEmoji = "💭"
                    selectedStatus = nil
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
    StatusView()
        .environmentObject(AppState())
        .environmentObject(FirebaseService.shared)
}
