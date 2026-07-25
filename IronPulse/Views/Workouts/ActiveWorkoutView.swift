import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var log: WorkoutLog
    @Query private var catalog: [Exercise]
    @State private var restRemaining: Int = 0
    @State private var restTask: Task<(), Never>? = nil

    private var exerciseNames: [String: String] {
        Dictionary(catalog.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        VStack {
            HStack {
                Text(log.routineName).font(.title2).fontWeight(.black)
                Spacer()
                if log.endDate != nil {
                    Text("Finalizada").foregroundStyle(Color.ironTextSecondary)
                }
            }
            .padding()

            List {
                ForEach(log.completedSets.sorted { $0.setIndex < $1.setIndex }) { set in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(exerciseNames[set.exerciseId] ?? set.exerciseId).font(.headline)
                            Text("Set \(set.setIndex) · \(set.repsCompleted) reps")
                                .font(.caption)
                                .foregroundStyle(Color.ironTextSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            Text(String(format: "%.1fkg", set.weightKg)).font(.subheadline)
                            Button(action: { toggleCompleted(set) }) {
                                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(set.isCompleted ? Color.ironAccent : Color.ironTextSecondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            HStack(spacing: 12) {
                Button("Terminar") {
                    log.endDate = Date()
                    try? modelContext.save()
                }
                .buttonStyle(PrimarySportButtonStyle())

                Spacer()

                if restRemaining > 0 {
                    Text("Descanso: \(restRemaining)s").font(.headline).foregroundStyle(Color.ironAccent)
                }
            }
            .padding()
        }
        .navigationTitle("Entrenamiento")
    }

    private func toggleCompleted(_ set: SetLog) {
        set.isCompleted.toggle()
        set.timestamp = Date()
        try? modelContext.save()

        if set.isCompleted {
            HapticFeedback.setCompleted()
            // ponytail: descanso fijo de 60s; leerlo del RoutineExercise cuando la Fase 5 conecte rutina -> log
            startRest(seconds: 60)
        }
    }

    private func startRest(seconds: Int) {
        restTask?.cancel()
        restRemaining = seconds

        restTask = Task { @MainActor in
            while restRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                restRemaining -= 1
            }
            if !Task.isCancelled {
                HapticFeedback.restFinished()
            }
        }
    }
}

struct ActiveWorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Active Workout")
            .preferredColorScheme(.dark)
    }
}
