import SwiftUI
import Combine

struct ExerciseListView: View {
    @StateObject private var vm = ExerciseListViewModel()
    @State private var searchText: String = ""

    var body: some View {
        NavigationStack {
            List(vm.filteredExercises(search: searchText), id: \ .id) { exercise in
                NavigationLink(value: exercise) {
                    HStack(spacing: 12) {
                        AsyncImage(url: exercise.imageURL) { phase in
                            switch phase {
                            case .empty:
                                Color.ironBorder.frame(width: 72, height: 56).cornerRadius(8)
                            case .success(let image):
                                image.resizable().scaledToFill().frame(width: 72, height: 56).clipped().cornerRadius(8)
                            case .failure:
                                Color.gray.frame(width: 72, height: 56).cornerRadius(8)
                            @unknown default:
                                EmptyView()
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(exercise.name).font(.headline)
                            Text(exercise.cleanedDescription).font(.caption).lineLimit(2).foregroundStyle(.ironTextSecondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Ejercicios")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .refreshable {
                await vm.reload()
            }
            .task {
                await vm.reload()
            }
        }
    }
}

@MainActor
final class ExerciseListViewModel: ObservableObject {
    @Published private(set) var exercises: [WgerExercise] = []
    private let service = WgerAPIService()

    func reload() async {
        do {
            let items = try await service.fetchExercises()
            self.exercises = items
        } catch {
            // Silently ignore for now; production should surface
            print("Failed loading exercises: \(error)")
        }
    }

    func filteredExercises(search: String) -> [WgerExercise] {
        guard !search.trimmingCharacters(in: .whitespaces).isEmpty else { return exercises }
        let term = search.lowercased()
        return exercises.filter { $0.name.lowercased().contains(term) || $0.cleanedDescription.lowercased().contains(term) }
    }
}

struct ExerciseListView_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseListView()
            .preferredColorScheme(.dark)
    }
}
