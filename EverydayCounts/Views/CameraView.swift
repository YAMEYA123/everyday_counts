import SwiftUI
import AVFoundation

struct CameraView: View {
    let onCapture: (Data, URL?) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraManager()
    @State private var pinchBaseZoom: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                // Top bar: close + flash + live
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.title3).foregroundStyle(.white).padding(12)
                    }
                    Spacer()
                    Button { camera.toggleFlash() } label: {
                        Image(systemName: camera.flashMode.icon)
                            .font(.title3).foregroundStyle(.yellow).padding(12)
                    }
                    Button { camera.toggleLive() } label: {
                        Text("LIVE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(camera.isLiveEnabled ? .yellow : .white.opacity(0.5))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .overlay(RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(camera.isLiveEnabled ? Color.yellow : .white.opacity(0.3), lineWidth: 1))
                            .padding(.trailing, 12)
                    }
                }
                .padding(.top, 8)

                // Viewfinder — 4:3 ratio, not full screen
                if let layer = camera.previewLayer {
                    GeometryReader { geo in
                        PreviewLayerView(layer: layer)
                            .frame(width: geo.size.width, height: geo.size.width * 4 / 3)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .padding(.horizontal, 0)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                }

                Spacer()

                // Zoom presets
                if camera.availableZooms.count > 1 {
                    HStack(spacing: 16) {
                        ForEach(camera.availableZooms, id: \.self) { z in
                            let isActive = abs(camera.zoomFactor - z) < 0.05
                            Button { camera.setZoom(z) } label: {
                                Text(zoomLabel(z))
                                    .font(.system(size: 13, weight: isActive ? .bold : .regular))
                                    .foregroundStyle(isActive ? .yellow : .white.opacity(0.7))
                                    .frame(width: 40, height: 40)
                                    .background(Color.white.opacity(isActive ? 0.15 : 0.05))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }

                // Shutter
                Button { camera.capturePhoto() } label: {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 72, height: 72)
                        .overlay(Circle().fill(.white).padding(6))
                }
                .padding(.bottom, 48)
            }
        }
        .task {
            camera.onCapture = { data, url in
                camera.stop()
                onCapture(data, url)
            }
            await camera.setup()
        }
    }

    private func zoomLabel(_ factor: CGFloat) -> String {
        if factor < 1.0 { return "0.5×" }
        if abs(factor - 1.0) < 0.1 { return "1×" }
        return "\(Int(factor.rounded()))×"
    }
}

struct PreviewLayerView: UIViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer = layer
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}

class PreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            guard let layer = previewLayer else { return }
            layer.frame = bounds
            layer.videoGravity = .resizeAspectFill
            self.layer.addSublayer(layer)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer?.frame = bounds
        CATransaction.commit()
    }
}
