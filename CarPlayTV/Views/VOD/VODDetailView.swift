import SwiftUI

public struct VODDetailView: View {
    @Environment(\.dismiss) var dismiss
    let item: VODItem
    var series: Series?
    let onPlay: (VODItem, Bool) -> Void

    @State private var selectedSeason: Int = 1

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Backdrop / Poster Image
                    ZStack(alignment: .bottomLeading) {
                        CachedAsyncImage(url: item.backdropURL ?? item.posterURL, targetSize: CGSize(width: 600, height: 350)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 240)
                                .clipped()
                        } placeholder: {
                            Rectangle()
                                .fill(Color(UIColor.secondarySystemBackground))
                                .frame(height: 240)
                        }

                        LinearGradient(
                            colors: [.clear, Color(UIColor.systemBackground)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 120)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                if let rating = item.rating {
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                            .font(.caption)
                                        Text(String(format: "%.1f", rating))
                                            .font(.caption.bold())
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(6)
                                }

                                if let year = item.year {
                                    Text(year)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if item.duration > 0 {
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    Text(item.formattedDuration)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Text(series?.title ?? item.title)
                                .font(.title2.bold())
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal)
                    }

                    // Play Buttons
                    VStack(spacing: 10) {
                        if item.lastPosition > 10 {
                            Button(action: {
                                onPlay(item, false)
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Kaldığın Yerden Devam Et (\(formatTime(item.lastPosition)))")
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }

                            Button(action: {
                                onPlay(item, true)
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Baştan Başlat")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .foregroundColor(.secondary)
                            }
                        } else {
                            Button(action: {
                                onPlay(item, true)
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Şimdi Oynat")
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Synopsis / Plot
                    if let plot = series?.plot ?? item.plot {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Konu")
                                .font(.headline)
                            Text(plot)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal)
                    }

                    // Series Seasons and Episodes
                    if let s = series, !s.seasons.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Bölümler")
                                .font(.headline)
                                .padding(.horizontal)

                            // Season selector
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(s.seasons) { season in
                                        Button(action: {
                                            selectedSeason = season.seasonNumber
                                        }) {
                                            Text(season.name)
                                                .font(.caption.bold())
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(selectedSeason == season.seasonNumber ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                                                .foregroundColor(selectedSeason == season.seasonNumber ? .white : .primary)
                                                .cornerRadius(16)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }

                            // Episode list
                            if let season = s.seasons.first(where: { $0.seasonNumber == selectedSeason }) {
                                ForEach(season.episodes) { ep in
                                    Button(action: {
                                        onPlay(ep, false)
                                        dismiss()
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "play.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.accentColor)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(ep.title)
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(.primary)
                                                Text(ep.formattedDuration)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                        }
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(10)
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
