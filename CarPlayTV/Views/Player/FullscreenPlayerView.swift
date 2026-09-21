import SwiftUI

public struct FullscreenPlayerView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var playback = PlaybackManager.shared

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CustomVideoPlayerView()
                .ignoresSafeArea()

            VideoControlsOverlayView(onClose: {
                dismiss()
            })
        }
        .statusBar(hidden: true)
        .navigationBarHidden(true)
    }
}
