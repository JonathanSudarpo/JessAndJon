import Foundation
import SwiftUI

// MARK: - Firebase Service
// This is a mock implementation that stores data locally
// Replace with actual Firebase SDK calls when you set up Firebase

class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    @Published var isConnected = false
    @Published var partnerContent: SharedContent?
    
    private let sharedDefaults = UserDefaults(suiteName: "group.com.jessandjon.app")
    private let contentKey = "sharedContent"
    private let partnerContentKey = "partnerContent"
    
    init() {
        loadLocalContent()
    }
    
    // MARK: - User Management
    
    func createUser(name: String) async throws -> AppUser {
        let user = AppUser(id: UUID().uuidString, name: name)
        // In real implementation: save to Firestore
        // await Firestore.firestore().collection("users").document(user.id).setData(...)
        return user
    }
    
    func connectWithPartner(code: String, currentUser: AppUser) async throws -> AppUser? {
        // In real implementation: query Firestore for user with this partner code
        // let query = Firestore.firestore().collection("users").whereField("partnerCode", isEqualTo: code)
        
        // Mock: Create a fake partner for testing
        var partner = AppUser(id: UUID().uuidString, name: "Partner")
        partner.partnerId = currentUser.id
        
        // Update current user with partner ID
        var updatedUser = currentUser
        updatedUser.partnerId = partner.id
        
        return partner
    }
    
    // MARK: - Content Sharing
    
    func sendContent(_ content: SharedContent) async throws {
        var allContent = loadAllContent()
        allContent.insert(content, at: 0)
        saveAllContent(allContent)
        
        // Save to shared container for widget
        saveToWidget(content)
        
        // In real implementation: save to Firestore
        // try await Firestore.firestore().collection("content").document(content.id).setData(...)
        
        // Trigger push notification to partner
        // await sendPushNotification(to: partnerId, content: content)
    }
    
    func fetchPartnerContent() async throws -> [SharedContent] {
        // In real implementation: query Firestore
        // let query = Firestore.firestore().collection("content")
        //     .whereField("senderId", isEqualTo: partnerId)
        //     .order(by: "timestamp", descending: true)
        
        return loadAllContent()
    }
    
    func getLatestPartnerContent() -> SharedContent? {
        return loadAllContent().first
    }
    
    // MARK: - Memories/Collage
    
    func fetchMemories(for monthYear: String) async throws -> [SharedContent] {
        let allContent = loadAllContent()
        return allContent.filter { $0.timestamp.monthYearString == monthYear }
    }
    
    func generateCollage(for monthYear: String) async throws -> Memory {
        let content = try await fetchMemories(for: monthYear)
        let photos = content.filter { $0.contentType == .photo }
        let notes = content.filter { $0.contentType == .note || $0.contentType == .drawing }
        let statuses = content.filter { $0.contentType == .status }
        
        return Memory(
            id: UUID().uuidString,
            coupleId: "couple_id",
            monthYear: monthYear,
            photoUrls: photos.compactMap { $0.imageUrl },
            noteCount: notes.count,
            statusCount: statuses.count,
            createdAt: Date(),
            title: "Our memories from \(monthYear)"
        )
    }
    
    // MARK: - Local Storage
    
    private func loadAllContent() -> [SharedContent] {
        guard let data = sharedDefaults?.data(forKey: contentKey),
              let content = try? JSONDecoder().decode([SharedContent].self, from: data) else {
            return []
        }
        return content
    }
    
    private func saveAllContent(_ content: [SharedContent]) {
        if let data = try? JSONEncoder().encode(content) {
            sharedDefaults?.set(data, forKey: contentKey)
        }
    }
    
    private func loadLocalContent() {
        partnerContent = loadAllContent().first
    }
    
    // MARK: - Widget Support
    
    private func saveToWidget(_ content: SharedContent) {
        let widgetData = WidgetData(
            contentType: content.contentType,
            imageData: content.imageData,
            noteText: content.noteText,
            statusEmoji: content.statusEmoji,
            statusText: content.statusText,
            senderName: content.senderName,
            timestamp: content.timestamp
        )
        
        if let data = try? JSONEncoder().encode(widgetData) {
            sharedDefaults?.set(data, forKey: "widgetData")
        }
        
        // Reload widget timeline
        // WidgetCenter.shared.reloadTimelines(ofKind: "LoveWidget")
    }
    
    func getWidgetData() -> WidgetData {
        guard let data = sharedDefaults?.data(forKey: "widgetData"),
              let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return WidgetData.placeholder
        }
        return widgetData
    }
    
    // MARK: - Image Handling
    
    func uploadImage(_ image: UIImage) async throws -> String {
        // In real implementation: upload to Firebase Storage
        // let ref = Storage.storage().reference().child("images/\(UUID().uuidString).jpg")
        // let data = image.jpegData(compressionQuality: 0.7)!
        // let _ = try await ref.putDataAsync(data)
        // return try await ref.downloadURL().absoluteString
        
        // Mock: return a fake URL
        return "local://\(UUID().uuidString)"
    }
    
    func downloadImage(from url: String) async throws -> UIImage? {
        // In real implementation: download from Firebase Storage
        // let ref = Storage.storage().reference(forURL: url)
        // let data = try await ref.data(maxSize: 10 * 1024 * 1024)
        // return UIImage(data: data)
        
        return nil
    }
}

// MARK: - Mock Data Generator
extension FirebaseService {
    func generateMockContent() {
        let mockContent: [SharedContent] = [
            {
                var c = SharedContent(senderId: "partner", senderName: "Jess", contentType: .status)
                c.statusEmoji = "💕"
                c.statusText = "Missing you"
                c.timestamp = Date().addingTimeInterval(-3600)
                return c
            }(),
            {
                var c = SharedContent(senderId: "partner", senderName: "Jon", contentType: .note)
                c.noteText = "Can't wait to see you tonight! 💖"
                c.timestamp = Date().addingTimeInterval(-7200)
                return c
            }(),
            {
                var c = SharedContent(senderId: "partner", senderName: "Jess", contentType: .status)
                c.statusEmoji = "☕️"
                c.statusText = "Good morning!"
                c.timestamp = Date().addingTimeInterval(-86400)
                return c
            }()
        ]
        
        saveAllContent(mockContent)
        partnerContent = mockContent.first
    }
}
