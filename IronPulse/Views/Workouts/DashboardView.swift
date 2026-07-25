import SwiftUI
import SwiftData

struct DashboardView: View {
    @Bindable var profile: UserProfile

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                if let active = profile.activeRoutine {
                    RoutineCard(routine: active)
                } else {
                    ContentUnavailableView("Sin rutina activa", systemImage: "bolt.slash", description: Text("El generador de rutinas llega en la Fase 3."))
                }
            }
            .padding()
        }
        .navigationTitle(profile.name)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(profile.name).font(.ironTitle)
                Text("\(profile.experienceLevel.displayName) • \(profile.primaryGoal.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(Color.ironTextSecondary)
            }

            Spacer()

            Circle().fill(Color.ironAccent).frame(width: 56, height: 56).neonGlow()
        }
        .ironCard()
    }
}

private struct RoutineCard: View {
    let routine: WorkoutRoutine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading) {
                Text(routine.name).font(.headline)
                Text("\(routine.days.count) dias · \(routine.splitType.displayName)")
                    .font(.caption)
                    .foregroundStyle(Color.ironTextSecondary)
            }

            ForEach(routine.days.sorted { $0.dayNumber < $1.dayNumber }) { day in
                VStack(alignment: .leading, spacing: 6) {
                    Text(day.title).font(.subheadline).bold()
                    ForEach(day.exercises.sorted { $0.orderIndex < $1.orderIndex }) { ex in
                        HStack {
                            Text(ex.exercise.name).font(.caption)
                            Spacer()
                            Text("\(ex.targetSets)x\(ex.targetRepsMin)-\(ex.targetRepsMax)")
                                .font(.caption2)
                                .foregroundStyle(Color.ironTextSecondary)
                        }
                    }
                }
            }
        }
        .ironCard()
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Dashboard")
            .preferredColorScheme(.dark)
    }
}
