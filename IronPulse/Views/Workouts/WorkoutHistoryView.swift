import SwiftUI
import SwiftData

struct WorkoutHistoryView: View {
    @Query(
        filter: #Predicate<WorkoutLog> { $0.endDate != nil },
        sort: \WorkoutLog.startDate,
        order: .reverse
    )
    private var logs: [WorkoutLog]

    @State private var selectedLog: WorkoutLog?

    var body: some View {
        List(logs) { log in
            Button {
                selectedLog = log
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(log.routineName) · \(log.dayTitle)").font(.headline)
                        Text("\(log.startDate.formatted(date: .abbreviated, time: .shortened)) · \(duration(log))")
                            .font(.caption)
                            .foregroundStyle(Color.ironTextSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.ironTextSecondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.ironCard)
        }
        .scrollContentBackground(.hidden)
        .background(Color.ironBackground)
        .navigationTitle("Historial")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(item: $selectedLog) { log in
            ActiveWorkoutView(log: log)
        }
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
