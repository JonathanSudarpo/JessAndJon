import WidgetKit
import SwiftUI
import UIKit

// MARK: - Timeline Provider
struct LoveWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LoveWidgetEntry {
        LoveWidgetEntry(date: Date(), widgetData: WidgetData.placeholder)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (LoveWidgetEntry) -> Void) {
        let entry = LoveWidgetEntry(date: Date(), widgetData: loadWidgetData())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<LoveWidgetEntry>) -> Void) {
        let currentDate = Date()
        let widgetData = loadWidgetData()
        // Use current date (or slightly in the past) to ensure entry is immediately valid
        // This ensures the widget updates immediately when reloadTimelines() is called
        let entryDate = currentDate
        let entry = LoveWidgetEntry(date: entryDate, widgetData: widgetData)
        
        // Refresh every 15 minutes as a fallback
        // Primary updates happen via reloadTimelines() when new content arrives
        // This ensures widget updates even if reloadTimelines() is throttled by iOS
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func loadWidgetData() -> WidgetData {
        // Force synchronization to ensure we have the latest data
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.jessandjon.app") else {
            // App Group not configured - return placeholder
            print("⚠️ Widget: App Group not configured")
            return WidgetData.placeholder
        }
        
        // Force synchronization to get latest data
        sharedDefaults.synchronize()
        
        guard let data = sharedDefaults.data(forKey: "widgetData") else {
            // No widget data saved yet - return placeholder
            print("⚠️ Widget: No widget data found in UserDefaults")
            return WidgetData.placeholder
        }
        
        guard let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            // Failed to decode - return placeholder
            print("⚠️ Widget: Failed to decode widget data")
            return WidgetData.placeholder
        }
        
        let textContent = widgetData.caption ?? widgetData.statusText ?? widgetData.noteText ?? "nil"
        let imageSize = widgetData.imageData != nil ? "\(Double(widgetData.imageData!.count) / 1024.0)KB" : "none"
        print("✅ Widget: Loaded data - contentType: \(widgetData.contentType.rawValue), senderName: \(widgetData.senderName), hasImageData: \(widgetData.imageData != nil), imageSize: \(imageSize), text: \(textContent)")
        return widgetData
    }
}

// MARK: - Widget Entry
struct LoveWidgetEntry: TimelineEntry {
    let date: Date
    let widgetData: WidgetData
}

// MARK: - Widget Data Model (copied for Widget Extension)
struct WidgetData: Codable {
    var contentType: ContentType
    var imageData: Data?
    var noteText: String?
    var statusEmoji: String?
    var statusText: String?
    var caption: String?  // For photos
    var senderName: String
    var timestamp: Date
    
    static let placeholder = WidgetData(
        contentType: .status,
        statusEmoji: "💕",
        statusText: "Waiting for love...",
        senderName: "Your Love",
        timestamp: Date()
    )
}

enum ContentType: String, Codable {
    case photo
    case note
    case drawing
    case status
}

// MARK: - Widget View
struct LoveWidgetEntryView: View {
    var entry: LoveWidgetProvider.Entry
    @Environment(\.widgetFamily) var family
    
    // Colors
    private let gradientStart = Color(red: 255/255, green: 182/255, blue: 193/255)
    private let gradientMid = Color(red: 221/255, green: 160/255, blue: 221/255)
    private let gradientEnd = Color(red: 147/255, green: 112/255, blue: 219/255)
    private let heartPink = Color(red: 255/255, green: 107/255, blue: 157/255)
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [gradientStart, gradientMid, gradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Content
            switch family {
            case .systemSmall:
                smallWidget
            case .systemMedium:
                mediumWidget
            case .systemLarge:
                largeWidget
            case .accessoryRectangular:
                lockScreenRectangular
            case .accessoryCircular:
                lockScreenCircular
            case .accessoryInline:
                lockScreenInline
            default:
                smallWidget
            }
        }
    }
    
    // MARK: - Small Widget
    private var smallWidget: some View {
        VStack(spacing: 8) {
            // Emoji or photo thumbnail
            contentIcon
                .frame(width: 50, height: 50)
            
            // Status text or preview
            VStack(spacing: 2) {
                Text(entry.widgetData.caption ?? entry.widgetData.statusText ?? entry.widgetData.noteText ?? "")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text(entry.widgetData.senderName)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(12)
    }
    
    // MARK: - Medium Widget
    private var mediumWidget: some View {
        HStack(spacing: 16) {
            // Left side - content
            contentIcon
                .frame(width: 80, height: 80)
            
            // Right side - text
            VStack(alignment: .leading, spacing: 6) {
                Text("From \(entry.widgetData.senderName)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(entry.widgetData.caption ?? entry.widgetData.statusText ?? entry.widgetData.noteText ?? "")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(3)
                
                Spacer()
                
                Text(timeAgo(from: entry.widgetData.timestamp))
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(16)
    }
    
    // MARK: - Large Widget
    private var largeWidget: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lovance")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("From \(entry.widgetData.senderName)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Text(timeAgo(from: entry.widgetData.timestamp))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Main content
            contentIcon
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            
            // Text
            Text(entry.widgetData.caption ?? entry.widgetData.statusText ?? entry.widgetData.noteText ?? "")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(3)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(20)
    }
    
    // MARK: - Content Icon
    @ViewBuilder
    private var contentIcon: some View {
        switch entry.widgetData.contentType {
        case .photo:
            if let imageData = entry.widgetData.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                photoPlaceholder
            }
        case .drawing:
            // Drawings should show the image like photos
            if let imageData = entry.widgetData.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                    
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
        case .note:
            // For notes, show partner's profile picture if available
            if let imageData = entry.widgetData.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
            } else {
                // Fallback to note icon if no profile picture
            notePlaceholder
            }
        case .status:
            statusEmoji
        }
    }
    
    private var photoPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.2))
            
            Image(systemName: "photo")
                .font(.system(size: 24))
                .foregroundColor(.white)
        }
    }
    
    private var notePlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.2))
            
            Image(systemName: "note.text")
                .font(.system(size: 24))
                .foregroundColor(.white)
        }
    }
    
    private var statusEmoji: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.2))
            
            Text(entry.widgetData.statusEmoji ?? "💕")
                .font(.system(size: family == .systemSmall ? 32 : 48))
        }
    }
    
    // MARK: - Lock Screen Widgets
    private var lockScreenRectangular: some View {
        HStack(spacing: 8) {
            // Emoji or small icon
            Group {
                switch entry.widgetData.contentType {
                case .photo, .drawing:
                    Image(systemName: "photo.fill")
                        .font(.system(size: 14))
                case .note:
                    Image(systemName: "note.text")
                        .font(.system(size: 14))
                case .status:
                    Text(entry.widgetData.statusEmoji ?? "💕")
                        .font(.system(size: 16))
                }
            }
            .foregroundColor(.white)
            
            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.widgetData.caption ?? entry.widgetData.statusText ?? entry.widgetData.noteText ?? "")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("From \(entry.widgetData.senderName)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    private var lockScreenCircular: some View {
        VStack(spacing: 4) {
            // Emoji or icon
            Group {
                switch entry.widgetData.contentType {
                case .photo, .drawing:
                    Image(systemName: "photo.fill")
                        .font(.system(size: 20))
                case .note:
                    Image(systemName: "note.text")
                        .font(.system(size: 20))
                case .status:
                    Text(entry.widgetData.statusEmoji ?? "💕")
                        .font(.system(size: 24))
                }
            }
            .foregroundColor(.white)
            
            // Sender initial
            Text(entry.widgetData.senderName.prefix(1).uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
        }
    }
    
    private var lockScreenInline: some View {
        HStack(spacing: 4) {
            // Emoji
            Text(entry.widgetData.statusEmoji ?? "💕")
                .font(.system(size: 14))
            
            // Text
            Text(entry.widgetData.caption ?? entry.widgetData.statusText ?? entry.widgetData.noteText ?? "New update")
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(.white)
    }
    
    // MARK: - Time Ago Helper
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Widget Configuration
struct LoveWidget: Widget {
    let kind: String = "LoveWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LoveWidgetProvider()) { entry in
            LoveWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [
                            Color(red: 255/255, green: 182/255, blue: 193/255),
                            Color(red: 221/255, green: 160/255, blue: 221/255),
                            Color(red: 147/255, green: 112/255, blue: 219/255)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Love Widget")
        .description("See what your partner is up to 💕")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    LoveWidget()
} timeline: {
    LoveWidgetEntry(
        date: Date(),
        widgetData: WidgetData(
            contentType: .status,
            statusEmoji: "💕",
            statusText: "Missing you",
            senderName: "Jess",
            timestamp: Date()
        )
    )
}

#Preview(as: .systemMedium) {
    LoveWidget()
} timeline: {
    LoveWidgetEntry(
        date: Date(),
        widgetData: WidgetData(
            contentType: .note,
            noteText: "Can't wait to see you tonight! I love you so much 💖",
            senderName: "Jon",
            timestamp: Date().addingTimeInterval(-3600)
        )
    )
}
