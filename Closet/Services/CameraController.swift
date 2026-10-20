import AVFoundation
import SwiftUI
import UIKit

enum CameraState: Equatable {
    case idle, running, denied, unavailable
}

/// Runs the back camera for the scan screen and captures stills. All mutable state
/// is only touched on `queue`, which is what makes the unchecked Sendable safe.
final class CameraController: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    enum CaptureError: Error {
        case notRunning, noData
    }

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "closet.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var pendingCapture: CheckedContinuation<UIImage, Error>?

    /// Asks for permission if needed, configures the session and starts it.
    func start(_ completion: @escaping (CameraState) -> Void) {
        let finish: (CameraState) -> Void = { state in
            DispatchQueue.main.async { completion(state) }
        }
        // No camera (e.g. the Simulator): don't ask for a permission we can't use.
        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil else {
            finish(.unavailable)
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession(finish)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { self.startSession(finish) } else { finish(.denied) }
            }
        default:
            finish(.denied)
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func capture() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.session.isRunning, self.pendingCapture == nil else {
                    continuation.resume(throwing: CaptureError.notRunning)
                    return
                }
                self.pendingCapture = continuation
                self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
        }
    }

    private func startSession(_ finish: @escaping (CameraState) -> Void) {
        queue.async {
            if !self.isConfigured {
                guard self.configure() else {
                    finish(.unavailable)
                    return
                }
                self.isConfigured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
            finish(self.session.isRunning ? .running : .unavailable)
        }
    }

    private func configure() -> Bool {
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device)
        else { return false }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard session.canAddInput(input), session.canAddOutput(photoOutput) else { return false }
        session.addInput(input)
        session.addOutput(photoOutput)

        if (try? device.lockForConfiguration()) != nil {
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            device.unlockForConfiguration()
        }
        return true
    }

    // MARK: AVCapturePhotoCaptureDelegate

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        queue.async {
            guard let continuation = self.pendingCapture else { return }
            self.pendingCapture = nil
            if let error {
                continuation.resume(throwing: error)
            } else if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
                continuation.resume(returning: image)
            } else {
                continuation.resume(throwing: CaptureError.noData)
            }
        }
    }
}

/// Live preview of the capture session.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
