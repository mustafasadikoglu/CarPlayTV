import SwiftUI

public struct FullscreenPlayerView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var playback = PlaybackManager.shared

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if playback.isVLCPlayback {
                VLCVideoPlayerView()
                    .ignoresSafeArea()
            } else {
                CustomVideoPlayerView()
                    .ignoresSafeArea()
            }

            VideoControlsOverlayView(onClose: {
                playback.stopPlayback()
                dismiss()
            })
        }
        .statusBar(hidden: true)
        .navigationBarHidden(true)
    }
}
