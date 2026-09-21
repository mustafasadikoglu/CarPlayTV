import SwiftUI

public struct VODCardView: View {
    let item: VODItem
    let onSelect: () -> Void

    public var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                // Poster
                ZStack(alignment: .bottomLeading) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .aspectRatio(2/3, contentMode: .fit)

                        if let poster = item.posterURL {
                            AsyncImage(url: poster) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .empty:
                                    ProgressView()
                                default:
                                    Image(systemName: "film")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                }
                            }
                        } else {
                            Image(systemName: "film")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

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
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                        .padding(6)
                    }
                }

                // Title & Details
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.primary)

                HStack(spacing: 6) {
                    if let year = item.year {
                        Text(year)
                    }
                    if item.duration > 0 {
                        Text("•")
                        Text(item.formattedDuration)
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
