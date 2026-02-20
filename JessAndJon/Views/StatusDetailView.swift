import SwiftUI

struct StatusDetailView: View {
    let content: SharedContent
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                AppTheme.softGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Status card
                        VStack(spacing: 24) {
                            // Large emoji
                            if let emoji = content.statusEmoji {
                                Text(emoji)
                                    .font(.system(size: 120))
                            } else {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(AppTheme.mainGradient)
                            }
                            
                            // Status text
                            if let statusText = content.statusText, !statusText.isEmpty {
                                Text(statusText)
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                        }
                        .padding(60)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            AppTheme.softPink.opacity(0.4),
                                            AppTheme.lavender.opacity(0.2),
                                            Color.white
                                        ],
                                        center: .center,
                                        startRadius: 50,
                                        endRadius: 200
                                    )
                                )
                                .shadow(color: AppTheme.accentPink.opacity(0.2), radius: 20, x: 0, y: 10)
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 40)
                        
                        // Info card
                        VStack(alignment: .leading, spacing: 16) {
                            // From
                            HStack {
                                Text("From")
                                    .font(.appCaption)
                                    .foregroundColor(AppTheme.textSecondary)
                                
                                Text(content.senderName)
                                    .font(.appHeadline)
                                    .foregroundColor(AppTheme.textPrimary)
                                
                                Spacer()
                            }
                            
                            // Date
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.textSecondary)
                                
                                Text(content.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.appCaption)
                                    .foregroundColor(AppTheme.textSecondary)
                                
                                Spacer()
                                
                                Text(content.timestamp.timeAgo)
                                    .font(.appCaption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                        )
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentPurple)
                }
            }
        }
    }
}

#Preview {
    StatusDetailView(content: SharedContent(
        senderId: "test",
        senderName: "Jess",
        contentType: .status
    ))
}
