import SwiftUI
import Charts

struct ExerciseProgressView: View {
    let profile: UserProfile
    let exercise: Exercise

    private var points: [(date: Date, maxWeightKg: Double)] {
        WorkoutStatsService.progress(for: exercise.id, in: profile.workoutLogs)
    }

    private var displayPoints: [(date: Date, displayWeight: Double)] {
        let system = UnitSystem.current
        return points.map { point in
            (date: point.date, displayWeight: system == .metric ? point.maxWeightKg : UnitSystem.kgToLbs(point.maxWeightKg))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(exercise.name).font(.wwHeadline)

                if points.isEmpty {
                    ContentUnavailableView(
                        "Sin datos todavia",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Todavia no completaste ningun set de este ejercicio.")
                    )
                } else {
                    Chart(displayPoints, id: \.date) { point in
                        LineMark(x: .value("Fecha", point.date), y: .value("Peso maximo", point.displayWeight))
                            .foregroundStyle(Color.ironAccent)
                        PointMark(x: .value("Fecha", point.date), y: .value("Peso maximo", point.displayWeight))
                            .foregroundStyle(Color.ironAccent)
                    }
                    .frame(height: 220)
                    // Mismo motivo que en DashboardView: el Chart bloquea los toques
                    // del resto de la pantalla si se deja interactivo.
                    .allowsHitTesting(false)
                    .ironCard()
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(Color.ironBackground)
        .navigationTitle("Progreso")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct ExerciseProgressView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Progreso")
            .preferredColorScheme(.dark)
    }
}
