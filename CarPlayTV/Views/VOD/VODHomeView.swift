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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Segmented Filter: Filmler vs Diziler
                    Picker("İçerik Türü", selection: $selectedTab) {
                        Text("Filmler (\(store.movies.count))").tag(0)
                        Text("Diziler (\(store.series.count))").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Continue Watching Row (if any)
                    if !store.continueWatching.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("İzlemeye Devam Et")
                                .font(.headline)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(store.continueWatching) { item in
                                        VODCardView(item: item) {
                                            selectedItemForDetail = item
                                        }
                                        .frame(width: 140)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Category Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button(action: {
                                selectedCategory = "Tümü"
                            }) {
                                Text("Tümü")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == "Tümü" ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                                    .foregroundColor(selectedCategory == "Tümü" ? .white : .primary)
                                    .cornerRadius(16)
                            }

                            ForEach(relevantCategories) { cat in
                                Button(action: {
                                    selectedCategory = cat.categoryName
                                }) {
                                    Text(cat.categoryName)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedCategory == cat.categoryName ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                                        .foregroundColor(selectedCategory == cat.categoryName ? .white : .primary)
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Main Content Grid
                    if selectedTab == 0 {
                        // Movies Grid
                        if filteredMovies.isEmpty {
                            emptyStateView(message: "Film bulunamadı")
                        } else {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(filteredMovies) { movie in
                                    VODCardView(item: movie) {
                                        selectedItemForDetail = movie
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        // Series Grid
                        if filteredSeries.isEmpty {
                            emptyStateView(message: "Dizi bulunamadı")
                        } else {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(filteredSeries) { series in
                                    seriesCard(for: series)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical, 8)
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
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}
