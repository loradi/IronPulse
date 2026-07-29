import SwiftUI
import SwiftData

struct GuidedWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var log: WorkoutLog
    let catalog: [Exercise]

    @State private var currentExerciseIndex: Int = 0
    @State private var activeSetID: SetLog.ID?
    @State private var setPhase: SetPhase = .idle
    @State private var elapsedSetSeconds: Int = 0
    @State private var restRemaining: Int = 0
    @State private var timerTask: Task<(), Never>? = nil
    @State private var isShowingExerciseInfo = false

    private var groups: [(exerciseId: String, sets: [SetLog])] {
        GuidedSessionFlow.groupedSets(log.completedSets)
    }

    private var currentGroup: (exerciseId: String, sets: [SetLog])? {
        guard groups.indices.contains(currentExerciseIndex) else { return nil }
        return groups[currentExerciseIndex]
    }

    private var currentExercise: Exercise? {
        guard let currentGroup else { return nil }
        return catalog.first { $0.id == currentGroup.exerciseId }
    }

    private var activeSet: SetLog? {
        guard let currentGroup else { return nil }
        return currentGroup.sets.first { $0.id == activeSetID } ?? currentGroup.sets.first
    }

    var body: some View {
        VStack(spacing: 16) {
            if let currentGroup, let exercise = currentExercise {
                Text(exercise.name).font(.wwHeadline).padding(.top)

                List {
                    ForEach(Array(currentGroup.sets.enumerated()), id: \.element.id) { index, set in
                        setRow(set: set, index: index)
                    }
                    Button {
                        addSet(to: currentGroup.exerciseId)
                    } label: {
                        Label(addSetLabel, systemImage: "plus")
                    }
                }

                if let set = activeSet {
                    controls(for: set)
                        .padding()
                }
            } else {
                ContentUnavailableView(
                    noExercisesLabel,
                    systemImage: "checkmark.circle"
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image("wwLogoMark")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                    Text("Entrenamiento").font(.wwHeadline)
                }
            }
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button {
                    goToPreviousExercise()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentExerciseIndex == 0)

                Button {
                    goToNextExercise()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentExerciseIndex >= groups.count - 1)
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    isShowingExerciseInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
                Button(finishLabel) {
                    finishSession()
                }
            }
        }
        .sheet(isPresented: $isShowingExerciseInfo) {
            if let exercise = currentExercise {
                NavigationStack {
                    ExerciseDetailView(exercise: exercise)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(closeLabel) {
                                    isShowingExerciseInfo = false
                                }
                            }
                        }
                }
            }
        }
        .task {
            await RestNotificationScheduler.requestAuthorizationIfNeeded()
        }
        .onAppear {
            selectFirstIncompleteSet()
        }
        .onDisappear {
            timerTask?.cancel()
        }
    }

    private func setRow(set: SetLog, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Set \(index + 1)").font(.wwHeadline)
                Spacer()
                Text("Meta: \(set.targetRepsMin)-\(set.targetRepsMax)")
                    .font(.wwCaption)
                    .foregroundStyle(Color.ironTextSecondary)
                if set.isCompleted {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.ironAccent)
                }
            }

            HStack {
                HStack(spacing: 4) {
                    TextField("Peso", value: bindingForWeight(set), format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .frame(width: 60)
                    Text(UnitSystem.current == .metric ? "kg" : "lbs").font(.wwCaption).foregroundStyle(Color.ironTextSecondary)
                }
                Spacer()
                Stepper("\(set.repsCompleted) reps", value: bindingForReps(set), in: 0...50)
            }

            if (currentGroup?.sets.count ?? 0) > 1 {
                Button(role: .destructive) {
                    removeSet(set)
                } label: {
                    Label(removeSetLabel, systemImage: "trash")
                }
                .font(.wwCaption)
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
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func controls(for set: SetLog) -> some View {
        switch setPhase {
        case .idle:
            Button(startSetLabel) {
                startSet()
            }
            .buttonStyle(PrimarySportButtonStyle())
        case .runningSet:
            VStack(spacing: 8) {
                Text(elapsedLabel(elapsedSetSeconds)).font(.wwHeadline).foregroundStyle(Color.ironAccent)
                Button(finishSetLabel) {
                    finishSet(set)
                }
                .buttonStyle(PrimarySportButtonStyle())
                .disabled(!GuidedSessionFlow.canCompleteSet(weightKg: set.weightKg, repsCompleted: set.repsCompleted))
            }
        case .resting:
            HStack(spacing: 12) {
                Text(restLabel(restRemaining)).font(.wwHeadline).foregroundStyle(Color.ironAccent)
                Spacer()
                Button(startSetLabel) {
                    startNextSet()
                }
                .buttonStyle(PrimarySportButtonStyle())
            }
        }
    }

    private func bindingForWeight(_ set: SetLog) -> Binding<Double> {
        Binding(
            get: { UnitSystem.current == .metric ? set.weightKg : UnitSystem.kgToLbs(set.weightKg) },
            set: { newValue in
                set.weightKg = UnitSystem.current == .metric ? newValue : UnitSystem.lbsToKg(newValue)
            }
        )
    }

    private func bindingForReps(_ set: SetLog) -> Binding<Int> {
        Binding(get: { set.repsCompleted }, set: { set.repsCompleted = $0 })
    }

    private func startSet() {
        setPhase = .runningSet
        elapsedSetSeconds = 0
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                elapsedSetSeconds += 1
            }
        }
    }

    private func finishSet(_ set: SetLog) {
        set.isCompleted = true
        set.timestamp = Date()
        try? modelContext.save()
        HapticFeedback.setCompleted()

        let isCompound = currentExercise?.isCompound ?? false
        let seconds = GuidedSessionFlow.restSeconds(isCompound: isCompound)
        RestNotificationScheduler.scheduleRestFinished(in: seconds)
        startRest(seconds: seconds)
    }

    private func startRest(seconds: Int) {
        timerTask?.cancel()
        setPhase = .resting
        restRemaining = seconds

        timerTask = Task { @MainActor in
            while restRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                restRemaining -= 1
            }
            if !Task.isCancelled {
                HapticFeedback.restFinished()
                RestNotificationScheduler.cancelPending()
                startNextSet()
            }
        }
    }

    private func startNextSet() {
        timerTask?.cancel()
        RestNotificationScheduler.cancelPending()

        guard let currentGroup, let activeSet else { return }
        if let nextID = GuidedSessionFlow.nextSetID(after: activeSet.id, in: currentGroup.sets) {
            activeSetID = nextID
            setPhase = .idle
        } else {
            advanceToNextExercise()
        }
    }

    private func advanceToNextExercise() {
        guard currentExerciseIndex < groups.count - 1 else {
            setPhase = .idle
            return
        }
        currentExerciseIndex += 1
        selectFirstIncompleteSet()
    }

    private func goToPreviousExercise() {
        guard currentExerciseIndex > 0 else { return }
        currentExerciseIndex -= 1
        selectFirstIncompleteSet()
    }

    private func goToNextExercise() {
        guard currentExerciseIndex < groups.count - 1 else { return }
        currentExerciseIndex += 1
        selectFirstIncompleteSet()
    }

    private func finishSession() {
        timerTask?.cancel()
        log.endDate = Date()
        try? modelContext.save()
        dismiss()
    }

    private func addSet(to exerciseId: String) {
        let exerciseSets = log.completedSets.filter { $0.exerciseId == exerciseId }
        guard let template = exerciseSets.max(by: { $0.setIndex < $1.setIndex }) else { return }
        let newSet = SetLog(
            exerciseId: exerciseId,
            setIndex: (log.completedSets.map(\.setIndex).max() ?? 0) + 1,
            weightKg: 0,
            repsCompleted: 0,
            restSeconds: template.restSeconds,
            targetRepsMin: template.targetRepsMin,
            targetRepsMax: template.targetRepsMax
        )
        log.completedSets.append(newSet)
        renumberSets()
        try? modelContext.save()
    }

    private func removeSet(_ set: SetLog) {
        let exerciseSetCount = log.completedSets.filter { $0.exerciseId == set.exerciseId }.count
        guard exerciseSetCount > 1 else { return }
        log.completedSets.removeAll { $0.id == set.id }
        modelContext.delete(set)
        if activeSetID == set.id {
            selectFirstIncompleteSet()
        }
        renumberSets()
        try? modelContext.save()
    }

    private func renumberSets() {
        let order = GuidedSessionFlow.groupedSets(log.completedSets).map(\.exerciseId)
        GuidedSessionFlow.renumbered(log.completedSets, groupedBy: order)
    }

    private func selectFirstIncompleteSet() {
        timerTask?.cancel()
        setPhase = .idle
        elapsedSetSeconds = 0
        restRemaining = 0
        guard let currentGroup else { return }
        activeSetID = currentGroup.sets.first { !$0.isCompleted }?.id ?? currentGroup.sets.last?.id
    }

    private var startSetLabel: String {
        String(localized: "guided_session.start_set", defaultValue: "Empezar set", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var finishSetLabel: String {
        String(localized: "guided_session.finish_set", defaultValue: "Terminar set", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var noExercisesLabel: String {
        String(localized: "guided_session.no_exercises", defaultValue: "Sin ejercicios", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private func restLabel(_ seconds: Int) -> String {
        String(localized: "guided_session.rest_seconds", defaultValue: "Descanso: \(seconds) s", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private func elapsedLabel(_ seconds: Int) -> String {
        String(localized: "guided_session.elapsed_seconds", defaultValue: "\(seconds) s", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var finishLabel: String {
        String(localized: "guided_session.finish", defaultValue: "Terminar", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var closeLabel: String {
        String(localized: "guided_session.close_info", defaultValue: "Cerrar", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var addSetLabel: String {
        String(localized: "guided_session.add_set", defaultValue: "Agregar set", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var removeSetLabel: String {
        String(localized: "guided_session.remove_set", defaultValue: "Eliminar set", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }
}

private enum SetPhase: Equatable {
    case idle
    case runningSet
    case resting
}

struct GuidedWorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Guided Workout")
            .preferredColorScheme(.dark)
    }
}
