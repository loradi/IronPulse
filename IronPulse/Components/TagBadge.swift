import SwiftUI

struct TagBadge: View {
    let text: String
    var color: Color = .ironAccent

    var body: some View {
        Text(text.uppercased())
            .font(.wwLabelCaps)
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 4)
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.chip, style: .continuous)
                    .stroke(color, lineWidth: 1)
            }
    }
}
