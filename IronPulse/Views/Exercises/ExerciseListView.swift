import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText: String = ""

    private var filtered: [Exercise] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return exercises }
        let term = searchText.lowercased()
        return exercises.filter { $0.name.lowercased().contains(term) }
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
                        Text(exercise.name).font(.headline)
                        Text("\(exercise.muscleGroup.displayName) • \(exercise.equipment.displayName)")
                            .font(.caption)
                            .foregroundStyle(Color.ironTextSecondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.ironCard)
        }
        .scrollContentBackground(.hidden)
        .background(Color.ironBackground)
        .navigationTitle("Ejercicios")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
    }
}

private struct ExerciseDetailView: View {
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

                Text("\(exercise.muscleGroup.displayName) • \(exercise.equipment.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(Color.ironTextSecondary)

                if !exercise.secondaryMuscles.isEmpty {
                    Text("Tambien trabaja: \(exercise.secondaryMuscles.map(\.displayName).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(Color.ironTextSecondary)
                }

                if !exercise.instructions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                            Text("\(index + 1). \(step)")
                                .font(.body)
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
