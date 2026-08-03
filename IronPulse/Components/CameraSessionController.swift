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
        sessionQueue.async { [weak self] in
            self?.configureSessionIfNeeded()
            self?.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func toggleCamera() {
        cameraPosition = cameraPosition == .back ? .front : .back
        sessionQueue.async { [weak self] in
            self?.reconfigureInput()
        }
    }

    private func configureSessionIfNeeded() {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        session.sessionPreset = .medium
        reconfigureInput()

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: sessionQueue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()
    }

    private func reconfigureInput() {
        session.beginConfiguration()
        if let currentInput {
            session.removeInput(currentInput)
        }

        let position: AVCaptureDevice.Position = cameraPosition == .back ? .back : .front
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
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
