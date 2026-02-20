import Foundation
import SwiftUI
import UIKit
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import OSLog
import WidgetKit

// MARK: - Firebase Service
class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    @Published var isConnected = false
    @Published var partnerContent: SharedContent?
    @Published var streakData: StreakData = StreakData()
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let logger = Logger(subsystem: "com.jessandjon.app", category: "FirebaseService")
    
    private var contentListener: ListenerRegistration?
    
    private let sharedDefaults = UserDefaults(suiteName: "group.com.jessandjon.app")
    private let contentKey = "sharedContent"
    private let partnerContentKey = "partnerContent"
    
    init() {
        // Fallback to standard UserDefaults if App Group is not available
        if sharedDefaults == nil {
            logger.warning("App Group 'group.com.jessandjon.app' not configured - using standard UserDefaults")
        }
        loadLocalContent()
        // Load initial streak data
        streakData = getStreak()
    }
    
    deinit {
        contentListener?.remove()
    }
    
    // MARK: - User Management
    
    // Sync user and partner data from Firestore
    func syncUserAndPartner() async throws -> (AppUser?, AppUser?) {
        guard let authUser = Auth.auth().currentUser else {
            return (nil, nil)
        }
        
        // Fetch current user from Firestore
        let userDoc = try await db.collection("users").document(authUser.uid).getDocument()
        guard let userData = userDoc.data(),
              let userId = userData["id"] as? String,
              let userName = userData["name"] as? String,
              let partnerCode = userData["partnerCode"] as? String else {
            return (nil, nil)
        }
        
        var user = AppUser(id: userId, name: userName)
        user.partnerCode = partnerCode
        user.partnerId = userData["partnerId"] as? String
        
        // Load anniversary date if present
        if let anniversaryTimestamp = userData["anniversaryDate"] as? Timestamp {
            user.anniversaryDate = anniversaryTimestamp.dateValue()
        }
        
        // Load profile image URL if present
        if let profileImageUrl = userData["profileImageUrl"] as? String {
            user.profileImageUrl = profileImageUrl
        }
        
        // If user has a partner, fetch partner data
        var partner: AppUser? = nil
        if let partnerId = user.partnerId {
            let partnerDoc = try await db.collection("users").document(partnerId).getDocument()
            if let partnerData = partnerDoc.data(),
               let partnerUserId = partnerData["id"] as? String,
               let partnerName = partnerData["name"] as? String {
                partner = AppUser(id: partnerUserId, name: partnerName)
                partner?.partnerCode = partnerData["partnerCode"] as? String ?? ""
                partner?.partnerId = partnerData["partnerId"] as? String
                
                // Load partner's anniversary date if present
                if let anniversaryTimestamp = partnerData["anniversaryDate"] as? Timestamp {
                    partner?.anniversaryDate = anniversaryTimestamp.dateValue()
                }
                
                // Load partner's profile image URL if present
                if let profileImageUrl = partnerData["profileImageUrl"] as? String {
                    partner?.profileImageUrl = profileImageUrl
                }
            }
        }
        
        logger.info("Synced user and partner from Firestore")
        return (user, partner)
    }
    
    // Generate a unique partner code by checking Firestore
    private func generateUniquePartnerCode() async throws -> String {
        var code = AppUser.generatePartnerCode()
        var attempts = 0
        let maxAttempts = 10
        
        // Check if code exists in Firestore
        while attempts < maxAttempts {
            let query = db.collection("users")
                .whereField("partnerCode", isEqualTo: code)
                .limit(to: 1)
            
            let snapshot = try await query.getDocuments()
            
            if snapshot.documents.isEmpty {
                // Code is unique
                return code
            }
            
            // Code exists, generate a new one
            code = AppUser.generatePartnerCode()
            attempts += 1
        }
        
        // If we couldn't find a unique code after max attempts, throw error
        throw NSError(domain: "FirebaseService", code: -6, userInfo: [NSLocalizedDescriptionKey: "Could not generate unique partner code"])
    }
    
    func createUser(name: String) async throws -> AppUser {
        guard let authUser = Auth.auth().currentUser else {
            throw NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Validate and sanitize name
        let validatedName = try Validation.validateName(name)
        
        // Check if user already exists in Firestore
        let existingDoc = try? await db.collection("users").document(authUser.uid).getDocument()
        if existingDoc?.exists == true, let existingData = existingDoc?.data() {
            // User already exists - return existing user data
            logger.info("User already exists in Firestore: \(authUser.uid, privacy: .public)")
            guard let userId = existingData["id"] as? String,
                  let userName = existingData["name"] as? String,
                  let partnerCode = existingData["partnerCode"] as? String else {
                throw NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid user data in Firestore"])
            }
            
            var user = AppUser(id: userId, name: userName)
            user.partnerCode = partnerCode
            user.partnerId = existingData["partnerId"] as? String
            if let createdAtTimestamp = existingData["createdAt"] as? Timestamp {
                user.createdAt = createdAtTimestamp.dateValue()
            }
            if let anniversaryTimestamp = existingData["anniversaryDate"] as? Timestamp {
                user.anniversaryDate = anniversaryTimestamp.dateValue()
            }
            if let profileImageUrl = existingData["profileImageUrl"] as? String {
                user.profileImageUrl = profileImageUrl
            }
            
            return user
        }
        
        // New user - generate unique partner code
        let uniqueCode = try await generateUniquePartnerCode()
        var user = AppUser(id: authUser.uid, name: validatedName)
        user.partnerCode = uniqueCode
        
        // Save to Firestore
        var userData: [String: Any] = [
            "id": user.id,
            "name": user.name,
            "partnerCode": user.partnerCode,
            "createdAt": Timestamp(date: user.createdAt),
            "partnerId": user.partnerId as Any
        ]
        
        // Add anniversary date if present
        if let anniversaryDate = user.anniversaryDate {
            userData["anniversaryDate"] = Timestamp(date: anniversaryDate)
        }
        
        try await db.collection("users").document(user.id).setData(userData)
        logger.info("User created in Firestore: \(user.id, privacy: .public)")
        
        return user
    }
    
    // Update user in Firestore (for things like anniversary date, name changes, etc.)
    func updateUser(_ user: AppUser) async throws {
        guard let authUser = Auth.auth().currentUser,
              authUser.uid == user.id else {
            throw NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated or user ID mismatch"])
        }
        
        // Validate and sanitize name
        let validatedName = try Validation.validateName(user.name)
        
        var userData: [String: Any] = [
            "id": user.id,
            "name": validatedName,
            "partnerCode": user.partnerCode,
            "createdAt": Timestamp(date: user.createdAt),
            "partnerId": user.partnerId as Any
        ]
        
        // Add anniversary date if present
        if let anniversaryDate = user.anniversaryDate {
            userData["anniversaryDate"] = Timestamp(date: anniversaryDate)
        } else {
            // Remove anniversary date if it was set to nil
            userData["anniversaryDate"] = NSNull()
        }
        
        // Add profile image URL if present
        if let profileImageUrl = user.profileImageUrl {
            userData["profileImageUrl"] = profileImageUrl
        } else {
            userData["profileImageUrl"] = NSNull()
        }
        
        try await db.collection("users").document(user.id).updateData(userData)
        logger.info("User updated in Firestore: \(user.id, privacy: .public)")
        
        // If anniversary date was set/updated and user has a partner, sync it to partner's document
        if let anniversaryDate = user.anniversaryDate, let partnerId = user.partnerId {
            do {
                try await db.collection("users").document(partnerId).updateData([
                    "anniversaryDate": Timestamp(date: anniversaryDate)
                ])
                logger.info("Synced anniversary date to partner: \(partnerId, privacy: .public)")
            } catch {
                logger.error("Failed to sync anniversary date to partner: \(error.localizedDescription, privacy: .public)")
                // Don't throw - the user's update succeeded, partner sync is best effort
            }
        }
    }
    
    func connectWithPartner(code: String, currentUser: AppUser) async throws -> AppUser? {
        // Validate partner code format
        let validatedCode = try Validation.validatePartnerCode(code)
        logger.info("Searching for partner with code: \(validatedCode, privacy: .public)")
        
        // Check if current user already has a partner
        if currentUser.partnerId != nil {
            throw NSError(domain: "FirebaseService", code: -3, userInfo: [NSLocalizedDescriptionKey: "You already have a partner connected. Please disconnect your current partner first."])
        }
        
        // Query Firestore for user with this partner code
        let query = db.collection("users")
            .whereField("partnerCode", isEqualTo: validatedCode)
            .limit(to: 1)
        
        let snapshot = try await query.getDocuments()
        
        guard let partnerDoc = snapshot.documents.first,
              let partnerId = partnerDoc.data()["id"] as? String,
              let partnerName = partnerDoc.data()["name"] as? String else {
            logger.warning("No partner found with code: \(code, privacy: .public)")
            return nil
        }
        
        // Don't allow connecting to yourself
        if partnerId == currentUser.id {
            throw NSError(domain: "FirebaseService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot connect to yourself"])
        }
        
        // Check if partner already has a partner
        if let existingPartnerId = partnerDoc.data()["partnerId"] as? String, !existingPartnerId.isEmpty {
            throw NSError(domain: "FirebaseService", code: -4, userInfo: [NSLocalizedDescriptionKey: "This user is already connected to another partner."])
        }
        
        var partner = AppUser(id: partnerId, name: partnerName)
        partner.partnerId = currentUser.id
        partner.partnerCode = partnerDoc.data()["partnerCode"] as? String ?? ""
        
        // Load partner's profile image (but NOT anniversary date - start fresh for new relationship)
        if let profileImageUrl = partnerDoc.data()["profileImageUrl"] as? String {
            partner.profileImageUrl = profileImageUrl
        }
        
        // Clear anniversary date from both users when connecting (start fresh for new relationship)
        // Also clear any existing anniversary date from current user's local state
        var updatedCurrentUser = currentUser
        updatedCurrentUser.anniversaryDate = nil
        
        // Update both users in Firestore with partner IDs and clear anniversary dates
        try await db.collection("users").document(currentUser.id).updateData([
            "partnerId": partner.id,
            "anniversaryDate": NSNull()
        ])
        
        try await db.collection("users").document(partner.id).updateData([
            "partnerId": currentUser.id,
            "anniversaryDate": NSNull()
        ])
        
        // Clear streak data for fresh start (since it's based on content sharing between partners)
        let defaults = sharedDefaults ?? UserDefaults.standard
        defaults.removeObject(forKey: "streakData")
        defaults.synchronize()
        // Update published property to trigger UI refresh
        Task { @MainActor in
            streakData = StreakData()
        }
        
        logger.info("Partner connection established: \(currentUser.id, privacy: .public) <-> \(partner.id, privacy: .public)")
        
        return partner
    }
    
    // Disconnect from partner
    func disconnectPartner(currentUser: AppUser) async throws {
        guard let partnerId = currentUser.partnerId else {
            throw NSError(domain: "FirebaseService", code: -5, userInfo: [NSLocalizedDescriptionKey: "No partner to disconnect"])
        }
        
        // Step 1: Delete all shared content between the two partners
        // Query all content where senderId is either current user or partner
        let contentQuery1 = db.collection("content")
            .whereField("senderId", isEqualTo: currentUser.id)
        
        let contentQuery2 = db.collection("content")
            .whereField("senderId", isEqualTo: partnerId)
        
        let snapshot1 = try await contentQuery1.getDocuments()
        let snapshot2 = try await contentQuery2.getDocuments()
        
        // Collect all content documents to delete
        var contentToDelete: [String] = []
        var imageUrlsToDelete: [String] = []
        
        // Process current user's content
        for doc in snapshot1.documents {
            contentToDelete.append(doc.documentID)
            // Extract image URLs for deletion from Storage
            let data = doc.data()
            if let imageUrl = data["imageUrl"] as? String {
                imageUrlsToDelete.append(imageUrl)
            }
        }
        
        // Process partner's content
        for doc in snapshot2.documents {
            contentToDelete.append(doc.documentID)
            // Extract image URLs for deletion from Storage
            let data = doc.data()
            if let imageUrl = data["imageUrl"] as? String {
                imageUrlsToDelete.append(imageUrl)
            }
        }
        
        // Delete all content documents
        let batch = db.batch()
        for docId in contentToDelete {
            let docRef = db.collection("content").document(docId)
            batch.deleteDocument(docRef)
        }
        try await batch.commit()
        logger.info("Deleted \(contentToDelete.count) content documents")
        
        // Step 2: Delete images from Storage (optional but good practice)
        for imageUrl in imageUrlsToDelete {
            do {
                // Use the Storage URL directly to create a reference
                let ref = storage.reference(forURL: imageUrl)
                try await ref.delete()
                logger.info("Deleted image from Storage: \(imageUrl, privacy: .public)")
            } catch {
                // Log but don't fail - image deletion is best effort
                logger.warning("Failed to delete image from Storage: \(error.localizedDescription, privacy: .public)")
            }
        }
        
        // Step 3: Remove partner ID and anniversary date from both users
        try await db.collection("users").document(currentUser.id).updateData([
            "partnerId": NSNull(),
            "anniversaryDate": NSNull()
        ])
        
        try await db.collection("users").document(partnerId).updateData([
            "partnerId": NSNull(),
            "anniversaryDate": NSNull()
        ])
        
        // Step 4: Clear widget data
        if let defaults = sharedDefaults {
            defaults.removeObject(forKey: "widgetData")
            defaults.synchronize()
        }
        
        // Step 5: Clear local content cache
        clearAllContent()
        
        // Step 6: Clear streak data (since it's based on content sharing between partners)
        let defaults = sharedDefaults ?? UserDefaults.standard
        defaults.removeObject(forKey: "streakData")
        defaults.synchronize()
        // Update published property to trigger UI refresh
        Task { @MainActor in
            streakData = StreakData()
        }
        
        // Step 7: Remove content listener
        contentListener?.remove()
        contentListener = nil
        
        // Step 8: Reload widget to show placeholder
        WidgetCenter.shared.reloadTimelines(ofKind: "LoveWidget")
        
        logger.info("Partner disconnected and all content cleared: \(currentUser.id, privacy: .public) <-> \(partnerId, privacy: .public)")
    }
    
    // MARK: - Content Sharing
    
    func sendContent(_ content: SharedContent) async throws {
        var contentToSave = content
        
        // If there's image data but no URL, upload to Storage first
        if content.contentType == .photo,
           let imageData = content.imageData,
           content.imageUrl == nil {
            // Convert data to UIImage
            guard let uiImage = UIImage(data: imageData) else {
                throw NSError(domain: "FirebaseService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
            }
            
            // Upload to Storage
            let imageUrl = try await uploadImage(uiImage)
            contentToSave.imageUrl = imageUrl
            logger.info("Image uploaded to Storage: \(imageUrl, privacy: .public)")
        }
        
        // If there's drawing data but no URL, upload to Storage
        if content.contentType == .drawing,
           let drawingData = content.drawingData,
           content.imageUrl == nil {
            // Convert data to UIImage
            guard let uiImage = UIImage(data: drawingData) else {
                throw NSError(domain: "FirebaseService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Invalid drawing data"])
            }
            
            // Upload to Storage
            let imageUrl = try await uploadImage(uiImage)
            contentToSave.imageUrl = imageUrl
            logger.info("Drawing uploaded to Storage: \(imageUrl, privacy: .public)")
        }
        
        // Convert SharedContent to Firestore document
        var contentData: [String: Any] = [
            "id": contentToSave.id,
            "senderId": contentToSave.senderId,
            "senderName": contentToSave.senderName,
            "contentType": contentToSave.contentType.rawValue,
            "timestamp": Timestamp(date: contentToSave.timestamp),
            "isRead": contentToSave.isRead
        ]
        
        // Add optional fields (but NOT image/drawing data - too large for Firestore)
        // Validate and sanitize text fields
        if let imageUrl = contentToSave.imageUrl {
            contentData["imageUrl"] = imageUrl
        }
        if let noteText = contentToSave.noteText {
            // Validate note text
            do {
                let validatedNote = try Validation.validateNote(noteText)
                contentData["noteText"] = validatedNote
            } catch {
                logger.error("Invalid note text: \(error.localizedDescription, privacy: .public)")
                throw error
            }
        }
        if let statusEmoji = contentToSave.statusEmoji {
            contentData["statusEmoji"] = statusEmoji
        }
        if let statusText = contentToSave.statusText {
            // Validate and sanitize status text
            if let validatedStatus = Validation.validateStatusText(statusText) {
                contentData["statusText"] = validatedStatus
            }
        }
        if let caption = contentToSave.caption {
            // Validate and sanitize caption
            if let validatedCaption = Validation.validateCaption(caption) {
                contentData["caption"] = validatedCaption
            }
        }
        
        // DO NOT save image/drawing data to Firestore - it's too large
        // Only save URLs, and download images when needed
        
        // Save to Firestore
        try await db.collection("content").document(contentToSave.id).setData(contentData)
        logger.info("Content saved to Firestore: \(contentToSave.id, privacy: .public)")
        
        // Update streak when content is sent
        updateStreak()
        
        // Note: Do NOT update partnerContent or widget here - this is content the USER sent
        // The widget should only show content FROM the partner, not from the user
        // The real-time listener will update the widget when the partner sends content
        
        // Also save locally for offline access (with image data for local caching)
        var allContent = loadAllContent()
        allContent.insert(contentToSave, at: 0)
        saveAllContent(allContent)
    }
    
    // Set up real-time listener for partner content
    func setupContentListener() {
        // Remove existing listener
        contentListener?.remove()
        
        Task {
            do {
                guard let currentUser = Auth.auth().currentUser else { return }
                
                // Get partner ID from current user
                let userDoc = try await db.collection("users").document(currentUser.uid).getDocument()
                guard let partnerId = userDoc.data()?["partnerId"] as? String else {
                    logger.info("No partner connected - not setting up listener")
                    await MainActor.run {
                        partnerContent = nil
                    }
                    return
                }
                
                // Set up real-time listener for partner's latest content
                let query = db.collection("content")
                    .whereField("senderId", isEqualTo: partnerId)
                    .order(by: "timestamp", descending: true)
                    .limit(to: 1)
                
                contentListener = query.addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        self.logger.error("Content listener error: \(error.localizedDescription, privacy: .public)")
                        return
                    }
                    
                    guard let doc = snapshot?.documents.first else {
                        Task { @MainActor in
                            self.partnerContent = nil
                        }
                        return
                    }
                    
                    // Process content asynchronously (can't use await in synchronous closure)
                    Task {
                        do {
                            let content = try await self.documentToSharedContent(doc)
                            await MainActor.run {
                                self.partnerContent = content
                                self.logger.info("Real-time update: New content from \(content.senderName, privacy: .public)")
                                // Update widget
                                self.saveToWidget(content)
                            }
                        } catch {
                            self.logger.error("Error parsing content: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }
                
                logger.info("Real-time content listener set up for partner: \(partnerId, privacy: .public)")
            } catch {
                logger.error("Error setting up content listener: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    // Refresh partner content from Firestore (one-time fetch)
    func refreshPartnerContent() {
        Task {
            do {
                guard let currentUser = Auth.auth().currentUser else { return }
                
                // Get partner ID from current user
                let userDoc = try await db.collection("users").document(currentUser.uid).getDocument()
                guard let partnerId = userDoc.data()?["partnerId"] as? String else {
                    logger.info("No partner connected")
                    await MainActor.run {
                        partnerContent = nil
                    }
                    return
                }
                
                // Query latest content from partner
                let query = db.collection("content")
                    .whereField("senderId", isEqualTo: partnerId)
                    .order(by: "timestamp", descending: true)
                    .limit(to: 1)
                
                let snapshot = try await query.getDocuments()
                
                if let doc = snapshot.documents.first {
                    let content = try await documentToSharedContent(doc)
                    await MainActor.run {
                        partnerContent = content
                        logger.info("Refreshed partner content: \(content.senderName, privacy: .public)")
                        // Update widget with partner's content
        saveToWidget(content)
                    }
                } else {
                    await MainActor.run {
                        partnerContent = nil
                    }
                }
            } catch {
                logger.error("Error refreshing partner content: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    // Helper to convert Firestore document to SharedContent
    private func documentToSharedContent(_ doc: QueryDocumentSnapshot) async throws -> SharedContent {
        let data = doc.data()
        
        guard let senderId = data["senderId"] as? String,
              let senderName = data["senderName"] as? String,
              let contentTypeString = data["contentType"] as? String,
              let contentType = ContentType(rawValue: contentTypeString),
              let timestampValue = data["timestamp"] as? Timestamp else {
            throw NSError(domain: "FirebaseService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid content data"])
        }
        
        let timestamp = timestampValue.dateValue()
        
        var content = SharedContent(
            id: data["id"] as? String ?? doc.documentID,
            senderId: senderId,
            senderName: senderName,
            contentType: contentType
        )
        content.timestamp = timestamp
        content.isRead = data["isRead"] as? Bool ?? false
        content.imageUrl = data["imageUrl"] as? String
        content.noteText = data["noteText"] as? String
        content.statusEmoji = data["statusEmoji"] as? String
        content.statusText = data["statusText"] as? String
        content.caption = data["caption"] as? String
        
        // Download image from Storage if URL is present
        if let imageUrl = content.imageUrl, !imageUrl.isEmpty {
            do {
                if let downloadedImage = try await downloadImage(from: imageUrl),
                   let imageData = downloadedImage.jpegData(compressionQuality: 0.7) {
                    // Set image data on content based on content type
                    if content.contentType == .drawing {
                        // For drawings, store in drawingData
                        content.drawingData = imageData
                        // Also set imageData for widget compatibility
                        content.imageData = imageData
                    } else {
                        // For photos, store in imageData
                        content.imageData = imageData
                    }
                    
                    // Also update local cache
                    var allContent = loadAllContent()
                    if let index = allContent.firstIndex(where: { $0.id == content.id }) {
                        if content.contentType == .drawing {
                            allContent[index].drawingData = imageData
                        }
                        allContent[index].imageData = imageData
                        saveAllContent(allContent)
                    } else {
                        // Content not in cache yet, add it
                        allContent.insert(content, at: 0)
                        saveAllContent(allContent)
                    }
                }
            } catch {
                logger.error("Failed to download image: \(error.localizedDescription, privacy: .public)")
            }
        }
        
        return content
    }
    
    // MARK: - Streak Management
    
    func getStreak() -> StreakData {
        let defaults = sharedDefaults ?? UserDefaults.standard
        
        guard let data = defaults.data(forKey: "streakData"),
              let streak = try? JSONDecoder().decode(StreakData.self, from: data) else {
            return StreakData()
        }
        
        // Check if streak should be reset (missed a day)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastDate = streak.lastStreakDate {
            let lastStreakDay = calendar.startOfDay(for: lastDate)
            let daysSince = calendar.dateComponents([.day], from: lastStreakDay, to: today).day ?? 0
            
            // If more than 1 day has passed, reset streak
            if daysSince > 1 {
                var resetStreak = StreakData()
                resetStreak.longestStreak = max(streak.longestStreak, streak.currentStreak)
                saveStreak(resetStreak)
                return resetStreak
            }
        }
        
        return streak
    }
    
    // Get streak and update published property
    private func refreshStreak() {
        streakData = getStreak()
    }
    
    private func updateStreak() {
        var streak = getStreak()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastDate = streak.lastStreakDate {
            let lastStreakDay = calendar.startOfDay(for: lastDate)
            let daysSince = calendar.dateComponents([.day], from: lastStreakDay, to: today).day ?? 0
            
            if daysSince == 0 {
                // Already sent today, don't increment
                return
            } else if daysSince == 1 {
                // Consecutive day, increment streak
                streak.currentStreak += 1
            } else {
                // Missed a day, reset streak
                streak.longestStreak = max(streak.longestStreak, streak.currentStreak)
                streak.currentStreak = 1
            }
        } else {
            // First time sending, start streak
            streak.currentStreak = 1
        }
        
        streak.lastStreakDate = today
        streak.longestStreak = max(streak.longestStreak, streak.currentStreak)
        saveStreak(streak)
        // Update published property to trigger UI refresh
        Task { @MainActor in
            streakData = streak
        }
    }
    
    private func saveStreak(_ streak: StreakData) {
        let defaults = sharedDefaults ?? UserDefaults.standard
        
        if let data = try? JSONEncoder().encode(streak) {
            defaults.set(data, forKey: "streakData")
        }
    }
    
    func fetchPartnerContent() async throws -> [SharedContent] {
        guard let currentUser = Auth.auth().currentUser else {
            return []
        }
        
        // Get partner ID
        let userDoc = try await db.collection("users").document(currentUser.uid).getDocument()
        guard let partnerId = userDoc.data()?["partnerId"] as? String else {
            return []
        }
        
        // Query Firestore for partner's content
        let query = db.collection("content")
            .whereField("senderId", isEqualTo: partnerId)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
        
        let snapshot = try await query.getDocuments()
        var content: [SharedContent] = []
        
        for doc in snapshot.documents {
            if let sharedContent = try? await documentToSharedContent(doc) {
                content.append(sharedContent)
            }
        }
        
        return content
    }
    
    func getLatestPartnerContent() -> SharedContent? {
        return partnerContent
    }
    
    // MARK: - Memories/Collage
    
    func fetchMemories(for monthYear: String) async throws -> [SharedContent] {
        guard let currentUser = Auth.auth().currentUser else {
            logger.warning("fetchMemories: No authenticated user")
            return []
        }
        
        // Get partner ID
        let userDoc = try await db.collection("users").document(currentUser.uid).getDocument()
        guard let partnerId = userDoc.data()?["partnerId"] as? String else {
            logger.warning("fetchMemories: No partner connected")
            return []
        }
        
        // Parse month and year - monthYear is in "yyyy-MM" format (e.g., "2026-02")
        let components = monthYear.split(separator: "-")
        guard components.count == 2,
              let year = Int(components[0]),
              let month = Int(components[1]) else {
            logger.error("fetchMemories: Failed to parse monthYear '\(monthYear, privacy: .public)' - expected format 'yyyy-MM'")
            return []
        }
        
        let calendar = Calendar.current
        guard let startDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) else {
            logger.error("fetchMemories: Failed to create date range for monthYear '\(monthYear, privacy: .public)'")
            return []
        }
        
        logger.info("fetchMemories: Querying content from \(currentUser.uid, privacy: .public) and partner \(partnerId, privacy: .public) for \(monthYear, privacy: .public)")
        
        // Query content from both users in this month
        let query = db.collection("content")
            .whereField("senderId", in: [currentUser.uid, partnerId])
            .whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("timestamp", isLessThan: Timestamp(date: endDate))
            .order(by: "timestamp", descending: true)
        
        let snapshot = try await query.getDocuments()
        logger.info("fetchMemories: Found \(snapshot.documents.count) documents in Firestore")
        
        var content: [SharedContent] = []
        
        for doc in snapshot.documents {
            do {
                let sharedContent = try await documentToSharedContent(doc)
                content.append(sharedContent)
            } catch {
                logger.error("fetchMemories: Failed to convert document \(doc.documentID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        
        logger.info("fetchMemories: Successfully loaded \(content.count) memories")
        return content
    }
    
    func generateCollage(for monthYear: String) async throws -> Memory {
        let content = try await fetchMemories(for: monthYear)
        let photos = content.filter { $0.contentType == .photo }
        let notes = content.filter { $0.contentType == .note || $0.contentType == .drawing }
        let statuses = content.filter { $0.contentType == .status }
        
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        return Memory(
            id: UUID().uuidString,
            coupleId: currentUser.uid,
            monthYear: monthYear,
            photoUrls: photos.compactMap { $0.imageUrl },
            noteCount: notes.count,
            statusCount: statuses.count,
            createdAt: Date(),
            title: "Our memories from \(monthYear)"
        )
    }
    
    // MARK: - Local Storage (for offline caching)
    
    private func loadAllContent() -> [SharedContent] {
        let defaults = sharedDefaults ?? UserDefaults.standard
        
        guard let data = defaults.data(forKey: contentKey),
              let content = try? JSONDecoder().decode([SharedContent].self, from: data) else {
            return []
        }
        return content
    }
    
    private func saveAllContent(_ content: [SharedContent]) {
        let defaults = sharedDefaults ?? UserDefaults.standard
        
        if let data = try? JSONEncoder().encode(content) {
            defaults.set(data, forKey: contentKey)
        }
    }
    
    private func loadLocalContent() {
        // Load from local cache as fallback
        let content = loadAllContent()
        let realContent = content.filter { $0.senderId != "partner" }
        partnerContent = realContent.first
    }
    
    // Clear all content (useful when switching users or starting fresh)
    func clearAllContent() {
        let defaults = sharedDefaults ?? UserDefaults.standard
        defaults.removeObject(forKey: contentKey)
        defaults.removeObject(forKey: partnerContentKey)
        partnerContent = nil
    }
    
    // MARK: - Widget Support
    
    private func saveToWidget(_ content: SharedContent) {
        // CRITICAL: Widget extension can ONLY read from App Group UserDefaults
        // If App Group is not configured, widget will never see the data
        guard let defaults = sharedDefaults else {
            logger.error("App Group not configured - widget data cannot be saved!")
            return
        }
        
        // For notes, we want to show the partner's profile picture
        // For drawings/photos, use the content's image data
        var sourceImageData: Data? = nil
        
        if content.contentType == .note {
            // For notes, fetch partner's profile image asynchronously
            Task {
                do {
                    var profileImageData: Data? = nil
                    if let imageData = try await fetchPartnerProfileImage(for: content.senderId) {
                        profileImageData = imageData
                    }
                    // Save widget data with profile image (or nil if not available)
                    await saveWidgetDataWithImage(content: content, imageData: profileImageData)
                } catch {
                    logger.error("Failed to fetch partner profile image for widget: \(error.localizedDescription, privacy: .public)")
                    // Save without image on error
                    await saveWidgetDataWithImage(content: content, imageData: nil)
                }
            }
            return // Will be saved asynchronously
        } else {
            // For photos/drawings, use the content's image data
            sourceImageData = content.contentType == .drawing ? content.drawingData : content.imageData
        }
        
        // Process image data synchronously for photos/drawings
        var compressedImageData: Data? = nil
        if let imageData = sourceImageData,
           let uiImage = UIImage(data: imageData) {
            
            // Resize image to max 800x800 for widget (much smaller file size)
            let maxDimension: CGFloat = 800
            var resizedImage = uiImage
            
            if uiImage.size.width > maxDimension || uiImage.size.height > maxDimension {
                let scale = min(maxDimension / uiImage.size.width, maxDimension / uiImage.size.height)
                let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
                
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                uiImage.draw(in: CGRect(origin: .zero, size: newSize))
                if let resized = UIGraphicsGetImageFromCurrentImageContext() {
                    resizedImage = resized
                }
                UIGraphicsEndImageContext()
            }
            
            // Compress with aggressive quality for widget (target <300KB)
            compressedImageData = resizedImage.jpegData(compressionQuality: 0.4)
            
            // If still too large, compress even more aggressively
            if let compressed = compressedImageData, compressed.count > 300_000 {
                compressedImageData = resizedImage.jpegData(compressionQuality: 0.2)
            }
            
            // Final check - if still too large, resize even smaller
            if let compressed = compressedImageData, compressed.count > 500_000 {
                let smallerDimension: CGFloat = 600
                let scale = min(smallerDimension / resizedImage.size.width, smallerDimension / resizedImage.size.height)
                let newSize = CGSize(width: resizedImage.size.width * scale, height: resizedImage.size.height * scale)
                
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                resizedImage.draw(in: CGRect(origin: .zero, size: newSize))
                if let smaller = UIGraphicsGetImageFromCurrentImageContext() {
                    compressedImageData = smaller.jpegData(compressionQuality: 0.3)
                }
                UIGraphicsEndImageContext()
            }
            
            if let final = compressedImageData {
                let sizeKB = Double(final.count) / 1024.0
                logger.info("Image compressed for widget: \(String(format: "%.1f", sizeKB))KB (original: \(String(format: "%.1f", Double(imageData.count) / 1024.0))KB)")
            }
        }
        
        // Save widget data using shared helper
        saveWidgetData(content: content, imageData: compressedImageData)
    }
    
    // Helper function to save widget data with image (called async for notes)
    @MainActor
    private func saveWidgetDataWithImage(content: SharedContent, imageData: Data?) async {
        // Compress partner profile image for widget
        var compressedImageData: Data? = nil
        if let imageData = imageData,
           let uiImage = UIImage(data: imageData) {
            // Resize and compress profile image (smaller for profile pictures)
            let maxDimension: CGFloat = 200
            var resizedImage = uiImage
            
            if uiImage.size.width > maxDimension || uiImage.size.height > maxDimension {
                let scale = min(maxDimension / uiImage.size.width, maxDimension / uiImage.size.height)
                let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
                
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                uiImage.draw(in: CGRect(origin: .zero, size: newSize))
                if let resized = UIGraphicsGetImageFromCurrentImageContext() {
                    resizedImage = resized
                }
                UIGraphicsEndImageContext()
            }
            
            compressedImageData = resizedImage.jpegData(compressionQuality: 0.6)
        }
        
        // Save widget data
        saveWidgetData(content: content, imageData: compressedImageData)
    }
    
    // Fetch partner's profile image from Firestore
    private func fetchPartnerProfileImage(for senderId: String) async throws -> Data? {
        // Get partner's user document
        let partnerDoc = try await db.collection("users").document(senderId).getDocument()
        guard let partnerData = partnerDoc.data(),
              let profileImageUrl = partnerData["profileImageUrl"] as? String,
              let url = URL(string: profileImageUrl) else {
            return nil
        }
        
        // Download the image
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    
    // Save widget data to UserDefaults (shared helper)
    private func saveWidgetData(content: SharedContent, imageData: Data?) {
        guard let defaults = sharedDefaults else {
            logger.error("App Group not configured - widget data cannot be saved!")
            return
        }
        
        let widgetData = WidgetData(
            contentType: content.contentType,
            imageData: imageData,
            noteText: content.noteText,
            statusEmoji: content.statusEmoji,
            statusText: content.statusText,
            caption: content.caption,
            senderName: content.senderName,
            timestamp: content.timestamp
        )
        
        if let data = try? JSONEncoder().encode(widgetData) {
            let dataSizeMB = Double(data.count) / 1024.0 / 1024.0
            let imageSizeKB = imageData != nil ? Double(imageData!.count) / 1024.0 : 0
            
            if data.count > 1_000_000 {
                logger.error("⚠️ Widget data too large: \(String(format: "%.2f", dataSizeMB))MB - UserDefaults may reject this!")
            }
            
            defaults.set(data, forKey: "widgetData")
            let syncSuccess = defaults.synchronize()
            
            let textContent = content.caption ?? content.statusText ?? content.noteText ?? "nil"
            logger.info("Widget data saved - contentType: \(content.contentType.rawValue, privacy: .public), hasImageData: \(imageData != nil, privacy: .public), imageSize: \(String(format: "%.1f", imageSizeKB))KB, totalSize: \(String(format: "%.2f", dataSizeMB))MB, syncSuccess: \(syncSuccess), senderName: \(content.senderName, privacy: .public), text: \(textContent, privacy: .public)")
        } else {
            logger.error("Failed to encode widget data")
        }
        
        WidgetCenter.shared.reloadTimelines(ofKind: "LoveWidget")
        logger.info("Widget timeline reloaded for kind: LoveWidget")
    }
    
    func getWidgetData() -> WidgetData {
        let defaults = sharedDefaults ?? UserDefaults.standard
        
        guard let data = defaults.data(forKey: "widgetData"),
              let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return WidgetData.placeholder
        }
        return widgetData
    }
    
    // MARK: - Image Handling
    
    func uploadImage(_ image: UIImage, isProfileImage: Bool = false) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "FirebaseService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let imageId = UUID().uuidString
        // Use profiles/ path for profile images, images/ for content images
        let path = isProfileImage ? "profiles/\(imageId).jpg" : "images/\(imageId).jpg"
        let ref = storage.reference().child(path)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let url = try await ref.downloadURL()
        
        logger.info("Image uploaded to Storage: \(url.absoluteString, privacy: .public), isProfileImage: \(isProfileImage, privacy: .public)")
        return url.absoluteString
    }
    
    func downloadImage(from url: String) async throws -> UIImage? {
        guard url.hasPrefix("http") else {
            // Local URL, try to load from cache
        return nil
    }
        
        let ref = storage.reference(forURL: url)
        let data = try await ref.data(maxSize: 10 * 1024 * 1024) // 10MB max
        return UIImage(data: data)
    }
}
