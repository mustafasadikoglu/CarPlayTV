import SwiftUI

public struct VODHomeView: View {
    @ObservedObject var store = VODStore.shared
    @ObservedObject var playback = PlaybackManager.shared

    @State private var selectedTab: Int = 0 // 0: Filmler, 1: Diziler
    @State private var selectedCategory: String = "Tümü"
    @State private var searchText: String = ""
    @State private var selectedItemForDetail: VODItem?
    @State private var selectedSeriesForDetail: Series?
    @State private var isPresentingFullscreenPlayer: Bool = false

    let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var filteredMovies: [VODItem] {
        var list = store.movies
        if selectedCategory != "Tümü" {
            list = list.filter { $0.categoryName == selectedCategory }
        }
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = searchText.lowercased()
            list = list.filter { $0.title.lowercased().contains(q) || ($0.genre?.lowercased().contains(q) ?? false) }
        }
        return list
    }

    var filteredSeries: [Series] {
        var list = store.series
        if selectedCategory != "Tümü" {
            list = list.filter { $0.categoryName == selectedCategory }
        }
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = searchText.lowercased()
            list = list.filter { $0.title.lowercased().contains(q) || ($0.genre?.lowercased().contains(q) ?? false) }
        }
        return list
    }

    private var relevantCategories: [VODCategory] {
        store.categories.filter { $0.isSeries == (selectedTab == 1) }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Custom Glass Segmented Switcher (Large 48pt Touch Target)
                        HStack(spacing: 8) {
                            Button(action: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                    selectedTab = 0
                                    selectedCategory = "Tümü"
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "film")
                                    Text("Filmler (\(store.movies.count))")
                                }
                                .font(.system(size: 15, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(selectedTab == 0 ? Color.accentColor : Color.white.opacity(0.08))
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(
                                            selectedTab == 0 ? Color.white.opacity(0.4) : Color.white.opacity(0.15),
                                            lineWidth: 1
                                        )
                                )
                                .foregroundColor(.white)
                            }

                            Button(action: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                    selectedTab = 1
                                    selectedCategory = "Tümü"
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.tv")
                                    Text("Diziler (\(store.series.count))")
                                }
                                .font(.system(size: 15, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(selectedTab == 1 ? Color.purple : Color.white.opacity(0.08))
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(
                                            selectedTab == 1 ? Color.white.opacity(0.4) : Color.white.opacity(0.15),
                                            lineWidth: 1
                                        )
                                )
                                .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                        // Continue Watching Row (if any)
                        if !store.continueWatching.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("İzlemeye Devam Et")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 14) {
                                        ForEach(store.continueWatching) { item in
                                            VODCardView(item: item) {
                                                selectedSeriesForDetail = nil
                                                selectedItemForDetail = item
                                            }
                                            .frame(width: 145)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }

                        // Category Filter Pills (Large 44pt Touch Targets)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                Button(action: {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                        selectedCategory = "Tümü"
                                    }
                                }) {
                                    Text("Tümü")
                                        .font(.system(size: 14, weight: .bold))
                                        .padding(.horizontal, 16)
                                        .frame(height: 44)
                                        .background(selectedCategory == "Tümü" ? Color.accentColor : Color.white.opacity(0.08))
                                        .background(.ultraThinMaterial)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().stroke(
                                                selectedCategory == "Tümü" ? Color.white.opacity(0.6) : Color.white.opacity(0.18),
                                                lineWidth: 1
                                            )
                                        )
                                        .foregroundColor(.white)
                                }

                                ForEach(relevantCategories) { cat in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                            selectedCategory = cat.categoryName
                                        }
                                    }) {
                                        Text(cat.categoryName)
                                            .font(.system(size: 14, weight: .bold))
                                            .padding(.horizontal, 16)
                                            .frame(height: 44)
                                            .background(selectedCategory == cat.categoryName ? Color.accentColor : Color.white.opacity(0.08))
                                            .background(.ultraThinMaterial)
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule().stroke(
                                                    selectedCategory == cat.categoryName ? Color.white.opacity(0.6) : Color.white.opacity(0.18),
                                                    lineWidth: 1
                                                )
                                            )
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Content Grid
                        if selectedTab == 0 {
                            // Movies Grid
                            if filteredMovies.isEmpty {
                                emptyStateView(message: "Film bulunamadı")
                            } else {
                                LazyVGrid(columns: columns, spacing: 18) {
                                    ForEach(filteredMovies) { movie in
                                        VODCardView(item: movie) {
                                            selectedSeriesForDetail = nil
                                            selectedItemForDetail = movie
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        } else {
                            // Series Grid
                            if filteredSeries.isEmpty {
                                emptyStateView(message: "Dizi bulunamadı")
                            } else {
                                LazyVGrid(columns: columns, spacing: 18) {
                                    ForEach(filteredSeries) { series in
                                        seriesCard(for: series)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
            .navigationTitle("Filmler & Diziler")
            .searchable(text: $searchText, prompt: "Film, dizi veya tür ara...")
            .sheet(item: $selectedItemForDetail) { item in
                VODDetailView(item: item, series: selectedSeriesForDetail) { playable, startFromBeginning in
                    playback.playVOD(item: playable, startFromBeginning: startFromBeginning)
                    isPresentingFullscreenPlayer = true
                }
            }
            .fullScreenCover(isPresented: $isPresentingFullscreenPlayer) {
                FullscreenPlayerView()
            }
        }
    }

    private func seriesCard(for series: Series) -> some View {
        VODCardView(item: series.sampleVODItem) {
            selectedSeriesForDetail = series
            if let firstEp = series.seasons.first?.episodes.first {
                selectedItemForDetail = firstEp
            } else {
                selectedItemForDetail = series.sampleVODItem
            }
        }
    }

    private func emptyStateView(message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "film.stack")
                .font(.system(size: 54))
                .foregroundColor(.white.opacity(0.35))
            Text(message)
                .font(.title3.bold())
                .foregroundColor(.white)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}
