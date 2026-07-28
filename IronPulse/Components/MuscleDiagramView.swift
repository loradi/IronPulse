import SwiftUI

enum DiagramZone: CaseIterable {
    case shoulders, chest, arms, core, legs
}

private extension MuscleGroup {
    var diagramZone: DiagramZone {
        switch self {
        case .shoulders: return .shoulders
        case .chest, .back: return .chest
        case .arms, .biceps, .triceps: return .arms
        case .core: return .core
        case .legs, .glutes, .calves: return .legs
        case .fullBody: return .chest // no se usa: fullBody se maneja aparte en zones(primary:secondary:)
        }
    }
}

func zones(primary: MuscleGroup, secondary: [MuscleGroup]) -> (highlighted: Set<DiagramZone>, dimmed: Set<DiagramZone>) {
    if primary == .fullBody {
        return (Set(DiagramZone.allCases), [])
    }
    let highlighted: Set<DiagramZone> = [primary.diagramZone]
    let dimmed = Set(secondary.map(\.diagramZone)).subtracting(highlighted)
    return (highlighted, dimmed)
}

struct MuscleDiagramView: View {
    let primary: MuscleGroup
    let secondary: [MuscleGroup]

    private var computed: (highlighted: Set<DiagramZone>, dimmed: Set<DiagramZone>) {
        zones(primary: primary, secondary: secondary)
    }

    private func color(for zone: DiagramZone) -> Color {
        if computed.highlighted.contains(zone) { return .ironAccent }
        if computed.dimmed.contains(zone) { return .ironTextSecondary }
        return .ironBorder
    }

    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(Color.ironBorder)
                .frame(width: 28, height: 28)

            HStack(spacing: 30) {
                Circle().fill(color(for: .shoulders)).frame(width: 16, height: 16)
                Circle().fill(color(for: .shoulders)).frame(width: 16, height: 16)
            }

            HStack(spacing: 4) {
                Capsule().fill(color(for: .arms)).frame(width: 14, height: 90)

                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color(for: .chest))
                        .frame(width: 44, height: 30)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color(for: .core))
                        .frame(width: 38, height: 24)
                }

                Capsule().fill(color(for: .arms)).frame(width: 14, height: 90)
            }

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color(for: .legs))
                    .frame(width: 20, height: 56)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color(for: .legs))
                    .frame(width: 20, height: 56)
            }
        }
        .frame(width: 120, height: 190)
    }
}
