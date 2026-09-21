import SwiftUI

public struct VODDetailView: View {
    @Environment(\.dismiss) var dismiss
    let item: VODItem
    var series: Series?
    let onPlay: (VODItem, Bool) -> Void

    @State private var currentSeries: Series?
    @State private var selectedSeason: Int = 1
    @State private var isLoadingEpisodes: Bool = false

    public init(item: VODItem, series: Series? = nil, onPlay: @escaping (VODItem, Bool) -> Void) {
        self.item = item
        self.series = series
        self.onPlay = onPlay
        self._currentSeries = State(initialValue: series)
        self._selectedSeason = State(initialValue: series?.seasons.first?.seasonNumber ?? 1)
    }

    private var activePlayableItem: VODItem {
        if let s = currentSeries,
           let season = s.seasons.first(where: { $0.seasonNumber == selectedSeason }),
           let firstEp = season.episodes.first {
            return firstEp
        }
        return item
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Backdrop Header with Glass Overlays
                        backdropHeader

                        // Action Play Buttons (Large 54pt touch target)
                        playButtonsSection

                        // Synopsis / Plot
                        plotSection

                        // Series Seasons & Episode Browser
                        if currentSeries != nil {
                            episodesSection
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                    }
                }
            }
            .task {
                if let s = currentSeries {
                    if s.seasons.isEmpty || !s.seasons.contains(where: { !$0.episodes.isEmpty }) {
                        isLoadingEpisodes = true
                        let loaded = await VODStore.shared.fetchSeriesEpisodes(for: s)
                        self.currentSeries = loaded
                        if let firstSeason = loaded.seasons.first {
                            self.selectedSeason = firstSeason.seasonNumber
                        }
                        isLoadingEpisodes = false
                    }
                }
            }
        }
    }

    // MARK: - Backdrop Header
    private var backdropHeader: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(
                url: item.backdropURL ?? item.posterURL ?? currentSeries?.backdropURL ?? currentSeries?.coverURL,
                targetSize: CGSize(width: 800, height: 450)
            ) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(height: 270)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 270)
            }

            // Glass Gradient Overlay
            LinearGradient(
                colors: [
                    Color.clear,
                    Color(red: 0.05, green: 0.06, blue: 0.09).opacity(0.4),
                    Color(red: 0.05, green: 0.06, blue: 0.09)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)

            // Title and Metadata Chips
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    // Type Badge
                    Text(currentSeries != nil ? "DİZİ" : "FİLM")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .clipShape(Capsule())

                    if let rating = item.rating ?? currentSeries?.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption2)
                            Text(String(format: "%.1f", rating))
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }

                    if let year = item.year ?? currentSeries?.year {
                        Text(year)
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }

                    if item.duration > 0 {
                        Text(item.formattedDuration)
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                }

                Text(currentSeries?.title ?? item.title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 3)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Play Buttons Section
    private var playButtonsSection: some View {
        VStack(spacing: 12) {
            if activePlayableItem.lastPosition > 10 {
                Button(action: {
                    onPlay(activePlayableItem, false)
                    dismiss()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("Kaldığın Yerden Devam Et (\(formatTime(activePlayableItem.lastPosition)))")
                    }
                }
                .buttonStyle(LiquidGlassButtonStyle(isPrimary: true, minHeight: 54))

                Button(action: {
                    onPlay(activePlayableItem, true)
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Baştan Başlat")
                    }
                }
                .buttonStyle(LiquidGlassButtonStyle(isPrimary: false, minHeight: 48))
            } else {
                Button(action: {
                    onPlay(activePlayableItem, true)
                    dismiss()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 20, weight: .bold))
                        if currentSeries != nil {
                            Text("1. Bölümü Oynat")
                        } else {
                            Text("Şimdi Oynat")
                        }
                    }
                }
                .buttonStyle(LiquidGlassButtonStyle(isPrimary: true, minHeight: 54))
            }
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Plot Section
    @ViewBuilder
    private var plotSection: some View {
        if let plot = currentSeries?.plot ?? item.plot, !plot.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Özet")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text(plot)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: 16)
            .padding(.horizontal, 18)
        }
    }

    // MARK: - Episodes Section
    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Bölümler")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                if isLoadingEpisodes {
                    HStack(spacing: 6) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Yükleniyor...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 18)

            if let s = currentSeries, !s.seasons.isEmpty {
                // Season Selector Pills (Large 44pt Touch Target)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(s.seasons) { season in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedSeason = season.seasonNumber
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Text(season.name)
                                        .font(.system(size: 15, weight: .semibold))
                                    if !season.episodes.isEmpty {
                                        Text("(\(season.episodes.count))")
                                            .font(.caption2.bold())
                                            .foregroundColor(selectedSeason == season.seasonNumber ? .white.opacity(0.9) : .secondary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                                .background(
                                    ZStack {
                                        if selectedSeason == season.seasonNumber {
                                            Color.accentColor
                                        } else {
                                            Color.white.opacity(0.08)
                                        }
                                    }
                                )
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            selectedSeason == season.seasonNumber
                                                ? Color.white.opacity(0.5)
                                                : Color.white.opacity(0.18),
                                            lineWidth: 1
                                        )
                                )
                                .foregroundColor(.white)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 18)
                }

                // Selected Season Episode Cards List
                if let activeSeason = s.seasons.first(where: { $0.seasonNumber == selectedSeason }) {
                    if activeSeason.episodes.isEmpty {
                        VStack(spacing: 8) {
                            Text("Bu sezonda kayıtlı bölüm bulunamadı.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .liquidGlass(cornerRadius: 16)
                        .padding(.horizontal, 18)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(activeSeason.episodes) { ep in
                                episodeRow(ep)
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                }
            } else if isLoadingEpisodes {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    Text("Sezonlar ve bölümler hazırlanıyor...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .liquidGlass(cornerRadius: 16)
                .padding(.horizontal, 18)
            }
        }
    }

    // MARK: - Single Episode Glass Row
    private func episodeRow(_ ep: VODItem) -> some View {
        Button(action: {
            onPlay(ep, false)
            dismiss()
        }) {
            HStack(spacing: 14) {
                // Episode Thumbnail with Glass Duration Badge
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(
                        url: ep.posterURL ?? ep.backdropURL ?? item.posterURL ?? currentSeries?.coverURL,
                        targetSize: CGSize(width: 220, height: 140)
                    ) { img in
                        img
                            .resizable()
                            .scaledToFill()
                            .frame(width: 110, height: 72)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 110, height: 72)
                            .overlay(
                                Image(systemName: "film")
                                    .foregroundColor(.white.opacity(0.4))
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // Duration chip
                    if ep.duration > 0 {
                        Text(ep.formattedDuration)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(4)
                    }
                }

                // Episode Info
                VStack(alignment: .leading, spacing: 4) {
                    if let epNum = ep.episodeNumber {
                        Text("\(epNum). Bölüm")
                            .font(.caption2.bold())
                            .foregroundColor(.accentColor)
                    }

                    Text(ep.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    if let plot = ep.plot, !plot.isEmpty {
                        Text(plot)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Large 48x48pt Play Button
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle().stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                        )

                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(12)
            .liquidGlassCard(cornerRadius: 16)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
