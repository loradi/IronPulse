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
}
