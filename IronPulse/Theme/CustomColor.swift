import SwiftUI
import UIKit

func diasLabel(_ count: Int) -> String {
    "\(count) \(count == 1 ? "dia" : "dias")"
}

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

    static let ironAccent = Color(hex: "CAF300")
    static let ironDanger = Color(hex: "FF3300")
    static let neonGreen = ironAccent
    static let neonOrange = ironDanger

    static let ironBackground = Color(hex: "121317")
    static let ironCard = Color(hex: "1E1F23")
    static let ironCardElevated = Color(hex: "292A2E")
    static let ironBorder = Color(hex: "343539")
    static let ironTextPrimary = Color(hex: "E3E2E7")
    static let ironTextSecondary = Color(hex: "9A9E86")
}

enum CornerRadius {
    static let card: CGFloat = 16
    static let button: CGFloat = 16
    static let chip: CGFloat = .infinity
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
}

private struct IronCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.md)
            .background(Color.ironCard)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .stroke(Color.ironBorder, lineWidth: 1)
            }
    }
}

extension View {
    func ironCard() -> some View {
        modifier(IronCardModifier())
    }
}

struct PrimarySportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.wwHeadline)
            .foregroundStyle(Color.ironBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.ironAccent.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button, style: .continuous))
    }
}

extension Font {
    static var wwDisplay: Font { .custom("Inter-ExtraBold", size: 32) }
    static var wwHeadline: Font { .custom("Inter-Bold", size: 24) }
    static var wwTitle3: Font { .custom("Inter-Bold", size: 18) }
    static var wwBody: Font { .custom("Inter-Regular", size: 16) }
    static var wwCaption: Font { .custom("Inter-Regular", size: 13) }
    static var wwLabelCaps: Font { .custom("Inter-Bold", size: 12) }

    static func wwDataMono(_ size: CGFloat = 20) -> Font {
        .custom("JetBrainsMono-Medium", size: size)
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
