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

/// A secondary constraint checked alongside `MovementProfile.primaryAngle`,
/// to catch the most common form problem: using body momentum/swing
/// instead of isolating the working joint. Two shapes cover the two
/// broad categories of exercise:
///
/// - `.stability`: for isolation exercises, where a joint (typically
///   the shoulder or torso) should stay put while only the primary
///   joint moves. Measured relative to wherever that joint happened to
///   be when the rep attempt started (there's no single "correct"
///   absolute angle here — only "however you started, don't drift far
///   from it").
/// - `.bounded`: for compound exercises, where that same joint is
///   *supposed* to move as a natural part of correct form (a squat's
///   torso leans forward, a hinge's torso tips over) — so instead of a
///   per-rep baseline, it's checked against one fixed absolute range
///   for the whole rep attempt.
enum SecondaryCheck: Equatable {
    case stability(angle: JointAngle, toleranceDegrees: Double)
    case bounded(angle: JointAngle, allowedRange: ClosedRange<Double>)

    var angle: JointAngle {
        switch self {
        case .stability(let angle, _): return angle
        case .bounded(let angle, _): return angle
        }
    }
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
    let secondaryCheck: SecondaryCheck?

    init(
        primaryAngle: JointAngle,
        downRange: ClosedRange<Double>,
        upRange: ClosedRange<Double>,
        secondaryCheck: SecondaryCheck? = nil
    ) {
        self.primaryAngle = primaryAngle
        self.downRange = downRange
        self.upRange = upRange
        self.secondaryCheck = secondaryCheck
    }
}

/// The curated set of exercises the Smart Assistant supports (see the
/// phase 3 design spec for why these 64 and not the full 146-exercise
/// catalog). Angle thresholds below are a reasonable starting point
/// based on standard range-of-motion references for each movement —
/// expect to retune them against real Vision output on a physical
/// device during verification, per the design spec.
enum MovementProfileCatalog {
    static func profile(forExerciseID id: String) -> MovementProfile? {
        profiles[id]
    }

    private static let profiles: [String: MovementProfile] = [
        "ex_048_sentadilla_trasera_con_barra": squat,
        "ex_060_sentadilla_goblet_con_mancuerna": squat,
        "ex_057_sentadilla_bulgara_con_mancuernas": squat,
        "ex_049_sentadilla_frontal_con_barra": squat,
        "ex_062_sentadilla_hack_en_maquina": squat,
        "ex_063_sentadilla_en_maquina_smith": squat,
        "ex_058_sentadilla_sissy": squat,
        "ex_076_sentadilla_sumo_con_mancuerna": squat,
        "ex_021_flexiones_pecho": pushUp,
        "ex_020_fondos_banco": pushUp,
        "ex_019_fondos_paralelas": pushUp,
        "ex_022_flexiones_inclinadas": pushUp,
        "ex_015_press_pecho_maquina": pushUp,
        "ex_123_flexiones_diamante": pushUp,
        "ex_124_fondos_maquina": pushUp,
        "ex_098_curl_barra_recta": curl,
        "ex_100_curl_alterno_mancuernas": curl,
        "ex_101_curl_martillo_mancuernas": curl,
        "ex_104_curl_concentrado": curl,
        "ex_099_curl_barra_z": curl,
        "ex_102_curl_predicador_barra_z": curl,
        "ex_103_curl_predicador_maquina": curl,
        "ex_105_curl_polea_baja": curl,
        "ex_106_curl_inclinado_mancuernas": curl,
        "ex_108_curl_drag": curl,
        "ex_109_curl_martillo_cuerda_polea": curl,
        "ex_110_curl_agarre_cerrado": curl,
        "ex_111_curl_zottman": curl,
        "ex_112_curl_polea_alta": curl,
        "ex_113_curl_inverso_barra": curl,
        "ex_114_curl_maquina": curl,
        "ex_078_press_militar_barra": overheadPress,
        "ex_079_press_militar_sentado_barra": overheadPress,
        "ex_080_press_hombros_mancuernas": overheadPress,
        "ex_081_press_arnold": overheadPress,
        "ex_082_press_hombros_sentado_mancuernas": overheadPress,
        "ex_083_press_hombros_maquina": overheadPress,
        "ex_084_press_hombros_polea": overheadPress,
        "ex_031_peso_muerto_convencional": hinge,
        "ex_051_peso_muerto_rumano_con_barra": hinge,
        "ex_052_peso_muerto_rumano_con_mancuernas": hinge,
        "ex_032_peso_muerto_rumano": hinge,
        "ex_043_peso_muerto_sumo": hinge,
        "ex_064_peso_muerto_sumo_con_barra": hinge,
        "ex_027_remo_sentado_polea": row,
        "ex_028_jalon_pecho_agarre_ancho": row,
        "ex_023_dominadas_pronadas": row,
        "ex_024_dominadas_supinadas": row,
        "ex_025_dominadas_asistidas_banda": row,
        "ex_029_jalon_pecho_agarre_cerrado": row,
        "ex_033_remo_posterior_polea_cuerda": row,
        "ex_045_face_pull_polea": row,
        "ex_046_remo_arrodillado_polea_alta": row,
        "ex_093_remo_menton_barra": row,
        "ex_094_remo_menton_mancuernas": row,
        "ex_117_pushdown_polea_cuerda": tricepsExtension,
        "ex_118_pushdown_polea_barra_recta": tricepsExtension,
        "ex_120_extension_mancuernas_dos_manos_sobre_cabeza": tricepsExtension,
        "ex_128_extension_polea_cuerda_tras_nuca": tricepsExtension,
        "ex_133_extension_triceps_maquina": tricepsExtension,
        "ex_085_elevaciones_laterales_mancuernas": lateralRaise,
        "ex_087_elevaciones_frontales_mancuernas": lateralRaise,
        "ex_054_extension_de_piernas_en_maquina": legExtension,
        "ex_056_curl_femoral_sentado": legCurl,
    ]

    // Knee angle (hip-knee-ankle): ~85 degrees at the bottom of a
    // working-depth squat, ~170 degrees standing tall. Secondary
    // check: torso (shoulder-hip-knee) shouldn't collapse forward past
    // ~50 degrees — a squat's torso naturally leans forward some, more
    // than the other `.bounded` checks below allow, so this one gets a
    // wider range.
    private static let squat = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
        downRange: 70...100,
        upRange: 160...180,
        secondaryCheck: .bounded(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            allowedRange: 50...180
        )
    )

    // Elbow angle (shoulder-elbow-wrist): ~85 degrees at the bottom
    // of a push-up, ~170 degrees at full lockout. Secondary check:
    // torso (shoulder-hip-knee) stays close to a straight line -
    // sagging hips would drop this well below 150.
    private static let pushUp = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist),
        downRange: 70...100,
        upRange: 155...180,
        secondaryCheck: .bounded(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            allowedRange: 150...180
        )
    )

    // Elbow angle: ~165 degrees hanging extended (the curl's "down"),
    // ~45 degrees at peak contraction (the curl's "up"). Secondary
    // check: shoulder (hip-shoulder-elbow) should stay near wherever
    // it started the rep - swinging it to help curl the weight is the
    // most common curl cheat.
    private static let curl = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist),
        downRange: 150...180,
        upRange: 30...60,
        secondaryCheck: .stability(
            angle: JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow),
            toleranceDegrees: 15
        )
    )

    // Shoulder angle (hip-shoulder-elbow): ~35 degrees racked at the
    // shoulder, ~165 degrees with the arm locked out overhead.
    // Secondary check: torso (shoulder-hip-knee) stays upright -
    // leaning back to "push press" with the legs/back would drop this
    // below 150.
    private static let overheadPress = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow),
        downRange: 20...50,
        upRange: 150...180,
        secondaryCheck: .bounded(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            allowedRange: 150...180
        )
    )

    // Hip angle (shoulder-hip-knee): ~80 degrees bent over at the
    // bottom of a deadlift, ~170 degrees standing tall at lockout.
    // Secondary check: knee (hip-knee-ankle) stays relatively straight
    // - bending it too much turns the hinge into a squat.
    private static let hinge = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
        downRange: 60...100,
        upRange: 160...180,
        secondaryCheck: .bounded(
            angle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
            allowedRange: 150...180
        )
    )

    // Elbow angle (shoulder-elbow-wrist): ~170 degrees extended
    // reaching for the weight (the row's "down"), ~60-85 degrees
    // pulled to the torso (the row's "up") — the opposite direction
    // from pushUp's elbow angle on the same joint triangle. Secondary
    // check: torso (shoulder-hip-knee) stays near wherever it started
    // - rocking back to heave the weight is the most common row cheat.
    private static let row = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist),
        downRange: 155...180,
        upRange: 60...85,
        secondaryCheck: .stability(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            toleranceDegrees: 15
        )
    )

    // Elbow angle (shoulder-elbow-wrist): ~70-95 degrees at the rack
    // position (the extension's "down"), ~160-180 degrees at full
    // lockout (the extension's "up") — the same joint triangle as
    // curl, opposite direction. Secondary check: shoulder
    // (hip-shoulder-elbow) stays near wherever it started, same
    // swing-for-momentum concern as curl.
    private static let tricepsExtension = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist),
        downRange: 70...95,
        upRange: 160...180,
        secondaryCheck: .stability(
            angle: JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow),
            toleranceDegrees: 15
        )
    )

    // Shoulder angle (hip-shoulder-elbow) - same triangle as
    // overheadPress, with a shorter range: ~0-25 degrees with the arm
    // at the side (the raise's "down" — the floor is 0, not ~10, since
    // the arm hanging naturally at rest can sit flush against the
    // torso), ~75-95 degrees at shoulder height (the raise's "up") -
    // stops well short of overheadPress's overhead lockout. Covers
    // both lateral and front raises: from a front-facing camera the
    // two produce a very similar change in this angle even though the
    // arm moves in a different plane (out to the side vs. forward) -
    // the tracked angle doesn't distinguish which plane, so one
    // profile serves both. Secondary check: torso (shoulder-hip-knee)
    // stays near wherever it started - swaying to help lift the arm is
    // the most common raise cheat.
    private static let lateralRaise = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow),
        downRange: 0...25,
        upRange: 75...95,
        secondaryCheck: .stability(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            toleranceDegrees: 15
        )
    )

    // Knee angle (hip-knee-ankle) - same triangle as squat, seated
    // machine motion: ~80-100 degrees with the leg bent under the seat
    // (the extension's "down"), ~160-180 degrees with the leg extended
    // straight out (the extension's "up"). Secondary check: torso
    // (shoulder-hip-knee) stays near wherever it started - it should
    // stay put in a seated machine.
    private static let legExtension = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
        downRange: 80...100,
        upRange: 160...180,
        secondaryCheck: .stability(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            toleranceDegrees: 15
        )
    )

    // Knee angle (hip-knee-ankle) - same triangle as legExtension,
    // opposite direction: ~160-180 degrees with the leg extended (the
    // curl's "down"), ~70-90 degrees curled under the seat (the
    // curl's "up"). Secondary check: same torso-stability concern as
    // legExtension.
    private static let legCurl = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
        downRange: 160...180,
        upRange: 70...90,
        secondaryCheck: .stability(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            toleranceDegrees: 15
        )
    )
}
