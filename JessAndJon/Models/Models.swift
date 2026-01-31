import Foundation
import SwiftUI

// MARK: - User Model
struct AppUser: Codable, Identifiable {
    var id: String
    var name: String
    var partnerId: String?
    var partnerCode: String
    var createdAt: Date
    var anniversaryDate: Date?
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
        self.partnerCode = AppUser.generatePartnerCode()
        self.createdAt = Date()
    }
    
    static func generatePartnerCode() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }
}

// MARK: - Shared Content Types
enum ContentType: String, Codable {
    case photo
    case note
    case drawing
    case status
}

// MARK: - Shared Content Model
struct SharedContent: Codable, Identifiable {
    var id: String
    var senderId: String
    var senderName: String
    var contentType: ContentType
    var timestamp: Date
    
    // For photos
    var imageUrl: String?
    var imageData: Data?
    
    // For notes/drawings
    var noteText: String?
    var drawingData: Data?
    
    // For status
    var statusEmoji: String?
    var statusText: String?
    
    // Metadata
    var caption: String?
    var isRead: Bool
    
    init(id: String = UUID().uuidString, senderId: String, senderName: String, contentType: ContentType) {
        self.id = id
        self.senderId = senderId
        self.senderName = senderName
        self.contentType = contentType
        self.timestamp = Date()
        self.isRead = false
    }
}

// MARK: - Status Options
struct StatusOption: Identifiable {
    let id = UUID()
    let emoji: String
    let text: String
    let color: Color
    
    static let options: [StatusOption] = [
        StatusOption(emoji: "💕", text: "Missing you", color: AppTheme.heartPink),
        StatusOption(emoji: "🥰", text: "Thinking of you", color: AppTheme.accentPink),
        StatusOption(emoji: "😘", text: "Sending kisses", color: AppTheme.heartRed),
        StatusOption(emoji: "🤗", text: "Wish you were here", color: AppTheme.gradientMid),
        StatusOption(emoji: "💤", text: "Going to sleep", color: AppTheme.lavender),
        StatusOption(emoji: "☕️", text: "Good morning!", color: AppTheme.gradientStart),
        StatusOption(emoji: "🍽️", text: "Having lunch", color: AppTheme.softPink),
        StatusOption(emoji: "💼", text: "At work", color: AppTheme.textSecondary),
        StatusOption(emoji: "🏠", text: "Home now!", color: AppTheme.accentPurple),
        StatusOption(emoji: "❤️", text: "I love you", color: AppTheme.heartRed),
        StatusOption(emoji: "🌙", text: "Goodnight", color: AppTheme.backgroundDark),
        StatusOption(emoji: "🎉", text: "Excited!", color: AppTheme.accentPink),
    ]
}

// MARK: - Memory/Collage Model
struct Memory: Codable, Identifiable {
    var id: String
    var coupleId: String
    var monthYear: String // Format: "2024-01"
    var photoUrls: [String]
    var noteCount: Int
    var statusCount: Int
    var createdAt: Date
    var title: String?
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var partner: AppUser?
    @Published var latestFromPartner: SharedContent?
    @Published var isOnboarded: Bool = false
    @Published var allContent: [SharedContent] = []
    
    // User defaults keys
    private let userDefaultsKey = "currentUser"
    private let onboardedKey = "isOnboarded"
    
    init() {
        loadUser()
    }
    
    func loadUser() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(AppUser.self, from: data) {
            currentUser = user
        }
        isOnboarded = UserDefaults.standard.bool(forKey: onboardedKey)
    }
    
    func saveUser(_ user: AppUser) {
        currentUser = user
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    func completeOnboarding() {
        isOnboarded = true
        UserDefaults.standard.set(true, forKey: onboardedKey)
    }
    
    func signOut() {
        currentUser = nil
        partner = nil
        isOnboarded = false
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.set(false, forKey: onboardedKey)
    }
}

// MARK: - Widget Data (Shared with Widget Extension)
struct WidgetData: Codable {
    var contentType: ContentType
    var imageData: Data?
    var noteText: String?
    var statusEmoji: String?
    var statusText: String?
    var senderName: String
    var timestamp: Date
    
    static let placeholder = WidgetData(
        contentType: .status,
        statusEmoji: "💕",
        statusText: "Waiting for love...",
        senderName: "Partner",
        timestamp: Date()
    )
}

// MARK: - Date Helpers
extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }
    
    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: self)
    }
}
