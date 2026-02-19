import SwiftUI

struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    @Environment(\.dismiss) var dismiss
    
    // Popular emojis for couples
    let emojiCategories: [(String, [String])] = [
        ("Love", ["💕", "❤️", "💖", "💗", "💓", "💞", "💝", "💘", "💟", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💋", "😘", "🥰", "😍", "😻", "💑", "👩‍❤️‍👨", "👨‍❤️‍👨", "👩‍❤️‍👩"]),
        ("Happy", ["😊", "😄", "😃", "😁", "😆", "😅", "🤣", "😂", "🙂", "😉", "😋", "😎", "🤩", "🥳", "😇", "🤗", "🤭", "😌", "😏"]),
        ("Romantic", ["🌹", "🌺", "🌻", "🌷", "🌼", "🌸", "💐", "🎁", "🎀", "✨", "⭐", "🌟", "💫", "🌙", "🌠", "🎆", "🎇", "🕯️", "💍", "💎"]),
        ("Activities", ["☕", "🍕", "🍔", "🍰", "🍫", "🍭", "🍬", "🍪", "🧁", "🎂", "🍷", "🍾", "🥂", "🍻", "🎵", "🎶", "🎤", "🎧", "🎮", "🎬", "📸", "📷", "🎨", "✏️", "📝", "💌", "📮"]),
        ("Moods", ["😴", "😪", "😌", "🤤", "😋", "🥺", "😢", "😭", "😤", "😠", "😡", "🤬", "😱", "😨", "😰", "😥", "😓", "🤯", "😵", "🥴", "🤢", "🤮", "🤧", "😷", "🤒", "🤕"]),
        ("Time", ["🌅", "🌄", "🌆", "🌇", "🌃", "🌉", "🌁", "⛅", "☀️", "🌤️", "⛈️", "🌦️", "🌧️", "⛈️", "🌩️", "❄️", "☃️", "⛄", "🌨️", "🌊", "🌋", "🏔️", "⛰️", "🌲", "🌳", "🌴", "🌵"]),
        ("Other", ["💭", "🤔", "🙄", "😑", "😐", "😶", "🤐", "🤫", "🤥", "😒", "🙃", "🤑", "🤠", "😈", "👿", "💀", "☠️", "👻", "👽", "🤖", "🎃", "🎄", "🎅", "🤶", "🧙", "🧚", "🧛", "🧜", "🧝", "🧞", "🧟"])
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Current selection preview
                    VStack(spacing: 8) {
                        Text("Selected")
                            .font(.appCaption)
                            .foregroundColor(AppTheme.textSecondary)
                        
                        Text(selectedEmoji)
                            .font(.system(size: 64))
                            .padding(20)
                            .background(
                                Circle()
                                    .fill(AppTheme.softGradient)
                            )
                    }
                    .padding(.top, 20)
                    
                    // Emoji categories
                    ForEach(emojiCategories, id: \.0) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(category.0)
                                .font(.appSubheadline)
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal, 20)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(category.1, id: \.self) { emoji in
                                    Button(action: {
                                        selectedEmoji = emoji
                                        dismiss()
                                    }) {
                                        Text(emoji)
                                            .font(.system(size: 32))
                                            .frame(width: 44, height: 44)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(selectedEmoji == emoji ? AppTheme.accentPink.opacity(0.2) : Color.clear)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .background(AppTheme.backgroundPrimary)
            .navigationTitle("Choose Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentPurple)
                }
            }
        }
    }
}

#Preview {
    EmojiPickerView(selectedEmoji: .constant("💭"))
}
