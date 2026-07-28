import SwiftUI
import SwiftData

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [Exercise]
    @State private var searchText: String = ""

    /// Ids ya agregados al dia: se muestran deshabilitados para no duplicar.
    let excludedIDs: Set<String>
    let onSelect: (Exercise) -> Void

    private var filtered: [Exercise] {
        let sorted = exercises.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return sorted }
        let term = searchText.lowercased()
        return sorted.filter { $0.name.lowercased().contains(term) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { exercise in
                let yaAgregado = excludedIDs.contains(exercise.id)

                Button {
                    onSelect(exercise)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        GIFImageView(
                            localName: exercise.gifFileName,
                            remoteURL: exercise.gifRemoteURLString.flatMap(URL.init(string:)),
                            contentMode: .fill
                        )
                        .frame(width: 56, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name).font(.wwTitle3)
                            Text("\(exercise.muscleGroup.displayName) • \(exercise.equipment.displayName)")
                                .font(.wwCaption)
                                .foregroundStyle(Color.ironTextSecondary)
                        }

                        Spacer()

                        if yaAgregado {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.ironAccent)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .disabled(yaAgregado)
                .listRowBackground(Color.ironCard)
            }
            .scrollContentBackground(.hidden)
            .background(Color.ironBackground)
            .navigationTitle("Elegir ejercicio")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .tint(Color.ironAccent)
    }
}
