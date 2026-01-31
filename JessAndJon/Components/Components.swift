import SwiftUI

// MARK: - Animated Heart Button
struct HeartButton: View {
    let action: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                isAnimating = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimating = false
            }
            
            action()
        }) {
            Image(systemName: "heart.fill")
                .font(.system(size: 24))
                .foregroundStyle(AppTheme.mainGradient)
                .scaleEffect(isAnimating ? 1.3 : 1.0)
        }
    }
}

// MARK: - Loading View
struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(AppTheme.softPink.opacity(0.3), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(AppTheme.buttonGradient, lineWidth: 4)
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            }
            
            Text("Loading...")
                .font(.appCaption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Pulse Animation Modifier
struct PulseAnimation: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .animation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    func pulseAnimation() -> some View {
        modifier(PulseAnimation())
    }
}

// MARK: - Shake Animation Modifier
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * shakesPerUnit),
                y: 0
            )
        )
    }
}

// MARK: - Confetti View
struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    let colors: [Color] = [
        AppTheme.accentPink,
        AppTheme.accentPurple,
        AppTheme.heartPink,
        AppTheme.softPink,
        AppTheme.lavender
    ]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                createParticles(in: geo.size)
                animateParticles(in: geo.size)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func createParticles(in size: CGSize) {
        particles = (0..<50).map { _ in
            ConfettiParticle(
                color: colors.randomElement() ?? .pink,
                size: CGFloat.random(in: 4...12),
                position: CGPoint(x: size.width / 2, y: size.height / 2),
                opacity: 1.0
            )
        }
    }
    
    private func animateParticles(in size: CGSize) {
        for i in particles.indices {
            let delay = Double.random(in: 0...0.5)
            let duration = Double.random(in: 1...2)
            
            withAnimation(.easeOut(duration: duration).delay(delay)) {
                particles[i].position = CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                )
                particles[i].opacity = 0
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var color: Color
    var size: CGFloat
    var position: CGPoint
    var opacity: Double
}

// MARK: - Gradient Text
struct GradientText: View {
    let text: String
    let font: Font
    let gradient: LinearGradient
    
    init(_ text: String, font: Font = .appTitle, gradient: LinearGradient = AppTheme.mainGradient) {
        self.text = text
        self.font = font
        self.gradient = gradient
    }
    
    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(gradient)
    }
}

// MARK: - Animated Checkmark
struct AnimatedCheckmark: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.buttonGradient)
                .frame(width: 80, height: 80)
                .scaleEffect(isAnimating ? 1 : 0)
            
            Image(systemName: "checkmark")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
                .scaleEffect(isAnimating ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Badge View
struct BadgeView: View {
    let count: Int
    
    var body: some View {
        if count > 0 {
            ZStack {
                Circle()
                    .fill(AppTheme.heartRed)
                    .frame(width: 20, height: 20)
                
                Text("\(min(count, 99))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Shimmer Effect
struct ShimmerEffect: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.5),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: isAnimating ? geo.size.width : -geo.size.width * 0.5)
                    .animation(
                        .linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                }
            )
            .clipped()
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}
