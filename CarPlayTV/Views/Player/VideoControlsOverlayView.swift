import SwiftUI

public struct VideoControlsOverlayView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var epgStore = EPGStore.shared
    @State private var areControlsVisible: Bool = true
    @State private var hideTimer: Timer?
    @State private var isShowingEPGSheet: Bool = false

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
                VStack(spacing: 0) {
                    // Top Floating Liquid Glass Island
                    topFloatingBar
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    Spacer()

                    // Center Buffering or Error Indicator
                    centerStatusView

                    Spacer()

                    // Bottom Floating Liquid Glass Dock
                    bottomFloatingDock
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)).animation(.easeInOut(duration: 0.22)))
            }
        }
        .onAppear {
            resetTimer()
        }
        .sheet(isPresented: $isShowingEPGSheet) {
            if let channel = playback.currentChannel {
                ChannelEPGSheetView(channel: channel)
            }
        }
    }

    // MARK: - Top Floating Glass Bar
    private var topFloatingBar: some View {
        HStack(spacing: 12) {
            if let onClose = onClose {
                Button(action: onClose) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white.opacity(0.95))
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.28), lineWidth: 1.2)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 2)
                }
            }

            if playback.isLiveStream {
                if let channel = playback.currentChannel {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 7, height: 7)
                                .shadow(color: .red.opacity(0.8), radius: 4, x: 0, y: 0)

                            Text("CANLI")
                                .font(.caption2.bold())
                                .foregroundColor(.red)

                            Text("•")
                                .foregroundColor(.white.opacity(0.3))

                            Text(channel.groupTitle)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.75))
                                .lineLimit(1)
                        }

                        HStack(spacing: 6) {
                            Text(channel.name)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .lineLimit(1)

                            if let prog = epgStore.currentProgram(for: channel) {
                                Text("•")
                                    .foregroundColor(.white.opacity(0.3))
                                Text(prog.title)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            } else {
                if let vod = playback.currentVODItem {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(vod.type == .movie ? "FİLM" : "DİZİ")
                                .font(.caption2.bold())
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                            Text("•")
                                .foregroundColor(.white.opacity(0.3))

                            Text(vod.categoryName)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.75))
                                .lineLimit(1)
                        }

                        Text(vod.title)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // CarPlay indicator
            if playback.isCarPlayConnected {
                HStack(spacing: 4) {
                    Image(systemName: "car.fill")
                        .font(.caption2)
                    Text(playback.isExternalVideoActive ? "CarPlay Video" : "CarPlay")
                        .font(.caption2.bold())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(playback.isExternalVideoActive ? Color.green.opacity(0.25) : Color.blue.opacity(0.25))
                .foregroundColor(playback.isExternalVideoActive ? .green : .blue)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke((playback.isExternalVideoActive ? Color.green : Color.blue).opacity(0.4), lineWidth: 1)
                )
            }

            // Aspect ratio menu
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
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.28), lineWidth: 1.2)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 2)
            }

            // EPG Sheet Button for Live Stream
            if playback.isLiveStream && playback.currentChannel != nil {
                Button(action: {
                    isShowingEPGSheet = true
                }) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.95))
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.28), lineWidth: 1.2)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 2)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 14, x: 0, y: 6)
    }

    // MARK: - Center Status View
    @ViewBuilder
    private var centerStatusView: some View {
        if playback.isBuffering && !playback.hasStartedPlayback {
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.4)

                Text("Bağlanıyor...")
                    .font(.caption2.bold())
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 20, x: 0, y: 8)
        } else if let error = playback.playbackError {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.title)

                Text(error)
                    .font(.caption)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 6)
        }
    }

    // MARK: - Bottom Floating Liquid Glass Dock
    private var bottomFloatingDock: some View {
        VStack(spacing: 14) {
            // VOD Scrubber Slider
            if !playback.isLiveStream && playback.duration > 0 {
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { playback.currentTime },
                            set: { playback.seek(to: $0) }
                        ),
                        in: 0...max(playback.duration, 1)
                    )
                    .accentColor(.accentColor)

                    HStack {
                        Text(formatTime(playback.currentTime))
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text(formatTime(playback.duration))
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 4)
            }

            // Oynatma hızı / altyazı / ses şeridi (VOD)
            if !playback.isLiveStream {
                HStack(spacing: 10) {
                    Button(action: {
                        playback.cyclePlaybackRate()
                        resetTimer()
                    }) {
                        Text(rateLabel(playback.playbackRate))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 32)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
                    }

                    if !playback.subtitleTracks.isEmpty {
                        Button(action: {
                            playback.cycleSubtitle()
                            resetTimer()
                        }) {
                            Image(systemName: playback.currentSubtitleIndex >= 0 ? "captions.bubble.fill" : "captions.bubble")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(playback.currentSubtitleIndex >= 0 ? Color.accentColor : .white.opacity(0.75))
                                .frame(width: 44, height: 32)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
                        }
                    }

                    if !playback.audioTracks.isEmpty {
                        Button(action: {
                            playback.cycleAudioTrack()
                            resetTimer()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("\(playback.audioTracks.count)")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            // Playback Buttons Dock
            HStack(spacing: 42) {
                if playback.isLiveStream {
                    // Previous Channel (56x56)
                    Button(action: {
                        playback.playPreviousChannel()
                        resetTimer()
                    }) {
                        Image(systemName: "backward.end.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white.opacity(0.95))
                            .frame(width: 56, height: 56)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.28), lineWidth: 1.2)
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 3)
                    }
                } else {
                    // Skip Backward 10s (56x56)
                    Button(action: {
                        playback.skipBackward(seconds: 10)
                        resetTimer()
                    }) {
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white.opacity(0.95))
                            .frame(width: 56, height: 56)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.28), lineWidth: 1.2)
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 3)
                    }
                }

                // Play / Pause Main Glass Orb (76x76)
                Button(action: {
                    playback.togglePlayPause()
                    resetTimer()
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.9),
                                        Color.accentColor.opacity(0.65)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 76, height: 76)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.6), .white.opacity(0.15)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: Color.accentColor.opacity(0.5), radius: 14, x: 0, y: 6)

                        Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                if playback.isLiveStream {
                    // Next Channel (56x56)
                    Button(action: {
                        playback.playNextChannel()
                        resetTimer()
                    }) {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white.opacity(0.95))
                            .frame(width: 56, height: 56)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.28), lineWidth: 1.2)
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 3)
                    }
                } else {
                    // Skip Forward 10s (56x56)
                    Button(action: {
                        playback.skipForward(seconds: 10)
                        resetTimer()
                    }) {
                        Image(systemName: "goforward.10")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white.opacity(0.95))
                            .frame(width: 56, height: 56)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.28), lineWidth: 1.2)
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 3)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 18, x: 0, y: 8)
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func rateLabel(_ rate: Float) -> String {
        switch rate {
        case 1.25: return "1.25x"
        case 1.5: return "1.5x"
        case 2.0: return "2x"
        case 0.5: return "0.5x"
        default: return "1x"
        }
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            areControlsVisible.toggle()
        }
        if areControlsVisible {
            resetTimer()
        }
    }

    private func resetTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 4.5, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                areControlsVisible = false
            }
        }
    }
}
