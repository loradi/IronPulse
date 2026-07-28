import SwiftUI
import SwiftData

struct RoutineTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var catalog: [Exercise]
    @Bindable var profile: UserProfile
    @State private var activeLog: WorkoutLog?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let active = profile.activeRoutine {
                    RoutineCard(routine: active, onStartDay: startWorkout)
                } else {
                    ContentUnavailableView(
                        "Sin rutina activa",
                        systemImage: "bolt.slash",
                        description: Text("Genera una rutina automatica o arma la tuya ejercicio por ejercicio.")
                    )
                }

                VStack(spacing: 12) {
                    Button("Rutina inteligente", action: generateRoutine)
                        .buttonStyle(PrimarySportButtonStyle())

                    NavigationLink {
                        RoutineBuilderView(profile: profile)
                    } label: {
                        Text("Crear rutina manual")
                            .font(.wwHeadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(Color.ironAccent)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.ironAccent, lineWidth: 1.5)
                            }
                    }
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(Color.ironBackground)
        .navigationTitle("Rutina")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(item: $activeLog) { log in
            ActiveWorkoutView(log: log)
        }
    }

    private func generateRoutine() {
        guard !catalog.isEmpty else { return }
        let routine = WorkoutGeneratorService.generateRoutine(for: profile, catalog: catalog)
        profile.activate(routine, in: modelContext)
    }

    private func startWorkout(_ day: RoutineDay) {
        guard let routine = profile.activeRoutine else { return }
        activeLog = WorkoutLogGenerator.startSession(for: day, routineName: routine.name, profile: profile, in: modelContext)
    }
}

private struct RoutineCard: View {
    let routine: WorkoutRoutine
    let onStartDay: (RoutineDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading) {
                Text(routine.name).font(.wwHeadline)
                Text("\(diasLabel(routine.days.count)) · \(routine.splitType.displayName)")
                    .font(.wwCaption)
                    .foregroundStyle(Color.ironTextSecondary)
            }

            ForEach(routine.days.sorted { $0.dayNumber < $1.dayNumber }) { day in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(day.title).font(.wwBody).bold()
                        Spacer()
                        Button("Empezar") { onStartDay(day) }
                            .font(.wwCaption.weight(.bold))
                            .foregroundStyle(Color.ironAccent)
                    }
                    ForEach(day.exercises.sorted { $0.orderIndex < $1.orderIndex }) { ex in
                        NavigationLink {
                            ExerciseDetailView(exercise: ex.exercise)
                        } label: {
                            HStack {
                                Text(ex.exercise.name).font(.wwCaption)
                                Spacer()
                                Text("\(ex.targetSets)x\(ex.targetRepsMin)-\(ex.targetRepsMax)")
                                    .font(.wwCaption)
                                    .foregroundStyle(Color.ironTextSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .ironCard()
    }
}

struct RoutineTabView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Rutina")
            .preferredColorScheme(.dark)
    }
}
