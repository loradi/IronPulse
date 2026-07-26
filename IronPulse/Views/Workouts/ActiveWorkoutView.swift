import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var log: WorkoutLog
    @Query private var catalog: [Exercise]
    @State private var restRemaining: Int = 0
    @State private var restTask: Task<(), Never>? = nil
    @State private var activeSetID: SetLog.ID?

    private var isReadOnly: Bool { log.endDate != nil }

    private var exerciseNames: [String: String] {
        Dictionary(catalog.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    private var flatSets: [SetLog] {
        log.completedSets.sorted { $0.setIndex < $1.setIndex }
    }

    private var groupedSets: [(exerciseId: String, sets: [SetLog])] {
        let sorted = flatSets
        var order: [String] = []
        var buckets: [String: [SetLog]] = [:]
        for set in sorted {
            if buckets[set.exerciseId] == nil { order.append(set.exerciseId) }
            buckets[set.exerciseId, default: []].append(set)
        }
        return order.map { ($0, buckets[$0]!) }
    }

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text(log.routineName).font(.title2).fontWeight(.black)
                    Text(log.dayTitle).font(.subheadline).foregroundStyle(Color.ironTextSecondary)
                }
                Spacer()
                if isReadOnly {
                    Text("Finalizada").foregroundStyle(Color.ironTextSecondary)
                }
            }
            .padding()

            List {
                ForEach(groupedSets, id: \.exerciseId) { group in
                    Section(exerciseNames[group.exerciseId] ?? group.exerciseId) {
                        ForEach(Array(group.sets.enumerated()), id: \.element.id) { index, set in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Set \(index + 1)").font(.headline)
                                    Spacer()
                                    Text("Meta: \(set.targetRepsMin)-\(set.targetRepsMax)")
                                        .font(.caption)
                                        .foregroundStyle(Color.ironTextSecondary)
                                    Button(action: { toggleCompleted(set) }) {
                                        Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(set.isCompleted ? Color.ironAccent : Color.ironTextSecondary)
                                    }
                                    .disabled(isReadOnly)
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        TextField("Peso", value: bindingForWeight(set), format: .number)
                                            .keyboardType(.decimalPad)
                                            .disabled(isReadOnly)
                                            .frame(width: 60)
                                        Text("kg").font(.caption).foregroundStyle(Color.ironTextSecondary)
                                    }

                                    Spacer()

                                    Stepper("\(set.repsCompleted) reps", value: bindingForReps(set), in: 0...50)
                                        .disabled(isReadOnly)
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background {
                                if set.id == activeSetID {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.ironAccent.opacity(0.12))
                                }
                            }
                            .overlay {
                                if set.id == activeSetID {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.ironAccent, lineWidth: 2)
                                }
                            }
                        }
                    }
                }
            }

            if !isReadOnly {
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
        }
        .navigationTitle("Entrenamiento")
        .task {
            if !isReadOnly {
                await RestNotificationScheduler.requestAuthorizationIfNeeded()
            }
        }
        .onAppear {
            if !isReadOnly && activeSetID == nil {
                activeSetID = flatSets.first?.id
            }
        }
        .onDisappear {
            restTask?.cancel()
        }
    }

    private func bindingForWeight(_ set: SetLog) -> Binding<Double> {
        Binding(get: { set.weightKg }, set: { set.weightKg = $0 })
    }

    private func bindingForReps(_ set: SetLog) -> Binding<Int> {
        Binding(get: { set.repsCompleted }, set: { set.repsCompleted = $0 })
    }

    private func toggleCompleted(_ set: SetLog) {
        set.isCompleted.toggle()
        set.timestamp = Date()
        try? modelContext.save()

        guard set.id == activeSetID, set.isCompleted else { return }
        HapticFeedback.setCompleted()
        let seconds = restSeconds(for: set)
        startRest(seconds: seconds) { advanceToNextSet() }
        RestNotificationScheduler.scheduleRestFinished(in: seconds)
    }

    private func restSeconds(for set: SetLog) -> Int {
        let isCompound = catalog.first { $0.id == set.exerciseId }?.isCompound ?? false
        return GuidedSessionFlow.restSeconds(isCompound: isCompound)
    }

    private func advanceToNextSet() {
        activeSetID = GuidedSessionFlow.nextSetID(after: activeSetID, in: flatSets)
    }

    private func startRest(seconds: Int, onFinished: @escaping () -> Void) {
        restTask?.cancel()
        restRemaining = seconds

        restTask = Task { @MainActor in
            while restRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                restRemaining -= 1
            }
            if !Task.isCancelled {
                HapticFeedback.restFinished()
                RestNotificationScheduler.cancelPending()
                onFinished()
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
