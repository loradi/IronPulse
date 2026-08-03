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

    // Elbow angle (shoulder-elbow-wrist): ~170 degrees extended
    // reaching for the weight (the row's "down"), ~60-85 degrees
    // pulled to the torso (the row's "up") — the opposite direction
    // from pushUp's elbow angle on the same joint triangle.
    private static let row = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist),
        downRange: 155...180,
        upRange: 60...85
    )

    // Elbow angle (shoulder-elbow-wrist): ~70-95 degrees at the rack
    // position (the extension's "down"), ~160-180 degrees at full
    // lockout (the extension's "up") — the same joint triangle as
    // curl, opposite direction.
    private static let tricepsExtension = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist),
        downRange: 70...95,
        upRange: 160...180
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
    // profile serves both.
    private static let lateralRaise = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow),
        downRange: 0...25,
        upRange: 75...95
    )

    // Knee angle (hip-knee-ankle) - same triangle as squat, seated
    // machine motion: ~80-100 degrees with the leg bent under the seat
    // (the extension's "down"), ~160-180 degrees with the leg extended
    // straight out (the extension's "up").
    private static let legExtension = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
        downRange: 80...100,
        upRange: 160...180
    )

    // Knee angle (hip-knee-ankle) - same triangle as legExtension,
    // opposite direction: ~160-180 degrees with the leg extended (the
    // curl's "down"), ~70-90 degrees curled under the seat (the
    // curl's "up").
    private static let legCurl = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
        downRange: 160...180,
        upRange: 70...90
    )
}
