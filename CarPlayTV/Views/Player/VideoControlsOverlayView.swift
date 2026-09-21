import SwiftUI

public struct VideoControlsOverlayView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @State private var areControlsVisible: Bool = true
    @State private var hideTimer: Timer?
    @State private var brightnessValue: CGFloat = UIScreen.main.brightness
    @State private var volumeGestureOffset: CGFloat = 0

    var onClose: (() -> Void)?

    public init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            // Background tap to toggle controls
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleControls()
                }

            if areControlsVisible {
                VStack {
                    // Top Bar
                    HStack(spacing: 12) {
                        if let onClose = onClose {
                            Button(action: onClose) {
                                Image(systemName: "chevron.down.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }

                        if let channel = playback.currentChannel {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                    Text("CANLI")
                                        .font(.caption2.bold())
                                        .foregroundColor(.red)

                                    Text("•")
                                        .foregroundColor(.white.opacity(0.4))

                                    Text(channel.groupTitle)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }

                                Text(channel.name)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        // CarPlay status indicator
                        if playback.isCarPlayConnected {
                            HStack(spacing: 4) {
                                Image(systemName: "car.fill")
                                    .font(.caption)
                                Text(playback.isExternalVideoActive ? "CarPlay Video" : "CarPlay Bağlı")
                                    .font(.caption2.bold())
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(playback.isExternalVideoActive ? Color.green.opacity(0.3) : Color.blue.opacity(0.3))
                            .foregroundColor(playback.isExternalVideoActive ? .green : .blue)
                            .cornerRadius(8)
                        }

                        // Aspect ratio toggle button
                        Menu {
                            ForEach(VideoAspectRatio.allCases, id: \.self) { ratio in
                                Button(action: {
                                    playback.aspectRatio = ratio
                                    CarPlayVideoWindowController.shared.updateAspectRatio(ratio)
                                }) {
                                    HStack {
                                        Text(ratio.rawValue)
                                        if playback.aspectRatio == ratio {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "aspectratio")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.9))
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.black.opacity(0.8), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    Spacer()

                    // Center Buffering or Error Indicator
                    if playback.isBuffering {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.6)
                            .padding(24)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                    } else if let error = playback.playbackError {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                                .font(.largeTitle)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }

                    Spacer()

                    // Bottom Player Controls
                    HStack(spacing: 40) {
                        // Previous Channel
                        Button(action: {
                            playback.playPreviousChannel()
                            resetTimer()
                        }) {
                            Image(systemName: "backward.end.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }

                        // Play / Pause
                        Button(action: {
                            playback.togglePlayPause()
                            resetTimer()
                        }) {
                            Image(systemName: playback.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 56))
                                .foregroundColor(.white)
                        }

                        // Next Channel
                        Button(action: {
                            playback.playNextChannel()
                            resetTimer()
                        }) {
                            Image(systemName: "forward.end.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 32)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
        .onAppear {
            resetTimer()
        }
    }

    private func toggleControls() {
        withAnimation {
            areControlsVisible.toggle()
        }
        if areControlsVisible {
            resetTimer()
        }
    }

    private func resetTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            withAnimation {
                areControlsVisible = false
            }
        }
    }
}
