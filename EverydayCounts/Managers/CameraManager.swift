import AVFoundation
import Photos

enum FlashMode { case off, auto, on
    var next: FlashMode { switch self { case .off: return .auto; case .auto: return .on; case .on: return .off } }
    var icon: String { switch self { case .off: return "bolt.slash.fill"; case .auto: return "bolt.badge.a.fill"; case .on: return "bolt.fill" } }
    var avMode: AVCaptureDevice.FlashMode { switch self { case .off: return .off; case .auto: return .auto; case .on: return .on } }
}

struct ZoomPreset: Identifiable {
    let id = UUID()
    let label: String   // e.g. "0.5×", "1×", "3×"
    let factor: CGFloat // actual AVCaptureDevice videoZoomFactor
}

@MainActor
class CameraManager: NSObject, ObservableObject {
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var isReady = false
    @Published var errorMessage: String?
    @Published var flashMode: FlashMode = .off
    @Published var isLiveEnabled = false
    /// Raw AVCaptureDevice videoZoomFactor (not human-readable multiplier)
    @Published var zoomFactor: CGFloat = 1.0
    @Published var zoomPresets: [ZoomPreset] = []
    /// The device factor that equals "1×" (wide camera)
    private(set) var wideZoomFactor: CGFloat = 1.0

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private var pendingImageData: Data?
    private var pendingMovieURL: URL?
    private var deliverTask: Task<Void, Never>?

    var onCapture: ((Data, URL?) -> Void)?

    /// Human-readable zoom label (relative to wide = 1×)
    var zoomLabel: String {
        guard wideZoomFactor > 0 else { return "1×" }
        let relative = zoomFactor / wideZoomFactor
        if relative < 1.0 { return String(format: "%.1f×", relative) }
        return String(format: relative.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f×" : "%.1f×", relative)
    }

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

        // Build zoom presets.
        // virtualDeviceSwitchOverVideoZoomFactors: e.g. [2, 6] means
        //   device factor 1..2  → ultrawide (0.5×)
        //   device factor 2..6  → wide (1×)
        //   device factor 6+    → tele (3×)
        let switchFactors = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
        var presets: [ZoomPreset] = []
        if switchFactors.isEmpty {
            // Single camera — factor 1.0 = 1×
            wideZoomFactor = device.minAvailableVideoZoomFactor
            presets = [ZoomPreset(label: "1×", factor: wideZoomFactor)]
        } else {
            let wideFactor = switchFactors[0]   // device factor for 1× (wide)
            wideZoomFactor = wideFactor
            let minFactor = device.minAvailableVideoZoomFactor
            if minFactor < wideFactor {
                presets.append(ZoomPreset(label: "0.5×", factor: minFactor))
            }
            presets.append(ZoomPreset(label: "1×", factor: wideFactor))
            if switchFactors.count >= 2 {
                let teleFactor = switchFactors[1]
                let teleMultiplier = teleFactor / wideFactor
                let teleLabel = teleMultiplier.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(teleMultiplier))×" : String(format: "%.1f×", teleMultiplier)
                presets.append(ZoomPreset(label: teleLabel, factor: teleFactor))
            }
        }
        zoomPresets = presets
        // Default to wide (1×)
        zoomFactor = wideZoomFactor

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
        let clamped = max(device.minAvailableVideoZoomFactor,
                          min(factor, device.maxAvailableVideoZoomFactor))
        try? device.lockForConfiguration()
        device.videoZoomFactor = clamped
        device.unlockForConfiguration()
        zoomFactor = clamped
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
