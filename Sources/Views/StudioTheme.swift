import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

struct StudioPalette {
    let isDark: Bool
    let canvasBackground: Color
    let canvasAuraPrimary: Color
    let canvasAuraSecondary: Color
    let cardBackground: Color
    let cardHoverBackground: Color
    let cardBorder: Color
    let cardHoverBorder: Color
    let cardShadow: Color
    let viewportRunningTop: Color
    let viewportRunningBottom: Color
    let viewportStoppedBackground: Color
    let dotMatrixColor: Color
    let terminalBoxBackground: Color
    let terminalBoxBorder: Color
    let terminalHeaderBackground: Color
    let primaryText: Color
    let secondaryText: Color
    let mutedText: Color
    let pillBackground: Color
    let pillBorder: Color
    let divider: Color
    let accentPurple: Color
    let accentBlue: Color
    let accentCyan: Color
    let accentGreen: Color
    let accentAmber: Color
    let accentRed: Color
    let mainGlow: Color
    let activeTaskGlow: Color
    let sheenColor: Color

    static func resolve(theme: AppTheme, systemScheme: ColorScheme) -> StudioPalette {
        switch theme {
        case .dark: return .darkObsidian
        case .light: return .lightFrost
        case .system: return systemScheme == .dark ? .darkObsidian : .lightFrost
        }
    }

    static let darkObsidian = StudioPalette(
        isDark: true,
        canvasBackground: Color(hex: 0x151821),
        canvasAuraPrimary: Color(hex: 0x7C5CFF, alpha: 0.14),
        canvasAuraSecondary: Color(hex: 0x0EA5E9, alpha: 0.08),
        cardBackground: Color(hex: 0x1D202B),
        cardHoverBackground: Color(hex: 0x222634),
        cardBorder: Color.white.opacity(0.08),
        cardHoverBorder: Color.white.opacity(0.18),
        cardShadow: Color.black.opacity(0.36),
        viewportRunningTop: Color(hex: 0x0B0D14),
        viewportRunningBottom: Color(hex: 0x121723),
        viewportStoppedBackground: Color(hex: 0x0D1017),
        dotMatrixColor: Color.white.opacity(0.085),
        terminalBoxBackground: Color(hex: 0x101420),
        terminalBoxBorder: Color.white.opacity(0.09),
        terminalHeaderBackground: Color(hex: 0x151A28),
        primaryText: Color(hex: 0xF3F5FA),
        secondaryText: Color(hex: 0xA4ACC0),
        mutedText: Color(hex: 0x6D768D),
        pillBackground: Color.white.opacity(0.06),
        pillBorder: Color.white.opacity(0.10),
        divider: Color.white.opacity(0.08),
        accentPurple: Color(hex: 0x8B5CF6),
        accentBlue: Color(hex: 0x3B82F6),
        accentCyan: Color(hex: 0x22D3EE),
        accentGreen: Color(hex: 0x34D399),
        accentAmber: Color(hex: 0xFBBF24),
        accentRed: Color(hex: 0xF87171),
        mainGlow: Color(hex: 0x8B5CF6, alpha: 0.50),
        activeTaskGlow: Color(hex: 0x22D3EE, alpha: 0.52),
        sheenColor: Color.white.opacity(0.07)
    )

    static let lightFrost = StudioPalette(
        isDark: false,
        canvasBackground: Color(hex: 0xF3F5F9),
        canvasAuraPrimary: Color(hex: 0x6366F1, alpha: 0.08),
        canvasAuraSecondary: Color(hex: 0x0EA5E9, alpha: 0.06),
        cardBackground: Color(hex: 0xFFFFFF),
        cardHoverBackground: Color(hex: 0xFAFBFD),
        cardBorder: Color(hex: 0x0F172A, alpha: 0.08),
        cardHoverBorder: Color(hex: 0x6366F1, alpha: 0.28),
        cardShadow: Color(hex: 0x0F172A, alpha: 0.07),
        viewportRunningTop: Color(hex: 0xF8FAFC),
        viewportRunningBottom: Color(hex: 0xEEF2F7),
        viewportStoppedBackground: Color(hex: 0xF1F5F9),
        dotMatrixColor: Color(hex: 0x475569, alpha: 0.14),
        terminalBoxBackground: Color(hex: 0xFFFFFF, alpha: 0.92),
        terminalBoxBorder: Color(hex: 0x0F172A, alpha: 0.09),
        terminalHeaderBackground: Color(hex: 0xE8EEF6),
        primaryText: Color(hex: 0x0F172A),
        secondaryText: Color(hex: 0x475569),
        mutedText: Color(hex: 0x64748B),
        pillBackground: Color(hex: 0x0F172A, alpha: 0.045),
        pillBorder: Color(hex: 0x0F172A, alpha: 0.09),
        divider: Color(hex: 0x0F172A, alpha: 0.08),
        accentPurple: Color(hex: 0x7C3AED),
        accentBlue: Color(hex: 0x2563EB),
        accentCyan: Color(hex: 0x0284C7),
        accentGreen: Color(hex: 0x059669),
        accentAmber: Color(hex: 0xD97706),
        accentRed: Color(hex: 0xDC2626),
        mainGlow: Color(hex: 0x7C3AED, alpha: 0.42),
        activeTaskGlow: Color(hex: 0x0EA5E9, alpha: 0.46),
        sheenColor: Color.white.opacity(0.45)
    )

    var mainBadgeGradient: LinearGradient {
        LinearGradient(colors: [accentPurple, accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var primaryGradient: LinearGradient {
        LinearGradient(colors: [accentPurple, accentBlue], startPoint: .leading, endPoint: .trailing)
    }
}

extension View {
    func studioSurface(background: Color, border: Color, radius: CGFloat = 11) -> some View {
        self
            .background(background)
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    func studioCapsule(background: Color, border: Color? = nil, height: CGFloat = 21) -> some View {
        self
            .padding(.horizontal, 7.5)
            .frame(height: height)
            .background(background)
            .overlay(Capsule().strokeBorder(border ?? .clear, lineWidth: border == nil ? 0 : 1))
            .clipShape(Capsule())
    }
}

struct StudioCapsuleButtonStyle: ButtonStyle {
    enum Tone { case primary, secondary, danger, subtle }

    let palette: StudioPalette
    var tone: Tone = .secondary
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let radius: CGFloat = compact ? 8 : 9
        configuration.label
            .font(.system(size: compact ? 11.5 : 12.5, weight: .semibold))
            .foregroundStyle(tone == .primary || tone == .danger ? Color.white : palette.primaryText)
            .padding(.horizontal, compact ? 10 : 13)
            .frame(height: compact ? 27 : 31)
            .background {
                switch tone {
                case .primary: palette.primaryGradient
                case .danger: palette.accentRed
                case .secondary: palette.pillBackground
                case .subtle: Color.clear
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(tone == .secondary ? palette.pillBorder : (tone == .subtle ? palette.divider : Color.white.opacity(0.16)), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
