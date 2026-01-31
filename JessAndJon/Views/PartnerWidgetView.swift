import SwiftUI

struct PartnerWidgetView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @Environment(\.dismiss) var dismiss
    
    @State private var content: [SharedContent] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AppTheme.softGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Latest content (big preview)
                        if let latest = content.first {
                            latestContentCard(content: latest)
                        }
                        
                        // Recent history
                        if content.count > 1 {
                            recentHistorySection
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("From Your Love")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentPurple)
                }
            }
            .onAppear {
                loadContent()
            }
        }
    }
    
    // MARK: - Latest Content Card
    private func latestContentCard(content: SharedContent) -> some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Latest from")
                        .font(.appCaption)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Text(content.senderName)
                        .font(.appHeadline)
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                Spacer()
                
                Text(content.timestamp.timeAgo)
                    .font(.appCaption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            // Content preview
            contentPreview(content: content, isLarge: true)
            
            // Caption if available
            if let caption = content.caption, !caption.isEmpty {
                Text(caption)
                    .font(.appBody)
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: AppTheme.accentPink.opacity(0.2), radius: 20, x: 0, y: 10)
        )
    }
    
    // MARK: - Content Preview
    private func contentPreview(content: SharedContent, isLarge: Bool) -> some View {
        Group {
            switch content.contentType {
            case .photo:
                photoPreview(content: content, isLarge: isLarge)
            case .note:
                notePreview(content: content, isLarge: isLarge)
            case .drawing:
                drawingPreview(content: content, isLarge: isLarge)
            case .status:
                statusPreview(content: content, isLarge: isLarge)
            }
        }
    }
    
    private func photoPreview(content: SharedContent, isLarge: Bool) -> some View {
        Group {
            if let imageData = content.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: isLarge ? 300 : 100)
                    .clipShape(RoundedRectangle(cornerRadius: isLarge ? 20 : 12))
            } else {
                RoundedRectangle(cornerRadius: isLarge ? 20 : 12)
                    .fill(AppTheme.softGradient)
                    .frame(height: isLarge ? 300 : 100)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: isLarge ? 48 : 24))
                            .foregroundColor(AppTheme.accentPink)
                    )
            }
        }
    }
    
    private func notePreview(content: SharedContent, isLarge: Bool) -> some View {
        VStack(spacing: 12) {
            if isLarge {
                Image(systemName: "quote.opening")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.mainGradient)
            }
            
            Text(content.noteText ?? "")
                .font(isLarge ? .system(size: 22, weight: .medium, design: .serif) : .appBody)
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(isLarge ? nil : 3)
            
            if isLarge {
                Image(systemName: "quote.closing")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.mainGradient)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(isLarge ? 32 : 16)
        .background(
            RoundedRectangle(cornerRadius: isLarge ? 20 : 12)
                .fill(AppTheme.lavender.opacity(0.3))
        )
    }
    
    private func drawingPreview(content: SharedContent, isLarge: Bool) -> some View {
        Group {
            if let drawingData = content.drawingData, let uiImage = UIImage(data: drawingData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: isLarge ? 300 : 100)
                    .clipShape(RoundedRectangle(cornerRadius: isLarge ? 20 : 12))
            } else {
                RoundedRectangle(cornerRadius: isLarge ? 20 : 12)
                    .fill(AppTheme.lavender.opacity(0.3))
                    .frame(height: isLarge ? 300 : 100)
                    .overlay(
                        Image(systemName: "pencil.tip")
                            .font(.system(size: isLarge ? 48 : 24))
                            .foregroundColor(AppTheme.accentPurple)
                    )
            }
        }
    }
    
    private func statusPreview(content: SharedContent, isLarge: Bool) -> some View {
        VStack(spacing: isLarge ? 16 : 8) {
            Text(content.statusEmoji ?? "💕")
                .font(.system(size: isLarge ? 80 : 40))
            
            Text(content.statusText ?? "")
                .font(isLarge ? .appHeadline : .appCaption)
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: isLarge ? 200 : 80)
        .background(
            RoundedRectangle(cornerRadius: isLarge ? 20 : 12)
                .fill(
                    RadialGradient(
                        colors: [AppTheme.softPink.opacity(0.4), AppTheme.lavender.opacity(0.2)],
                        center: .center,
                        startRadius: 20,
                        endRadius: isLarge ? 150 : 60
                    )
                )
        )
    }
    
    // MARK: - Recent History Section
    private var recentHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent")
                .font(.appSubheadline)
                .foregroundColor(AppTheme.textPrimary)
            
            ForEach(Array(content.dropFirst().prefix(10))) { item in
                historyRow(content: item)
            }
        }
    }
    
    private func historyRow(content: SharedContent) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            contentPreview(content: content, isLarge: false)
                .frame(width: 60, height: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(contentTypeLabel(content.contentType))
                        .font(.appCaption)
                        .foregroundColor(AppTheme.accentPurple)
                    
                    Spacer()
                    
                    Text(content.timestamp.timeAgo)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Text(contentDescription(content))
                    .font(.appBody)
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: AppTheme.accentPink.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Helpers
    
    private func contentTypeLabel(_ type: ContentType) -> String {
        switch type {
        case .photo: return "📸 Photo"
        case .note: return "📝 Note"
        case .drawing: return "✏️ Drawing"
        case .status: return "💭 Status"
        }
    }
    
    private func contentDescription(_ content: SharedContent) -> String {
        switch content.contentType {
        case .photo:
            return content.caption ?? "Shared a photo"
        case .note:
            return content.noteText ?? "Sent a note"
        case .drawing:
            return "Sent a drawing"
        case .status:
            return "\(content.statusEmoji ?? "") \(content.statusText ?? "")"
        }
    }
    
    private func loadContent() {
        Task {
            do {
                let fetched = try await firebaseService.fetchPartnerContent()
                await MainActor.run {
                    content = fetched
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    PartnerWidgetView()
        .environmentObject(FirebaseService.shared)
}
