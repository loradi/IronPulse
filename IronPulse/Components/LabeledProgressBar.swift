import SwiftUI

struct LabeledProgressBar: View {
    let label: String
    let valueText: String
    /// 0...1
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(label.uppercased())
                    .font(.wwLabelCaps)
                    .foregroundStyle(Color.ironTextSecondary)
                Spacer()
                Text(valueText)
                    .font(.wwDataMono(14))
                    .foregroundStyle(Color.ironAccent)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.ironCardElevated)
                    Capsule()
                        .fill(Color.ironAccent)
                        .frame(width: geometry.size.width * min(max(progress, 0), 1))
                }
            }
            .frame(height: 8)
        }
    }
}
