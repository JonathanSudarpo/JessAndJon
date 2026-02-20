import SwiftUI

struct NoteDetailView: View {
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
                        // Note card
                        VStack(spacing: 20) {
                            // Quote opening
                            Image(systemName: "quote.opening")
                                .font(.system(size: 48))
                                .foregroundStyle(AppTheme.mainGradient)
                            
                            // Note text
                            Text(content.noteText ?? "")
                                .font(.system(size: 24, weight: .medium, design: .serif))
                                .foregroundColor(AppTheme.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(8)
                                .padding(.horizontal, 32)
                            
                            // Quote closing
                            Image(systemName: "quote.closing")
                                .font(.system(size: 48))
                                .foregroundStyle(AppTheme.mainGradient)
                        }
                        .padding(40)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white)
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
            .navigationTitle("Note")
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
    NoteDetailView(content: SharedContent(
        senderId: "test",
        senderName: "Jess",
        contentType: .note
    ))
}
