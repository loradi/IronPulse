import SwiftUI

func initials(from name: String) -> String {
    let words = name
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .split(separator: " ")
        .prefix(2)

    let letters = words.compactMap { $0.first }
    return letters.isEmpty ? "?" : String(letters).uppercased()
}

struct AvatarPlaceholder: View {
    let name: String
    var size: CGFloat = 56

    var body: some View {
        Circle()
            .fill(Color.ironCardElevated)
            .overlay(Circle().stroke(Color.ironAccent, lineWidth: 2))
            .overlay {
                Text(initials(from: name))
                    .font(.wwHeadline)
                    .foregroundStyle(Color.ironTextPrimary)
            }
            .frame(width: size, height: size)
    }
}
