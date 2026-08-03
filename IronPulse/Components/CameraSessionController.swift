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
    var onFrame: ((CVPixelBuffer) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.BERNU.WattWeight.camera-session")
    private var currentInput: AVCaptureDeviceInput?

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
        }
        session.commitConfiguration()
    }

    private func reconfigureInput(position: CameraPosition) {
        session.beginConfiguration()
        if let currentInput {
            session.removeInput(currentInput)
        }

        let avPosition: AVCaptureDevice.Position = position == .back ? .back : .front
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: avPosition),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        currentInput = input
        session.commitConfiguration()
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
