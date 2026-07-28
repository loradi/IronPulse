import SwiftUI
import UIKit

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
    var photoData: Data? = nil
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.ironAccent, lineWidth: 2))
            } else {
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
    }
}
