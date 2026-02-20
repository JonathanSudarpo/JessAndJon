import SwiftUI

struct DrawingDetailView: View {
    let content: SharedContent
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Full-size drawing
                        if let drawingData = content.drawingData ?? content.imageData,
                           let uiImage = UIImage(data: drawingData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                        } else {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(AppTheme.softGradient)
                                .frame(height: 400)
                                .overlay(
                                    Image(systemName: "pencil.tip")
                                        .font(.system(size: 48))
                                        .foregroundColor(AppTheme.accentPurple)
                                )
                        }
                        
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
                            
                            // Caption
                            if let caption = content.caption, !caption.isEmpty {
                                Text(caption)
                                    .font(.appBody)
                                    .foregroundColor(AppTheme.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
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
            .navigationTitle("Drawing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    DrawingDetailView(content: SharedContent(
        senderId: "test",
        senderName: "Jess",
        contentType: .drawing
    ))
}
