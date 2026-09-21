import SwiftUI

public struct ChannelRowView: View {
    let channel: Channel
    let isCurrent: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void

    @ObservedObject var epgStore = EPGStore.shared
    @State private var isShowingEPGSheet: Bool = false

    public init(
        channel: Channel,
        isCurrent: Bool,
        onSelect: @escaping () -> Void,
        onToggleFavorite: @escaping () -> Void
    ) {
        self.channel = channel
        self.isCurrent = isCurrent
        self.onSelect = onSelect
        self.onToggleFavorite = onToggleFavorite
    }

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Channel Logo in Frosted Glass Frame
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 54, height: 54)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )

                    CachedAsyncImage(url: channel.logoURL, targetSize: CGSize(width: 108, height: 108)) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                            .cornerRadius(8)
                    } placeholder: {
                        Image(systemName: "tv")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                // Name, Group & EPG Program Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(channel.name)
                            .font(.system(size: 16, weight: isCurrent ? .bold : .semibold))
                            .foregroundColor(isCurrent ? .accentColor : .white)
                            .lineLimit(1)

                        if isCurrent {
                            HStack(spacing: 3) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text("Oynatılıyor")
                                    .font(.caption2.bold())
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }

                    // EPG Now Playing Info
                    if let program = epgStore.currentProgram(for: channel) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Text(program.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(1)

                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.4))

                                Text(program.timeRangeString)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            // Mini Progress Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(height: 3)
                                    Capsule()
                                        .fill(Color.accentColor)
                                        .frame(width: max(geo.size.width * CGFloat(program.progressPercentage), 2), height: 3)
                                }
                            }
                            .frame(height: 3)
                        }
                    } else {
                        Text(channel.groupTitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()

                // Large 48x48pt EPG Guide Button
                Button(action: {
                    isShowingEPGSheet = true
                }) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 48, height: 48)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(BorderlessButtonStyle())

                // Large 48x48pt Favorite Toggle Button
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    onToggleFavorite()
                }) {
                    Image(systemName: channel.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(channel.isFavorite ? .yellow : .white.opacity(0.45))
                        .frame(width: 48, height: 48)
                        .background(
                            channel.isFavorite ? Color.yellow.opacity(0.18) : Color.white.opacity(0.06)
                        )
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(
                                channel.isFavorite ? Color.yellow.opacity(0.5) : Color.white.opacity(0.15),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(12)
            .liquidGlassCard(cornerRadius: 16, isSelected: isCurrent)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $isShowingEPGSheet) {
            ChannelEPGSheetView(channel: channel)
        }
    }
}
