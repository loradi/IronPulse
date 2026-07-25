import SwiftUI

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

    static let ironBackground = Color(hex: "09090B")
    static let ironSurface = Color(hex: "18181B")
    static let ironBorder = Color(hex: "27272A")
    static let ironPrimary = Color(hex: "FF1E27")
    static let ironSecondary = Color(hex: "B91C1C")
    static let ironTextSecondary = Color(hex: "A1A1AA")
    static let ironLightBackground = Color(hex: "F4F4F6")
    static let ironLightBorder = Color(hex: "E4E4E7")
    static let ironLightPrimary = Color(hex: "D3121B")
}

struct IronCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(colorScheme == .dark ? Color.ironSurface : .white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.ironBorder : Color.ironLightBorder, lineWidth: 1)
            }
    }
}

extension View {
    func ironCard() -> some View {
        modifier(IronCardModifier())
    }

    func redGlow(active: Bool = true) -> some View {
        shadow(color: active ? Color.ironPrimary.opacity(0.38) : .clear, radius: active ? 18 : 0, x: 0, y: 0)
    }
}

struct PrimarySportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.black))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.ironPrimary.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .redGlow(active: !configuration.isPressed)
    }
}
