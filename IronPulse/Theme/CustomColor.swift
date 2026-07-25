import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        let sanitizedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitizedHex).scanHexInt64(&value)

        let alpha: UInt64
        let red: UInt64
        let green: UInt64
        let blue: UInt64

        switch sanitizedHex.count {
        case 3:
            alpha = 255
            red = (value >> 8) * 17
            green = (value >> 4 & 0xF) * 17
            blue = (value & 0xF) * 17
        case 6:
            alpha = 255
            red = value >> 16
            green = value >> 8 & 0xFF
            blue = value & 0xFF
        case 8:
            alpha = value >> 24
            red = value >> 16 & 0xFF
            green = value >> 8 & 0xFF
            blue = value & 0xFF
        default:
            alpha = 255
            red = 0
            green = 0
            blue = 0
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }

    private static func dynamic(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
    }

    static let neonGreen = Color(hex: "00FF66")
    static let neonOrange = Color(hex: "FF3300")
    static let ironAccent = neonGreen
    static let ironDanger = neonOrange

    static let ironBackground = dynamic(light: "F2F4F8", dark: "090C10")
    static let ironCard = dynamic(light: "FFFFFF", dark: "131822")
    // light-mode border wasn't specified in the spec; reuse a neutral light-gray in the same family as ironBackground
    static let ironBorder = dynamic(light: "E4E4E7", dark: "1F2838")
    static let ironTextPrimary = dynamic(light: "0D1117", dark: "F2F4F8")
    static let ironTextSecondary = dynamic(light: "56606E", dark: "8A94A6")
}

extension Font {
    static var ironTitle: Font { .system(.title, design: .rounded).weight(.black) }

    static func metricDisplay(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .rounded).weight(.black).monospacedDigit()
    }
}

enum HapticFeedback {
    static func setCompleted() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func restFinished() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

struct IronCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.ironCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.ironBorder, lineWidth: 1)
            }
    }
}

extension View {
    func ironCard() -> some View {
        modifier(IronCardModifier())
    }

    func neonGlow(color: Color = .ironAccent, active: Bool = true) -> some View {
        shadow(color: active ? color.opacity(0.3) : .clear, radius: active ? 6 : 0)
    }
}

struct PrimarySportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.black))
            // dark text reads better than white on a bright neon-green fill
            .foregroundStyle(Color.ironBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.ironAccent.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .neonGlow(active: !configuration.isPressed)
    }
}
