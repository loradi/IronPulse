import AVFoundation
import Foundation

/// Owns the AVCaptureSession for the Smart Assistant's live camera
/// feed. Frames reach `onFrame` and are never written to disk, cached,
/// or kept beyond the caller's own processing of that single call —
/// see the design spec's "no video/frame storage" constraint.
@Observable
final class CameraSessionController: NSObject {
    enum AuthorizationState {
        case notDetermined
        case authorized
        case denied
    }

    enum CameraPosition {
        case front
        case back
    }

    private(set) var authorizationState: AuthorizationState = .notDetermined
    private(set) var cameraPosition: CameraPosition = .back

    let session = AVCaptureSession()
    @ObservationIgnored
    var onFrame: ((CVPixelBuffer) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.BERNU.WattWeight.camera-session")
    private var currentInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?

    deinit {
        // `stop()`'s `[weak self]` hop onto `sessionQueue` cannot fire
        // once we're already inside `deinit` (self is being torn down),
        // so it cannot be relied on here. Call directly on `session`
        // (not through `self`) as a belt-and-braces safety net in case
        // some dismissal path skipped `stop()`.
        session.stopRunning()
    }

    func requestAuthorizationIfNeeded() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorizationState = .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorizationState = granted ? .authorized : .denied
        default:
            authorizationState = .denied
        }
    }

    func start() {
        guard authorizationState == .authorized else { return }
        let position = cameraPosition
        sessionQueue.async { [weak self] in
            self?.configureSessionIfNeeded(position: position)
            self?.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func toggleCamera() {
        let newPosition: CameraPosition = cameraPosition == .back ? .front : .back
        cameraPosition = newPosition
        sessionQueue.async { [weak self] in
            self?.reconfigureInput(position: newPosition)
        }
    }

    // `position` is passed in rather than read from `cameraPosition` because this
    // runs on `sessionQueue` while `cameraPosition` is only ever written on the
    // main actor (from `toggleCamera()`) — reading the shared property here would
    // be an unsynchronized cross-thread data race.
    private func configureSessionIfNeeded(position: CameraPosition) {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        session.sessionPreset = .medium
        reconfigureInput(position: position)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: sessionQueue)
        if session.canAddOutput(output) {
            session.addOutput(output)
            videoOutput = output
        }
        session.commitConfiguration()
        updateVideoConnection(position: position)
    }

    private func reconfigureInput(position: CameraPosition) {
        session.beginConfiguration()
        if let currentInput {
            session.removeInput(currentInput)
        }

        let avPosition: AVCaptureDevice.Position = position == .back ? .back : .front
        // Ultra-wide first so the phone doesn't need to be propped far
        // away to fit a whole body in frame; falls back to the
        // standard wide lens on devices/positions without one (most
        // front cameras, older/cheaper iPhones).
        let device = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: avPosition)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: avPosition)
        guard let device,
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        currentInput = input
        session.commitConfiguration()
        updateVideoConnection(position: position)
    }

    // `AVCaptureVideoDataOutput` delivers buffers in the sensor's native
    // (unrotated) orientation — unlike `AVCaptureVideoPreviewLayer`, it
    // does NOT auto-rotate for you. This feature's primary use case is
    // the phone propped up in portrait, so we lock the connection's
    // rotation to portrait (90 degrees, the standard "upright portrait"
    // angle in the iOS 17+ `videoRotationAngle` API) so the buffers
    // `PoseDetectorService` receives are already upright — see the `.up`
    // comment in `PoseDetectorService.detectJoints` for the other half
    // of this.
    //
    // Mirroring is deliberately forced OFF here, on every camera
    // position, and left untouched on the preview layer's own
    // (separate) connection. `AVCaptureVideoPreviewLayer` mirrors the
    // front camera automatically by default — that's what gives the
    // expected "selfie mirror" preview. If this data-output connection
    // also mirrored the buffer Vision sees, `CameraPreviewView`'s
    // `layerRectConverted(fromMetadataOutputRect:)` would end up
    // compensating for the preview's mirroring on top of a point that
    // was already computed from a mirrored buffer — two mirrors
    // canceling out, leaving the drawn skeleton geometrically
    // unmirrored while the video underneath it is mirrored, so the
    // skeleton visibly moves opposite to the user's real movement on
    // front camera. Keeping Vision's buffer in its natural, unmirrored
    // state avoids this, and keeps Vision's own left/right joint
    // labeling anatomically correct too (its body-pose model expects a
    // natural, not artificially mirrored, image).
    //
    // This hardcodes portrait rather than using
    // `AVCaptureDevice.RotationCoordinator` to track live device
    // orientation, since the assistant UI itself doesn't rotate — if a
    // future version supports landscape use, this needs revisiting.
    private func updateVideoConnection(position: CameraPosition) {
        guard let connection = videoOutput?.connection(with: .video) else { return }
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
    }
}

extension CameraSessionController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame?(pixelBuffer)
    }
}
