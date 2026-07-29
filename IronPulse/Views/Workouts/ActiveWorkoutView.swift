import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Bindable var log: WorkoutLog
    @Query private var catalog: [Exercise]

    private var isReadOnly: Bool { log.endDate != nil }

    private var exerciseNames: [String: String] {
        Dictionary(catalog.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    private var sessionVolumeKg: Double {
        log.completedSets
            .filter(\.isCompleted)
            .reduce(0) { $0 + $1.weightKg * Double($1.repsCompleted) }
    }

    private var groupedSets: [(exerciseId: String, sets: [SetLog])] {
        GuidedSessionFlow.groupedSets(log.completedSets)
    }

    var body: some View {
        Group {
            if isReadOnly {
                readOnlyBody
            } else {
                GuidedWorkoutView(log: log, catalog: catalog)
            }
        }
    }

    private var readOnlyBody: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text(log.routineName).font(.wwHeadline)
                    Text(log.dayTitle).font(.wwBody).foregroundStyle(Color.ironTextSecondary)
                }
                Spacer()
                Text("Finalizada").foregroundStyle(Color.ironTextSecondary)
            }
            .padding()

            LabeledProgressBar(
                label: "Session Volume",
                valueText: UnitSystem.formattedWeight(sessionVolumeKg, system: UnitSystem.current),
                progress: 1.0
            )
            .ironCard()
            .padding(.horizontal)

            List {
                ForEach(groupedSets, id: \.exerciseId) { group in
                    Section(exerciseNames[group.exerciseId] ?? group.exerciseId) {
                        ForEach(Array(group.sets.enumerated()), id: \.element.id) { index, set in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Set \(index + 1)").font(.wwHeadline)
                                    Spacer()
                                    Text("Meta: \(set.targetRepsMin)-\(set.targetRepsMax)")
                                        .font(.wwCaption)
                                        .foregroundStyle(Color.ironTextSecondary)
                                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(set.isCompleted ? Color.ironAccent : Color.ironTextSecondary)
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        TextField("Peso", value: .constant(displayWeight(set)), format: .number.precision(.fractionLength(1)))
                                            .keyboardType(.decimalPad)
                                            .disabled(true)
                                            .frame(width: 60)
                                        Text(UnitSystem.current == .metric ? "kg" : "lbs").font(.wwCaption).foregroundStyle(Color.ironTextSecondary)
                                    }
                                    Spacer()
                                    Stepper("\(set.repsCompleted) reps", value: .constant(set.repsCompleted), in: 0...50)
                                        .disabled(true)
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                        }
                    }
                }
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
        }
    }

    private func displayWeight(_ set: SetLog) -> Double {
        UnitSystem.current == .metric ? set.weightKg : UnitSystem.kgToLbs(set.weightKg)
    }
}

struct ActiveWorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Active Workout")
            .preferredColorScheme(.dark)
    }
}
