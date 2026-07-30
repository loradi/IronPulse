import Foundation

enum GuidedSessionFlow {
    static func restSeconds(isCompound: Bool) -> Int {
        isCompound ? 90 : 60
    }

    static func nextSetID(after currentID: SetLog.ID?, in orderedSets: [SetLog]) -> SetLog.ID? {
        guard let currentID,
              let currentIndex = orderedSets.firstIndex(where: { $0.id == currentID }),
              currentIndex + 1 < orderedSets.count
        else {
            return nil
        }
        return orderedSets[currentIndex + 1].id
    }

    static func groupedSets(_ sets: [SetLog]) -> [(exerciseId: String, sets: [SetLog])] {
        let sorted = sets.sorted { $0.setIndex < $1.setIndex }
        var order: [String] = []
        var buckets: [String: [SetLog]] = [:]
        for set in sorted {
            if buckets[set.exerciseId] == nil { order.append(set.exerciseId) }
            buckets[set.exerciseId, default: []].append(set)
        }
        return order.map { ($0, buckets[$0]!) }
    }

    static func renumbered(_ sets: [SetLog], groupedBy exerciseOrder: [String]) {
        var index = 0
        for exerciseId in exerciseOrder {
            for set in sets.filter({ $0.exerciseId == exerciseId }).sorted(by: { $0.setIndex < $1.setIndex }) {
                set.setIndex = index
                index += 1
            }
        }
    }

    static func canCompleteSet(weightKg: Double, repsCompleted: Int) -> Bool {
        weightKg > 0 && repsCompleted > 0
    }

    static func elapsedSeconds(since start: Date, now: Date = Date()) -> Int {
        max(0, Int(now.timeIntervalSince(start)))
    }

    static func remainingSeconds(until end: Date, now: Date = Date()) -> Int {
        max(0, Int(ceil(end.timeIntervalSince(now))))
    }
}
