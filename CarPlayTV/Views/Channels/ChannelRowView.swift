import SwiftUI

public struct ChannelRowView: View {
    let channel: Channel
    let isCurrent: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void

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

                // Name & Group
                VStack(alignment: .leading, spacing: 4) {
                    Text(channel.name)
                        .font(.system(size: 16, weight: isCurrent ? .bold : .medium))
                        .foregroundColor(isCurrent ? .accentColor : .primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(channel.groupTitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(4)

                        if isCurrent {
                            HStack(spacing: 3) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text("Oynatılıyor")
                                    .font(.caption2.bold())
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }

                Spacer()

                // Favorite Toggle Button
                Button(action: onToggleFavorite) {
                    Image(systemName: channel.isFavorite ? "star.fill" : "star")
                        .foregroundColor(channel.isFavorite ? .yellow : .gray.opacity(0.5))
                        .font(.system(size: 18))
                        .padding(8)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
