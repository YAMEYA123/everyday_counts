import AVFoundation
import Photos

@MainActor
class CameraManager: NSObject, ObservableObject {
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var isReady = false
    @Published var errorMessage: String?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var pendingImageData: Data?
    private var pendingMovieURL: URL?

    var onCapture: ((Data, URL) -> Void)?

    func setup() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status == .authorized || (await AVCaptureDevice.requestAccess(for: .video)) else {
            errorMessage = "需要相机权限"; return
        }
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            errorMessage = "无法访问摄像头"; return
        }
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
        session.commitConfiguration()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        previewLayer = layer
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async { self?.isReady = true }
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        if photoOutput.isLivePhotoCaptureEnabled {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
            settings.livePhotoMovieFileURL = url
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func stop() { session.stopRunning() }

    private func tryDeliver() {
        guard let imageData = pendingImageData, let movieURL = pendingMovieURL else { return }
        pendingImageData = nil; pendingMovieURL = nil
        onCapture?(imageData, movieURL)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                  didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else { return }
        Task { @MainActor in self.pendingImageData = data; self.tryDeliver() }
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                  didFinishProcessingLivePhotoToMovieFileAt url: URL,
                                  duration: CMTime, photoDisplayTime: CMTime,
                                  resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        Task { @MainActor in self.pendingMovieURL = url; self.tryDeliver() }
    }
}
