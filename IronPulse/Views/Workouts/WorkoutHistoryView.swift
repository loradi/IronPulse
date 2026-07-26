import SwiftUI
import SwiftData

struct WorkoutHistoryView: View {
    @Query(
        filter: #Predicate<WorkoutLog> { $0.endDate != nil },
        sort: \WorkoutLog.startDate,
        order: .reverse
    )
    private var logs: [WorkoutLog]

    var body: some View {
        List(logs) { log in
            NavigationLink {
                ActiveWorkoutView(log: log)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(log.routineName) · \(log.dayTitle)").font(.headline)
                    Text("\(log.startDate.formatted(date: .abbreviated, time: .shortened)) · \(duration(log))")
                        .font(.caption)
                        .foregroundStyle(Color.ironTextSecondary)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.ironCard)
        }
        .scrollContentBackground(.hidden)
        .background(Color.ironBackground)
        .navigationTitle("Historial")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .overlay {
            if logs.isEmpty {
                ContentUnavailableView(
                    "Sin entrenamientos",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Los entrenamientos que termines van a aparecer aca.")
                )
            }
        }
    }

    private func duration(_ log: WorkoutLog) -> String {
        guard let endDate = log.endDate else { return "" }
        let minutes = Int(endDate.timeIntervalSince(log.startDate) / 60)
        return "\(minutes) min"
    }
}

struct WorkoutHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WorkoutHistoryView()
        }
        .preferredColorScheme(.dark)
    }
}
