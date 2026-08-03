import Foundation

/// Body joints tracked for rep counting, independent of Vision's own
/// joint naming so the counting logic has no framework dependency and
/// can be unit tested without a camera. `PoseDetectorService` (added
/// in a later task) is the only place that maps Vision's joint names
/// onto this enum.
enum BodyJoint: String, Codable, Equatable, Hashable {
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case leftHip, rightHip
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle
}

/// A joint angle to track: the interior angle formed at `vertex`
/// between the rays to `proximal` and `distal` — e.g. the knee angle
/// is the angle at the knee between the hip and the ankle.
struct JointAngle: Equatable {
    let proximal: BodyJoint
    let vertex: BodyJoint
    let distal: BodyJoint
}

/// Per-exercise configuration for the rep counter: which angle to
/// track and which ranges count as the two extremes of one
/// repetition. Every exercise gets its own independent profile —
/// nothing is shared between exercises beyond the `RepCounterEngine`
/// that interprets them. `downRange`/`upRange` are exercise-relative
/// labels, not literal body position: for a squat "up" is standing
/// (the peak angle), for a curl "up" is the top of the curl (the
/// trough angle). See `RepCounterEngine` for how a rep is counted.
struct MovementProfile: Equatable {
    let primaryAngle: JointAngle
    let downRange: ClosedRange<Double>
    let upRange: ClosedRange<Double>
}

/// The curated set of exercises the Smart Assistant supports (see the
/// design spec for why these eight and not the full 146-exercise
/// catalog). Angle thresholds below are a reasonable starting point
/// based on standard range-of-motion references for each movement —
/// expect to retune them against real Vision output on a physical
/// device during Task 4's verification, per the design spec.
enum MovementProfileCatalog {
    static func profile(forExerciseID id: String) -> MovementProfile? {
        profiles[id]
    }

    private static let profiles: [String: MovementProfile] = [
        "ex_048_sentadilla_trasera_con_barra": squat,
        "ex_060_sentadilla_goblet_con_mancuerna": squat,
        "ex_057_sentadilla_bulgara_con_mancuernas": squat,
        "ex_021_flexiones_pecho": pushUp,
        "ex_020_fondos_banco": pushUp,
        "ex_098_curl_barra_recta": curl,
        "ex_078_press_militar_barra": overheadPress,
        "ex_031_peso_muerto_convencional": hinge,
    ]

    // Knee angle (hip-knee-ankle): ~85 degrees at the bottom of a
    // working-depth squat, ~170 degrees standing tall.
    private static let squat = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
        downRange: 70...100,
        upRange: 160...180
    )

    // Elbow angle (shoulder-elbow-wrist): ~85 degrees at the bottom
    // of a push-up, ~170 degrees at full lockout.
    private static let pushUp = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist),
        downRange: 70...100,
        upRange: 155...180
    )

    // Elbow angle: ~165 degrees hanging extended (the curl's "down"),
    // ~45 degrees at peak contraction (the curl's "up").
    private static let curl = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist),
        downRange: 150...180,
        upRange: 30...60
    )

    // Shoulder angle (hip-shoulder-elbow): ~35 degrees racked at the
    // shoulder, ~165 degrees with the arm locked out overhead.
    private static let overheadPress = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow),
        downRange: 20...50,
        upRange: 150...180
    )

    // Hip angle (shoulder-hip-knee): ~80 degrees bent over at the
    // bottom of a deadlift, ~170 degrees standing tall at lockout.
    private static let hinge = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
        downRange: 60...100,
        upRange: 160...180
    )
}
