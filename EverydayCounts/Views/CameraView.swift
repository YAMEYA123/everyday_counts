import SwiftUI
import AVFoundation

struct CameraView: View {
    let onCapture: (Data, URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraManager()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let layer = camera.previewLayer {
                PreviewLayerView(layer: layer).ignoresSafeArea()
            }
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.title2).foregroundStyle(.white).padding()
                    }
                    Spacer()
                }
                Spacer()
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
