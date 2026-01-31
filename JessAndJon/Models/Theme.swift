import SwiftUI

// MARK: - Color Theme
struct AppTheme {
    // Primary gradient colors - soft pink to purple
    static let gradientStart = Color(hex: "FFB6C1") // Light pink
    static let gradientMid = Color(hex: "DDA0DD") // Plum
    static let gradientEnd = Color(hex: "9370DB") // Medium purple
    
    // Accent colors
    static let accentPink = Color(hex: "FF69B4") // Hot pink
    static let accentPurple = Color(hex: "8A2BE2") // Blue violet
    static let softPink = Color(hex: "FFC0CB") // Pink
    static let lavender = Color(hex: "E6E6FA") // Lavender
    static let blush = Color(hex: "FFE4E1") // Misty rose
    
    // Text colors
    static let textPrimary = Color(hex: "4A4A4A")
    static let textSecondary = Color(hex: "7A7A7A")
    static let textOnGradient = Color.white
    
    // Background colors
    static let backgroundPrimary = Color(hex: "FFF5F7")
    static let backgroundCard = Color.white.opacity(0.9)
    static let backgroundDark = Color(hex: "2D1B3D")
    
    // Heart colors for animations
    static let heartPink = Color(hex: "FF6B9D")
    static let heartRed = Color(hex: "FF4757")
    
    // Gradients
    static let mainGradient = LinearGradient(
        colors: [gradientStart, gradientMid, gradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let softGradient = LinearGradient(
        colors: [softPink.opacity(0.3), lavender.opacity(0.3)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let cardGradient = LinearGradient(
        colors: [Color.white, blush.opacity(0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let buttonGradient = LinearGradient(
        colors: [accentPink, accentPurple],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let sunsetGradient = LinearGradient(
        colors: [
            Color(hex: "FFB6C1"),
            Color(hex: "FFA07A"),
            Color(hex: "DDA0DD")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Custom Font Styles
extension Font {
    static let appTitle = Font.system(size: 32, weight: .bold, design: .rounded)
    static let appHeadline = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let appSubheadline = Font.system(size: 18, weight: .medium, design: .rounded)
    static let appBody = Font.system(size: 16, weight: .regular, design: .rounded)
    static let appCaption = Font.system(size: 14, weight: .regular, design: .rounded)
    static let appButton = Font.system(size: 17, weight: .semibold, design: .rounded)
}

// MARK: - View Modifiers
struct GlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(AppTheme.backgroundCard)
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: AppTheme.accentPink.opacity(0.15), radius: 15, x: 0, y: 5)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appButton)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(AppTheme.buttonGradient)
                    .shadow(color: AppTheme.accentPink.opacity(0.4), radius: 10, x: 0, y: 5)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appButton)
            .foregroundColor(AppTheme.accentPurple)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .stroke(AppTheme.buttonGradient, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

extension View {
    func glassBackground() -> some View {
        modifier(GlassBackground())
    }
    
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
