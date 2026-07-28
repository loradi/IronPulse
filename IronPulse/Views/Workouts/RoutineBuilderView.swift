import SwiftUI
import SwiftData

struct RoutineBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let profile: UserProfile

    @State private var splitType: SplitType
    @State private var dayCount: Int
    @State private var draftDays: [DraftDay]
    @State private var pickerTarget: Int?

    init(profile: UserProfile) {
        self.profile = profile
        let split = WorkoutGeneratorService.splitType(for: profile.workoutDaysPerWeek)
        _splitType = State(initialValue: split)
        _dayCount = State(initialValue: profile.workoutDaysPerWeek)
        _draftDays = State(initialValue: Self.emptyDays(split: split, count: profile.workoutDaysPerWeek))
    }

    struct DraftDay: Identifiable {
        let id = UUID()
        var title: String
        var items: [DraftItem] = []
    }

    struct DraftItem: Identifiable {
        let id = UUID()
        let exercise: Exercise
        var sets: Int
        var repsMin: Int
        var repsMax: Int
        var restSeconds: Int
    }

    private static func emptyDays(split: SplitType, count: Int) -> [DraftDay] {
        WorkoutGeneratorService.dayTemplates(split: split, dayCount: count)
            .map { DraftDay(title: $0.title) }
    }

    private var totalExercises: Int {
        draftDays.reduce(0) { $0 + $1.items.count }
    }

    var body: some View {
        Form {
            Section("Estructura") {
                Picker("Split", selection: $splitType) {
                    ForEach(SplitType.allCases) { split in
                        Text(split.displayName).tag(split)
                    }
                }
                Stepper("\(diasLabel(dayCount)) por semana", value: $dayCount, in: 1...7)
            }
            .listRowBackground(Color.ironCard)

            ForEach(Array(draftDays.enumerated()), id: \.element.id) { dayIndex, day in
                Section("Dia \(dayIndex + 1) — \(day.title)") {
                    ForEach(Array(day.items.enumerated()), id: \.element.id) { itemIndex, item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.exercise.name).font(.wwTitle3)

                            Stepper(
                                "\(item.sets) series",
                                value: $draftDays[dayIndex].items[itemIndex].sets,
                                in: 1...10
                            )
                            Stepper(
                                "Minimo \(item.repsMin) reps",
                                value: $draftDays[dayIndex].items[itemIndex].repsMin,
                                in: 1...item.repsMax
                            )
                            Stepper(
                                "Maximo \(item.repsMax) reps",
                                value: $draftDays[dayIndex].items[itemIndex].repsMax,
                                in: item.repsMin...30
                            )
                            Stepper(
                                "\(item.restSeconds)s de descanso",
                                value: $draftDays[dayIndex].items[itemIndex].restSeconds,
                                in: 15...300,
                                step: 5
                            )
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        draftDays[dayIndex].items.remove(atOffsets: offsets)
                    }

                    Button("Agregar ejercicio") { pickerTarget = dayIndex }
                        .foregroundStyle(Color.ironAccent)
                }
                .listRowBackground(Color.ironCard)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.ironBackground)
        .navigationTitle("Rutina manual")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar", action: save).disabled(totalExercises == 0)
            }
        }
        .onChange(of: splitType) { _, nuevo in
            draftDays = Self.emptyDays(split: nuevo, count: dayCount)
        }
        .onChange(of: dayCount) { _, nuevo in
            draftDays = Self.emptyDays(split: splitType, count: nuevo)
        }
        .sheet(item: Binding(
            get: { pickerTarget.map { PickerTarget(dayIndex: $0) } },
            set: { pickerTarget = $0?.dayIndex }
        )) { target in
            ExercisePickerSheet(
                excludedIDs: Set(draftDays[target.dayIndex].items.map(\.exercise.id))
            ) { exercise in
                addExercise(exercise, toDay: target.dayIndex)
            }
        }
    }

    private struct PickerTarget: Identifiable {
        let dayIndex: Int
        var id: Int { dayIndex }
    }

    private func addExercise(_ exercise: Exercise, toDay dayIndex: Int) {
        let plan = WorkoutGeneratorService.prescription(
            goal: profile.primaryGoal,
            level: profile.experienceLevel
        )
        draftDays[dayIndex].items.append(
            DraftItem(
                exercise: exercise,
                sets: plan.sets,
                repsMin: plan.repsMin,
                repsMax: plan.repsMax,
                restSeconds: plan.restSeconds
            )
        )
    }

    private func save() {
        let routine = WorkoutRoutine(
            name: "Rutina manual - \(splitType.displayName)",
            splitType: splitType,
            isAutoGenerated: false,
            isActive: true
        )

        // Igual que en WorkoutGeneratorService: solo el lado "coleccion",
        // SwiftData completa el inverso al insertar.
        let weekdays = WorkoutGeneratorService.weekdaysForCount(dayCount)
        for (index, draft) in draftDays.enumerated() where !draft.items.isEmpty {
            let day = RoutineDay(dayNumber: index + 1, title: draft.title, weekday: weekdays[index])
            day.exercises = draft.items.enumerated().map { position, item in
                RoutineExercise(
                    exercise: item.exercise,
                    targetSets: item.sets,
                    targetRepsMin: item.repsMin,
                    targetRepsMax: item.repsMax,
                    restSeconds: item.restSeconds,
                    orderIndex: position
                )
            }
            routine.days.append(day)
        }

        profile.activate(routine, in: modelContext)
        dismiss()
    }
}
