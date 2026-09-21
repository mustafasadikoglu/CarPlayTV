import SwiftUI

// MARK: - Liquid Glass Theme & Design Tokens

public struct LiquidGlassBackground: View {
    public init() {}

    public var body: some View {
        ZStack {
            // Deep obsidian base
            Color(red: 0.05, green: 0.06, blue: 0.09)
                .ignoresSafeArea()

            // Subtle top aurora glow (ambient teal/indigo)
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.12, green: 0.20, blue: 0.35).opacity(0.45),
                    Color.clear
                ]),
                center: .topLeading,
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()

            // Subtle bottom-trailing magenta/violet glow
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.30, green: 0.10, blue: 0.28).opacity(0.35),
                    Color.clear
                ]),
                center: .bottomTrailing,
                startRadius: 60,
                endRadius: 500
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Liquid Glass View Modifiers

public struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var strokeOpacity: Double
    var shadowRadius: CGFloat
    var shadowOpacity: Double

    public func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(strokeOpacity),
                                Color.white.opacity(strokeOpacity * 0.3),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowRadius / 2.5)
    }
}

public struct LiquidGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var isSelected: Bool
    var activeColor: Color

    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    if isSelected {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(activeColor.opacity(0.18))
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isSelected
                            ? LinearGradient(
                                colors: [activeColor.opacity(0.8), activeColor.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(
                color: isSelected ? activeColor.opacity(0.35) : Color.black.opacity(0.25),
                radius: isSelected ? 12 : 8,
                x: 0,
                y: 4
            )
    }
}

public extension View {
    func liquidGlass(
        cornerRadius: CGFloat = 20,
        strokeOpacity: Double = 0.3,
        shadowRadius: CGFloat = 12,
        shadowOpacity: Double = 0.35
    ) -> some View {
        modifier(LiquidGlassModifier(
            cornerRadius: cornerRadius,
            strokeOpacity: strokeOpacity,
            shadowRadius: shadowRadius,
            shadowOpacity: shadowOpacity
        ))
    }

    func liquidGlassCard(
        cornerRadius: CGFloat = 16,
        isSelected: Bool = false,
        activeColor: Color = .accentColor
    ) -> some View {
        modifier(LiquidGlassCardModifier(
            cornerRadius: cornerRadius,
            isSelected: isSelected,
            activeColor: activeColor
        ))
    }
}

// MARK: - Accessible, Large Touch Target Glass Button Styles

public struct LiquidGlassButtonStyle: ButtonStyle {
    var isPrimary: Bool
    var activeColor: Color
    var minHeight: CGFloat

    public init(isPrimary: Bool = false, activeColor: Color = .accentColor, minHeight: CGFloat = 52) {
        self.isPrimary = isPrimary
        self.activeColor = activeColor
        self.minHeight = minHeight
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(
                ZStack {
                    if isPrimary {
                        LinearGradient(
                            colors: [activeColor, activeColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.white.opacity(0.12)
                    }
                }
            )
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isPrimary ? 0.45 : 0.25),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isPrimary ? activeColor.opacity(0.4) : Color.black.opacity(0.3),
                radius: 10,
                x: 0,
                y: 5
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

public struct LiquidGlassOrbButtonStyle: ButtonStyle {
    var size: CGFloat
    var isPrimary: Bool
    var activeColor: Color

    public init(size: CGFloat = 48, isPrimary: Bool = false, activeColor: Color = .accentColor) {
        self.size = size
        self.isPrimary = isPrimary
        self.activeColor = activeColor
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(
                ZStack {
                    if isPrimary {
                        LinearGradient(
                            colors: [activeColor, activeColor.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.white.opacity(0.12)
                    }
                }
            )
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isPrimary ? 0.5 : 0.3),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(
                color: isPrimary ? activeColor.opacity(0.45) : Color.black.opacity(0.35),
                radius: size * 0.18,
                x: 0,
                y: size * 0.08
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
