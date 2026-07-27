import AVFoundation
import UIKit
import SwiftUI

struct LivePhotoMovieView: UIViewRepresentable {
    let url: URL
    let videoGravity: AVLayerVideoGravity
    let playTrigger: Int
    let autoplay: Bool
    var onPlaybackEnded: (() -> Void)?

    init(
        url: URL,
        videoGravity: AVLayerVideoGravity = .resizeAspectFill,
        playTrigger: Int = 0,
        autoplay: Bool = false,
        onPlaybackEnded: (() -> Void)? = nil
    ) {
        self.url = url
        self.videoGravity = videoGravity
        self.playTrigger = playTrigger
        self.autoplay = autoplay
        self.onPlaybackEnded = onPlaybackEnded
    }

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        context.coordinator.attach(layer: view.playerLayer)
        context.coordinator.configurePlayer(url: url, gravity: videoGravity)
        if autoplay {
            context.coordinator.play()
        }
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        context.coordinator.configurePlayer(url: url, gravity: videoGravity)

        if autoplay {
            if !context.coordinator.didAutoPlay {
                context.coordinator.didAutoPlay = true
                context.coordinator.play()
            }
        }

        if playTrigger != context.coordinator.lastPlayTrigger {
            context.coordinator.lastPlayTrigger = playTrigger
            context.coordinator.play()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPlaybackEnded: onPlaybackEnded)
    }

    final class Coordinator {
        weak var playerLayer: AVPlayerLayer?
        var player: AVPlayer?
        var playerItem: AVPlayerItem?
        var playbackEndedObserver: NSObjectProtocol?
        var lastSourceURL: URL?
        var lastPlayTrigger: Int = 0
        var didAutoPlay = false
        var onPlaybackEnded: (() -> Void)?

        init(onPlaybackEnded: (() -> Void)?) {
            self.onPlaybackEnded = onPlaybackEnded
        }

        deinit {
            if let observer = playbackEndedObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func attach(layer: AVPlayerLayer) {
            playerLayer = layer
            layer.player = player
            layer.videoGravity = .resizeAspect
        }

        func configurePlayer(url: URL, gravity: AVLayerVideoGravity) {
            if lastSourceURL == url { return }
            lastSourceURL = url
            didAutoPlay = false

            let item = AVPlayerItem(url: url)
            playerItem = item

            player = AVPlayer(playerItem: item)
            playerLayer?.videoGravity = gravity
            playerLayer?.player = player

            if let previousObserver = playbackEndedObserver {
                NotificationCenter.default.removeObserver(previousObserver)
                playbackEndedObserver = nil
            }

            playbackEndedObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                self?.player?.seek(to: .zero)
                self?.player?.pause()
                self?.onPlaybackEnded?()
            }
        }

        func play() {
            guard let player else { return }

            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("audio session error:", error)
            }

            player.seek(to: .zero)
            player.play()
        }
    }
}

final class PlayerContainerView: UIView {
    let playerLayer = AVPlayerLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
        layer.addSublayer(playerLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
