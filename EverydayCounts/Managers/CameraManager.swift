import AVFoundation
import Photos

enum FlashMode { case off, auto, on
    var next: FlashMode { switch self { case .off: return .auto; case .auto: return .on; case .on: return .off } }
    var icon: String { switch self { case .off: return "bolt.slash.fill"; case .auto: return "bolt.badge.a.fill"; case .on: return "bolt.fill" } }
    var avMode: AVCaptureDevice.FlashMode { switch self { case .off: return .off; case .auto: return .auto; case .on: return .on } }
}

@MainActor
class CameraManager: NSObject, ObservableObject {
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var isReady = false
    @Published var errorMessage: String?
    @Published var flashMode: FlashMode = .off
    @Published var isLiveEnabled = false
    @Published var zoomFactor: CGFloat = 1.0
    @Published var availableZooms: [CGFloat] = [1.0]

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private var pendingImageData: Data?
    private var pendingMovieURL: URL?
    private var deliverTask: Task<Void, Never>?

    var onCapture: ((Data, URL?) -> Void)?

    func setup() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status != .authorized {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else { errorMessage = "需要相机权限"; return }
        }
        if AVCaptureDevice.authorizationStatus(for: .audio) != .authorized {
            await AVCaptureDevice.requestAccess(for: .audio)
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        // Try to get a multi-camera discovery session for zoom presets
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera],
            mediaType: .video, position: .back)
        guard let device = discovery.devices.first,
              let input = try? AVCaptureDeviceInput(device: device) else {
            errorMessage = "无法访问摄像头"; return
        }
        currentDevice = device
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

        // Compute available zoom presets from virtual device
        var zooms: [CGFloat] = []
        if let factors = (device as AnyObject).virtualDeviceSwitchOverVideoZoomFactors as? [NSNumber], !factors.isEmpty {
            // ultrawide is at factor 1 on some devices; wide is factors[0]
            let wideIdx = factors.first.map { CGFloat(truncating: $0) } ?? 2.0
            if wideIdx > 1.0 { zooms.append(1.0) }   // ultrawide
            zooms.append(wideIdx)                      // wide (1x)
            if factors.count >= 2 {
                zooms.append(CGFloat(truncating: factors[1]))  // tele
            }
        }
        if zooms.isEmpty { zooms = [1.0] }
        availableZooms = zooms
        zoomFactor = zooms.contains(where: { abs($0 - 1.0) < 0.1 }) ? 1.0 : zooms.first ?? 1.0

        // Live Photo: enable only if mic is authorized
        let micOK = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        photoOutput.isLivePhotoCaptureEnabled = micOK && photoOutput.isLivePhotoCaptureSupported
        isLiveEnabled = photoOutput.isLivePhotoCaptureEnabled

        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        previewLayer = layer

        let captureSession = session
        Task.detached(priority: .userInitiated) {
            captureSession.startRunning()
            await MainActor.run { self.isReady = true }
        }
    }

    func toggleLive() {
        guard photoOutput.isLivePhotoCaptureSupported else { return }
        isLiveEnabled.toggle()
        photoOutput.isLivePhotoCaptureEnabled = isLiveEnabled
    }

    func toggleFlash() { flashMode = flashMode.next }

    func setZoom(_ factor: CGFloat) {
        guard let device = currentDevice else { return }
        try? device.lockForConfiguration()
        device.videoZoomFactor = max(device.minAvailableVideoZoomFactor,
                                     min(factor, device.maxAvailableVideoZoomFactor))
        device.unlockForConfiguration()
        zoomFactor = factor
    }

    func capturePhoto() {
        pendingImageData = nil
        pendingMovieURL = nil
        deliverTask?.cancel()

        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        settings.flashMode = flashMode.avMode
        if photoOutput.isLivePhotoCaptureEnabled {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
            settings.livePhotoMovieFileURL = url
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func stop() { session.stopRunning() }

    private func scheduleDeliver() {
        deliverTask?.cancel()
        deliverTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            deliver()
        }
    }

    private func deliver() {
        guard let imageData = pendingImageData else { return }
        let movie = pendingMovieURL
        pendingImageData = nil
        pendingMovieURL = nil
        deliverTask = nil
        onCapture?(imageData, movie)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                  didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else { return }
        Task { @MainActor in
            self.pendingImageData = data
            if !self.photoOutput.isLivePhotoCaptureEnabled {
                self.deliver()
            } else {
                self.scheduleDeliver()
            }
        }
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                  didFinishProcessingLivePhotoToMovieFileAt url: URL,
                                  duration: CMTime, photoDisplayTime: CMTime,
                                  resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        Task { @MainActor in
            self.pendingMovieURL = url
            if self.pendingImageData != nil { self.deliver() }
        }
    }
}
