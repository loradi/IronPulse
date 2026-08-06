import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Query private var exercises: [Exercise]
    @State private var searchText: String = ""
    @State private var selectedMuscleGroup: MuscleGroup?
    @State private var selectedEquipment: EquipmentType?

    private var availableMuscleGroups: [MuscleGroup] {
        MuscleGroup.allCases.filter { group in exercises.contains { $0.muscleGroup == group } }
    }

    private var availableEquipment: [EquipmentType] {
        EquipmentType.allCases.filter { equipment in exercises.contains { $0.equipment == equipment } }
    }

    private var filtered: [Exercise] {
        exercises.filter { exercise in
            let matchesText: Bool
            let term = searchText.trimmingCharacters(in: .whitespaces).lowercased()
            matchesText = term.isEmpty || exercise.name.lowercased().contains(term)

            let matchesMuscleGroup = selectedMuscleGroup == nil || exercise.muscleGroup == selectedMuscleGroup
            let matchesEquipment = selectedEquipment == nil || exercise.equipment == selectedEquipment

            return matchesText && matchesMuscleGroup && matchesEquipment
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        List(filtered) { exercise in
            NavigationLink {
                ExerciseDetailView(exercise: exercise)
            } label: {
                HStack(spacing: 12) {
                    GIFImageView(
                        localName: exercise.gifFileName,
                        remoteURL: exercise.gifRemoteURLString.flatMap(URL.init(string:)),
                        contentMode: .fill
                    )
                    .frame(width: 72, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(exercise.name).font(.wwTitle3).lineLimit(2)
                            Spacer()
                            if MovementProfileCatalog.profile(forExerciseID: exercise.id) != nil {
                                SmartAssistantBadge()
                            }
                            if exercise.isCompound {
                                TagBadge(text: String(localized: "exercise.compound_badge", defaultValue: "Compound", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale))
                            }
                        }
                        Text("\(exercise.muscleGroup.displayName) • \(exercise.equipment.displayName)")
                            .font(.wwCaption)
                            .foregroundStyle(Color.ironTextSecondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.ironCard)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 8) {
                filterRow(
                    allLabel: String(localized: "exercise_filter.all", defaultValue: "Todos", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale),
                    items: availableMuscleGroups,
                    label: \.displayName,
                    selection: $selectedMuscleGroup
                )
                filterRow(
                    allLabel: String(localized: "exercise_filter.all", defaultValue: "Todos", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale),
                    items: availableEquipment,
                    label: \.displayName,
                    selection: $selectedEquipment
                )
            }
            .padding(.vertical, 8)
            .background(Color.ironBackground)
        }
        .scrollContentBackground(.hidden)
        .background(Color.ironBackground)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image("wwLogoMark")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                    Text("Watt + Weight").font(.wwHeadline)
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
    }

    private func filterRow<Item: Hashable>(
        allLabel: String,
        items: [Item],
        label: KeyPath<Item, String>,
        selection: Binding<Item?>
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: allLabel, isSelected: selection.wrappedValue == nil) {
                    selection.wrappedValue = nil
                }
                ForEach(items, id: \.self) { item in
                    FilterChip(title: item[keyPath: label], isSelected: selection.wrappedValue == item) {
                        selection.wrappedValue = item
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.wwLabelCaps)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? Color.ironBackground : Color.ironTextSecondary)
                .background(isSelected ? Color.ironAccent : Color.ironCard)
                .clipShape(Capsule())
        }
    }
}

struct ExerciseDetailView: View {
    let exercise: Exercise

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GIFImageView(
                    localName: exercise.gifFileName,
                    remoteURL: exercise.gifRemoteURLString.flatMap(URL.init(string:)),
                    contentMode: .fill
                )
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack(spacing: 8) {
                    if MovementProfileCatalog.profile(forExerciseID: exercise.id) != nil {
                        SmartAssistantBadge()
                    }
                    if exercise.isCompound {
                        TagBadge(text: String(localized: "exercise.compound_badge", defaultValue: "Compound", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale))
                    }
                }

                MuscleDiagramView(primary: exercise.muscleGroup, secondary: exercise.secondaryMuscles)
                    .frame(maxWidth: .infinity)

                if let proTip = exercise.proTip {
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(Color.ironAccent)
                        Text(proTip)
                            .font(.wwBody)
                            .italic()
                            .foregroundStyle(Color.ironTextPrimary)
                    }
                    .ironCard()
                }

                Text("\(exercise.muscleGroup.displayName) • \(exercise.equipment.displayName)")
                    .font(.wwBody)
                    .foregroundStyle(Color.ironTextSecondary)

                if !exercise.secondaryMuscles.isEmpty {
                    Text("Tambien trabaja: \(exercise.secondaryMuscles.map(\.displayName).joined(separator: ", "))")
                        .font(.wwCaption)
                        .foregroundStyle(Color.ironTextSecondary)
                }

                if !exercise.instructions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                            Text("\(index + 1). \(step)")
                                .font(.wwBody)
                        }
                    }
                    .ironCard()
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(Color.ironBackground)
        .navigationTitle(exercise.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct ExerciseListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ExerciseListView()
        }
        .preferredColorScheme(.dark)
    }
}
