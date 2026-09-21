import SwiftUI

public struct VODCardView: View {
    let item: VODItem
    let onSelect: () -> Void

    public init(item: VODItem, onSelect: @escaping () -> Void) {
        self.item = item
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Poster with Liquid Glass Frame
                ZStack(alignment: .bottomLeading) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .aspectRatio(2/3, contentMode: .fit)

                        CachedAsyncImage(url: item.posterURL, targetSize: CGSize(width: 320, height: 480)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Image(systemName: "film")
                                .font(.system(size: 36))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.28), Color.white.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)

                    // Type Badge Top-Trailing
                    VStack {
                        HStack {
                            Spacer()
                            Text(item.type == .movie ? "FİLM" : "DİZİ")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(item.type == .movie ? Color.accentColor : Color.purple)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .padding(8)
                        }
                        Spacer()
                    }

                    // Bottom Overlay Gradient
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.8)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Progress bar if partially watched
                    if item.progressPercent > 0 {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(height: 4)

                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(width: geo.size.width * CGFloat(item.progressPercent), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }

                    // Rating badge
                    if let rating = item.rating {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                        .padding(8)
                    }
                }

                // Title & Details
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(.white)

                    HStack(spacing: 6) {
                        if let year = item.year {
                            Text(year)
                        }
                        if item.duration > 0 {
                            Text("•")
                            Text(item.formattedDuration)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
