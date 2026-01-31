import SwiftUI

struct NotesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var firebaseService: FirebaseService
    
    @State private var noteText = ""
    @State private var showDrawingCanvas = false
    @State private var currentDrawing: UIImage?
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var selectedQuickNote: String?
    
    // Quick notes
    let quickNotes = [
        "I love you! 💕",
        "Thinking of you 🥰",
        "You make me smile 😊",
        "Can't wait to see you!",
        "You're amazing ✨",
        "Miss your face 🥺",
        "Sending hugs 🤗",
        "Dream of me tonight 🌙"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title
                VStack(spacing: 4) {
                    Text("Send a Note")
                        .font(.appHeadline)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("Write something sweet or draw a doodle")
                        .font(.appCaption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.top, 20)
                
                // Mode selector
                modeSelectorView
                
                if showDrawingCanvas {
                    // Drawing mode
                    drawingView
                } else {
                    // Text note mode
                    textNoteView
                }
                
                // Quick notes
                quickNotesView
                
                // Send button
                if !noteText.isEmpty || currentDrawing != nil {
                    sendButton
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
        }
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
        .sheet(isPresented: $showDrawingCanvas) {
            DrawingCanvasSheet(drawing: $currentDrawing)
        }
    }
    
    // MARK: - Mode Selector
    private var modeSelectorView: some View {
        HStack(spacing: 0) {
            modeButton(title: "Text", icon: "text.cursor", isSelected: !showDrawingCanvas) {
                withAnimation(.spring(response: 0.3)) {
                    showDrawingCanvas = false
                }
            }
            
            modeButton(title: "Draw", icon: "pencil.tip", isSelected: showDrawingCanvas) {
                withAnimation(.spring(response: 0.3)) {
                    showDrawingCanvas = true
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: AppTheme.accentPink.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private func modeButton(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.appButton)
            }
            .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AnyShapeStyle(AppTheme.buttonGradient) : AnyShapeStyle(Color.clear))
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Text Note View
    private var textNoteView: some View {
        VStack(spacing: 16) {
            // Note card
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: AppTheme.accentPink.opacity(0.15), radius: 15, x: 0, y: 8)
                
                // Decorative elements
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "heart.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.softPink.opacity(0.3))
                            .offset(x: 20, y: -10)
                    }
                    Spacer()
                }
                
                // Text editor
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 24))
                            .foregroundStyle(AppTheme.mainGradient)
                        Spacer()
                    }
                    
                    TextEditor(text: $noteText)
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundColor(AppTheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 150)
                    
                    HStack {
                        Spacer()
                        Text("\(noteText.count)/200")
                            .font(.appCaption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                .padding(20)
            }
            .frame(height: 250)
            
            if noteText.isEmpty {
                Text("Tip: Tap a quick note below or write your own")
                    .font(.appCaption)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
    }
    
    // MARK: - Drawing View
    private var drawingView: some View {
        VStack(spacing: 16) {
            if let drawing = currentDrawing {
                // Show drawing preview
                ZStack {
                    Image(uiImage: drawing)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(AppTheme.mainGradient, lineWidth: 2)
                        )
                        .shadow(color: AppTheme.accentPink.opacity(0.2), radius: 15, x: 0, y: 8)
                    
                    // Edit button
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: { currentDrawing = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.white, Color.black.opacity(0.5))
                            }
                            .padding(8)
                        }
                        Spacer()
                    }
                }
            } else {
                // Drawing canvas placeholder
                Button(action: { showDrawingCanvas = true }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(AppTheme.cardGradient)
                            .frame(height: 250)
                            .shadow(color: AppTheme.accentPink.opacity(0.15), radius: 15, x: 0, y: 8)
                        
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.softGradient)
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "pencil.tip.crop.circle")
                                    .font(.system(size: 36))
                                    .foregroundStyle(AppTheme.mainGradient)
                            }
                            
                            VStack(spacing: 4) {
                                Text("Tap to draw")
                                    .font(.appSubheadline)
                                    .foregroundColor(AppTheme.textPrimary)
                                
                                Text("Create a cute doodle for your love")
                                    .font(.appCaption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Quick Notes
    private var quickNotesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick notes")
                .font(.appCaption)
                .foregroundColor(AppTheme.textSecondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(quickNotes, id: \.self) { note in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            noteText = note
                            selectedQuickNote = note
                        }
                    }) {
                        Text(note)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedQuickNote == note ? .white : AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedQuickNote == note ? AnyShapeStyle(AppTheme.buttonGradient) : AnyShapeStyle(Color.white))
                                    .shadow(color: AppTheme.accentPink.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Send Button
    private var sendButton: some View {
        Button(action: sendNote) {
            HStack(spacing: 8) {
                if isSending {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Send to \(appState.partner?.name ?? "Partner")")
                    Image(systemName: "paperplane.fill")
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
                    
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 8) {
                    Text("Note sent! 💌")
                        .font(.appHeadline)
                        .foregroundColor(.white)
                    
                    Text("Your love note is on its way")
                        .font(.appBody)
                        .foregroundColor(.white.opacity(0.8))
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
    private func sendNote() {
        guard let currentUser = appState.currentUser,
              !noteText.isEmpty || currentDrawing != nil else { return }
        
        isSending = true
        
        Task {
            do {
                var content = SharedContent(
                    senderId: currentUser.id,
                    senderName: currentUser.name,
                    contentType: currentDrawing != nil ? .drawing : .note
                )
                
                if let drawing = currentDrawing {
                    content.drawingData = drawing.pngData()
                } else {
                    content.noteText = noteText
                }
                
                try await firebaseService.sendContent(content)
                
                await MainActor.run {
                    isSending = false
                    showSuccess = true
                    noteText = ""
                    currentDrawing = nil
                    selectedQuickNote = nil
                }
            } catch {
                await MainActor.run {
                    isSending = false
                }
            }
        }
    }
}

// MARK: - Drawing Canvas Sheet
struct DrawingCanvasSheet: View {
    @Binding var drawing: UIImage?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            DrawingCanvas(onSave: { image in
                drawing = image
                dismiss()
            })
            .navigationTitle("Draw")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NotesView()
        .environmentObject(AppState())
        .environmentObject(FirebaseService.shared)
}
