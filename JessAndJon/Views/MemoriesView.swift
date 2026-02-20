import SwiftUI

struct MemoriesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var firebaseService: FirebaseService
    
    @State private var selectedMonth = Date()
    @State private var memories: [SharedContent] = []
    @State private var isLoading = false
    @State private var showCollageView = false
    @State private var anniversaryDate: Date = Date()
    @State private var showDatePicker = false
    @State private var selectedFilter: ContentType? = nil
    @State private var selectedContent: SharedContent? = nil
    
    private let calendar = Calendar.current
    
    // Computed property for filtered memories
    private var filteredMemories: [SharedContent] {
        if let filter = selectedFilter {
            if filter == .note {
                // Notes filter includes both notes and drawings
                return memories.filter { $0.contentType == .note || $0.contentType == .drawing }
            } else {
                return memories.filter { $0.contentType == filter }
            }
        }
        return memories
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title
                VStack(spacing: 4) {
                    Text("Our Memories")
                        .font(.appHeadline)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("Relive your beautiful moments together")
                        .font(.appCaption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.top, 20)
                
                // Anniversary card
                anniversaryCard
                
                // Month selector
                monthSelector
                
                // Memory stats
                memoryStats
                
                // Memory grid
                if isLoading {
                    ProgressView()
                        .padding(40)
                } else if filteredMemories.isEmpty {
                    emptyState
                } else {
                    memoryGrid
                }
                
                // Create collage button
                if !filteredMemories.isEmpty {
                    createCollageButton
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showCollageView) {
            CollageView(memories: filteredMemories, monthYear: selectedMonth)
        }
        .sheet(isPresented: $showDatePicker) {
            anniversaryDatePicker
        }
        .sheet(item: $selectedContent) { content in
            Group {
                switch content.contentType {
                case .photo:
                    PhotoDetailView(content: content)
                case .note:
                    NoteDetailView(content: content)
                case .drawing:
                    DrawingDetailView(content: content)
                case .status:
                    StatusDetailView(content: content)
                }
            }
        }
        .onAppear {
            loadMemories()
            // Sync user and partner data when Memories view appears (for anniversary date updates)
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
    
    // MARK: - Anniversary Card
    private var anniversaryCard: some View {
        Button(action: { showDatePicker = true }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppTheme.sunsetGradient)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Anniversary")
                        .font(.appCaption)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    if let user = appState.currentUser, let anniversary = user.anniversaryDate {
                        Text(anniversary.formattedDate)
                            .font(.appSubheadline)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.accentPink)
                                Text("\(Date().daysSince(anniversary)) days together")
                                    .font(.appSubheadline)
                                    .foregroundColor(AppTheme.accentPink)
                            }
                            
                            Text("•")
                                .font(.appCaption)
                                .foregroundColor(AppTheme.textSecondary)
                            
                            Text(daysUntilAnniversary(from: anniversary))
                                .font(.appCaption)
                                .foregroundColor(AppTheme.accentPurple)
                        }
                    } else {
                        Text("Set your special date")
                            .font(.appSubheadline)
                            .foregroundColor(AppTheme.accentPurple)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: AppTheme.accentPink.opacity(0.15), radius: 15, x: 0, y: 8)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Month Selector
    private var monthSelector: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.accentPurple)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(AppTheme.lavender.opacity(0.5))
                    )
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(monthYearString(from: selectedMonth))
                    .font(.appHeadline)
                    .foregroundColor(AppTheme.textPrimary)
                
                Text("\(memories.count) memories")
                    .font(.appCaption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Spacer()
            
            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(canGoForward ? AppTheme.accentPurple : AppTheme.textSecondary.opacity(0.5))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(AppTheme.lavender.opacity(canGoForward ? 0.5 : 0.2))
                    )
            }
            .disabled(!canGoForward)
        }
    }
    
    // MARK: - Memory Stats
    private var memoryStats: some View {
        VStack(spacing: 12) {
            // Streak card (full width)
            let streak = firebaseService.getStreak()
            if streak.currentStreak > 0 {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.heartRed.opacity(0.15))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "flame.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.heartRed)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Streak")
                            .font(.appCaption)
                            .foregroundColor(AppTheme.textSecondary)
                        
                        HStack(spacing: 8) {
                            Text("\(streak.currentStreak) days 🔥")
                                .font(.appSubheadline)
                                .foregroundColor(AppTheme.heartRed)
                            
                            if streak.longestStreak > streak.currentStreak {
                                Text("• Best: \(streak.longestStreak)")
                                    .font(.appCaption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.heartRed.opacity(0.1), AppTheme.accentPink.opacity(0.05)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: AppTheme.heartRed.opacity(0.1), radius: 8, x: 0, y: 4)
                )
            }
            
            // Other stats - now clickable
            HStack(spacing: 12) {
                statCard(
                    icon: "photo.fill",
                    count: memories.filter { $0.contentType == .photo }.count,
                    label: "Photos",
                    color: AppTheme.accentPink,
                    contentType: .photo
                )
                
                statCard(
                    icon: "note.text",
                    count: memories.filter { $0.contentType == .note || $0.contentType == .drawing }.count,
                    label: "Notes",
                    color: AppTheme.accentPurple,
                    contentType: .note
                )
                
                statCard(
                    icon: "heart.text.square.fill",
                    count: memories.filter { $0.contentType == .status }.count,
                    label: "Statuses",
                    color: AppTheme.heartPink,
                    contentType: .status
                )
            }
            
            // Filter indicator and clear button
            if selectedFilter != nil {
                HStack {
                    Text("Showing: \(filterLabel(selectedFilter!))")
                        .font(.appCaption)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedFilter = nil
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                            Text("Clear filter")
                                .font(.appCaption)
                        }
                        .foregroundColor(AppTheme.accentPurple)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func filterLabel(_ type: ContentType) -> String {
        switch type {
        case .photo: return "Photos"
        case .note: return "Notes"
        case .drawing: return "Drawings"
        case .status: return "Statuses"
        }
    }
    
    private func statCard(icon: String, count: Int, label: String, color: Color, contentType: ContentType) -> some View {
        let isSelected = selectedFilter == contentType
        
        return Button(action: {
            withAnimation(.spring(response: 0.3)) {
                if selectedFilter == contentType {
                    // Toggle off if already selected
                    selectedFilter = nil
                } else {
                    selectedFilter = contentType
                }
            }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? color.opacity(0.25) : color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }
                
                Text("\(count)")
                    .font(.appSubheadline)
                    .foregroundColor(AppTheme.textPrimary)
                
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? color.opacity(0.1) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? color : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: color.opacity(isSelected ? 0.2 : 0.1), radius: isSelected ? 12 : 8, x: 0, y: isSelected ? 6 : 4)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Memory Grid
    private var memoryGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            ForEach(filteredMemories) { memory in
                Button(action: { selectedContent = memory }) {
                    memoryCell(memory: memory)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func memoryCell(memory: SharedContent) -> some View {
        ZStack {
            switch memory.contentType {
            case .photo:
                if let imageData = memory.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    AppTheme.softGradient
                    Image(systemName: "photo")
                        .foregroundColor(AppTheme.accentPink)
                }
            case .note:
                AppTheme.lavender.opacity(0.3)
                VStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.accentPurple)
                    if let text = memory.noteText {
                        Text(text)
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }
                }
            case .drawing:
                if let drawingData = memory.drawingData, let uiImage = UIImage(data: drawingData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    AppTheme.lavender.opacity(0.3)
                    VStack(spacing: 4) {
                        Image(systemName: "pencil.tip")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.accentPurple)
                    }
                }
                case .status:
                AppTheme.softGradient.opacity(0.5)
                VStack(spacing: 4) {
                    if let emoji = memory.statusEmoji {
                        Text(emoji)
                            .font(.system(size: 28))
                    } else {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.accentPink)
                    }
                    Text(memory.statusText ?? "")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.softGradient)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "heart.text.square")
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.mainGradient)
            }
            
            VStack(spacing: 8) {
                Text("No memories yet")
                    .font(.appSubheadline)
                    .foregroundColor(AppTheme.textPrimary)
                
                Text("Start sharing photos, notes, and statuses\nto create beautiful memories together!")
                    .font(.appCaption)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
    
    // MARK: - Create Collage Button
    private var createCollageButton: some View {
        Button(action: { showCollageView = true }) {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.3x3.fill")
                Text("Create Collage")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.top, 8)
    }
    
    // MARK: - Anniversary Date Picker
    private var anniversaryDatePicker: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.mainGradient)
                    
                    Text("When did your love story begin?")
                        .font(.appHeadline)
                        .foregroundColor(AppTheme.textPrimary)
                }
                .padding(.top, 32)
                
                DatePicker(
                    "Anniversary",
                    selection: $anniversaryDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(AppTheme.accentPink)
                
                Spacer()
                
                Button(action: saveAnniversary) {
                    Text("Save Date")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
            .navigationTitle("Set Anniversary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showDatePicker = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private var canGoForward: Bool {
        let now = Date()
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        return nextMonth <= now
    }
    
    private func changeMonth(by value: Int) {
        withAnimation {
            selectedMonth = calendar.date(byAdding: .month, value: value, to: selectedMonth) ?? selectedMonth
        }
        loadMemories()
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func daysUntilAnniversary(from date: Date) -> String {
        let now = Date()
        var nextAnniversary = calendar.date(
            bySetting: .year,
            value: calendar.component(.year, from: now),
            of: date
        ) ?? date
        
        if nextAnniversary < now {
            nextAnniversary = calendar.date(byAdding: .year, value: 1, to: nextAnniversary) ?? nextAnniversary
        }
        
        let days = calendar.dateComponents([.day], from: now, to: nextAnniversary).day ?? 0
        
        if days == 0 {
            return "Today is your anniversary!"
        } else if days == 1 {
            return "Tomorrow is your anniversary!"
        } else {
            return "\(days) days until your anniversary"
        }
    }
    
    private func loadMemories() {
        isLoading = true
        
        Task {
            do {
                let monthYear = selectedMonth.monthYearString
                print("📸 Loading memories for: \(monthYear)")
                let content = try await firebaseService.fetchMemories(for: monthYear)
                await MainActor.run {
                    memories = content
                    isLoading = false
                    print("📸 Loaded \(content.count) memories")
                }
            } catch {
                print("❌ Error loading memories: \(error.localizedDescription)")
                await MainActor.run {
                    memories = []
                    isLoading = false
                }
            }
        }
    }
    
    private func saveAnniversary() {
        guard var user = appState.currentUser else { return }
        
        user.anniversaryDate = anniversaryDate
        appState.saveUser(user)
        
        // Also save to Firestore so it syncs between devices
        Task {
            do {
                try await firebaseService.updateUser(user)
                
                // Refresh user and partner data to get the synced anniversary date
                let (updatedUser, updatedPartner) = try await firebaseService.syncUserAndPartner()
                await MainActor.run {
                    if let updatedUser = updatedUser {
                        appState.saveUser(updatedUser)
                    }
                    if let updatedPartner = updatedPartner {
                        appState.savePartner(updatedPartner)
                    }
                }
            } catch {
                print("Failed to save anniversary to Firestore: \(error.localizedDescription)")
            }
        }
        
        showDatePicker = false
    }
}

// MARK: - Collage View
struct CollageView: View {
    let memories: [SharedContent]
    let monthYear: Date
    @Environment(\.dismiss) var dismiss
    
    @State private var isAnimating = false
    @State private var currentIndex = 0
    
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AppTheme.backgroundDark
                    .ignoresSafeArea()
                
                // Slideshow
                if !memories.isEmpty {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(memories.enumerated()), id: \.element.id) { index, memory in
                            memorySlide(memory: memory)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onReceive(timer) { _ in
                        withAnimation(.easeInOut(duration: 0.5)) {
                            currentIndex = (currentIndex + 1) % memories.count
                        }
                    }
                }
                
                // Title overlay
                VStack {
                    Text(monthYearTitle)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        .padding(.top, 60)
                    
                    Spacer()
                    
                    // Progress dots
                    HStack(spacing: 8) {
                        ForEach(0..<memories.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentIndex ? 1.2 : 1.0)
                                .animation(.spring(), value: currentIndex)
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white, Color.white.opacity(0.3))
                    }
                }
            }
        }
    }
    
    private var monthYearTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return "Our \(formatter.string(from: monthYear))"
    }
    
    private func memorySlide(memory: SharedContent) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Content
            Group {
                switch memory.contentType {
                case .photo:
                    if let imageData = memory.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    }
                case .note:
                    VStack(spacing: 16) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text(memory.noteText ?? "")
                            .font(.system(size: 24, weight: .medium, design: .serif))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                case .drawing:
                    if let drawingData = memory.drawingData, let uiImage = UIImage(data: drawingData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                case .status:
                    VStack(spacing: 12) {
                        if let emoji = memory.statusEmoji {
                            Text(emoji)
                                .font(.system(size: 80))
                        } else {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Text(memory.statusText ?? "")
                            .font(.appHeadline)
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 400)
            
            // Caption/metadata
            VStack(spacing: 8) {
                Text("From \(memory.senderName)")
                    .font(.appCaption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(memory.timestamp.formattedDate)
                    .font(.appCaption)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    MemoriesView()
        .environmentObject(AppState())
        .environmentObject(FirebaseService.shared)
}
