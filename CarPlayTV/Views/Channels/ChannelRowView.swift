import SwiftUI

public struct ChannelRowView: View {
    let channel: Channel
    let isCurrent: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void

    @ObservedObject var epgStore = EPGStore.shared
    @State private var isShowingEPGSheet: Bool = false

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Channel Logo
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .frame(width: 50, height: 50)

                    CachedAsyncImage(url: channel.logoURL, targetSize: CGSize(width: 84, height: 84)) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 42, height: 42)
                            .cornerRadius(6)
                    } placeholder: {
                        Image(systemName: "tv")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }

                // Name, Group & EPG Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(channel.name)
                            .font(.system(size: 16, weight: isCurrent ? .bold : .medium))
                            .foregroundColor(isCurrent ? .accentColor : .primary)
                            .lineLimit(1)

                        if isCurrent {
                            HStack(spacing: 3) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text("Oynatılıyor")
                                    .font(.caption2.bold())
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    // EPG Now Playing Info
                    if let program = epgStore.currentProgram(for: channel) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(program.title)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.primary.opacity(0.85))
                                    .lineLimit(1)

                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Text(program.timeRangeString)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            // Mini Progress Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 2.5)
                                    Capsule()
                                        .fill(Color.accentColor)
                                        .frame(width: max(geo.size.width * CGFloat(program.progressPercentage), 2), height: 2.5)
                                }
                            }
                            .frame(height: 2.5)
                        }
                    } else {
                        Text(channel.groupTitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // EPG Schedule Button
                Button(action: {
                    isShowingEPGSheet = true
                }) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(6)
                }
                .buttonStyle(BorderlessButtonStyle())

                // Favorite Toggle Button
                Button(action: onToggleFavorite) {
                    Image(systemName: channel.isFavorite ? "star.fill" : "star")
                        .foregroundColor(channel.isFavorite ? .yellow : .gray.opacity(0.5))
                        .font(.system(size: 18))
                        .padding(6)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $isShowingEPGSheet) {
            ChannelEPGSheetView(channel: channel)
        }
    }
}
