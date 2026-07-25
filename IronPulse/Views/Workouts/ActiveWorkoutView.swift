import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    @State private var restRemaining: Int = 0
    @State private var restTimerRunning = false
    @State private var restTask: Task<(), Never>? = nil

    var body: some View {
        VStack {
            HStack {
                Text(session.title).font(.title2).weight(.black)
                Spacer()
                if let ended = session.endedAt {
                    Text("Finalizada").foregroundStyle(.ironTextSecondary)
                }
            }
            .padding()

            List {
                ForEach(session.sets.sorted { $0.setIndex < $1.setIndex }) { set in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(set.exerciseName).font(.headline)
                            Text("Set \(set.setIndex) · RPE \(set.rpe)").font(.caption).foregroundStyle(.ironTextSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            Text(set.weightKg.map { String(format: "%.1fkg", $0) } ?? "--").font(.subheadline)
                            Button(action: { toggleCompleted(set) }) {
                                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(set.isCompleted ? .ironPrimary : .ironTextSecondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            HStack(spacing: 12) {
                Button("Terminar") {
                    session.endedAt = Date()
                    try? modelContext.save()
                }
                .buttonStyle(PrimarySportButtonStyle())

                Spacer()

                if restRemaining > 0 {
                    Text("Descanso: \(restRemaining)s").font(.headline).foregroundStyle(.ironPrimary)
                }
            }
            .padding()
        }
        .navigationTitle("Entrenamiento")
    }

    private func toggleCompleted(_ set: WorkoutLogSet) {
        set.isCompleted.toggle()
        set.completedAt = set.isCompleted ? Date() : nil
        try? modelContext.save()

        if set.isCompleted {
            startRest(seconds: set.session?.sets.first?.session?.sets.first?.session == nil ? 60 : 60)
        }
    }

    private func startRest(seconds: Int) {
        restTask?.cancel()
        restRemaining = seconds
        restTimerRunning = true

        restTask = Task { @MainActor in
            while restRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                restRemaining -= 1
            }
            restTimerRunning = false
        }
    }
}

struct ActiveWorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Active Workout")
            .preferredColorScheme(.dark)
    }
}
