import SwiftUI
import UIKit
import VLCKit

/// MobileVLCKit'in video çıktısını SwiftUI içinde gösteren sarmalayıcı görünüm.
public struct VLCVideoPlayerView: UIViewRepresentable {
    private let controller = VLCPlaybackController.shared

    public init() {}

    public func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        controller.player.drawable = view
        return view
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        // VLCKit 4.0'da drawable Any? türündedir; doğrudan ata.
        controller.player.drawable = uiView
    }
}
