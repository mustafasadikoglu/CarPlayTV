import SwiftUI

public struct ChannelListView: View {
    @ObservedObject var store = PlaylistStore.shared
    @ObservedObject var playback = PlaybackManager.shared

    @State private var searchText: String = ""
    @State private var selectedCategory: String = "Tümü"
    @State private var onlyFavorites: Bool = false
    @State private var isPresentingFullscreenPlayer: Bool = false
    @State private var searchResults: [Channel] = []
    @State private var searchTask: Task<Void, Never>?

    public var displayedChannels: [Channel] {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return searchResults
        }
        if onlyFavorites {
            return store.favoriteChannels
        }
        return store.channels(for: selectedCategory)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progressive Parsing Banner (For Large Playlists)
                if let progress = store.parseProgressText {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(progress)
                            .font(.caption.bold())
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.12))
                }

                // Category Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Favorites quick toggle pill
                        Button(action: {
                            withAnimation {
                                onlyFavorites.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                Text("Favoriler (\(store.favoriteChannels.count))")
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(onlyFavorites ? Color.yellow : Color(UIColor.secondarySystemBackground))
                            .foregroundColor(onlyFavorites ? .black : .primary)
                            .cornerRadius(20)
                        }

                        if !onlyFavorites {
                            ForEach(store.categories) { cat in
                                Button(action: {
                                    withAnimation {
                                        selectedCategory = cat.name
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: cat.iconName)
                                        Text(cat.name)
                                        Text("(\(cat.channelCount))")
                                            .foregroundColor(selectedCategory == cat.name ? .white.opacity(0.8) : .secondary)
                                    }
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == cat.name ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                                    .foregroundColor(selectedCategory == cat.name ? .white : .primary)
                                    .cornerRadius(20)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                // Channel List
                if displayedChannels.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "tv.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(onlyFavorites ? "Henüz favori kanalınız yok" : "Kanal bulunamadı")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Çalma listesi sekmesinden M3U veya Xtream linki ekleyebilirsiniz.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(displayedChannels) { channel in
                            ChannelRowView(
                                channel: channel,
                                isCurrent: playback.currentChannel?.id == channel.id,
                                onSelect: {
                                    playback.play(channel: channel)
                                    isPresentingFullscreenPlayer = true
                                },
                                onToggleFavorite: {
                                    store.toggleFavorite(channelId: channel.id)
                                }
                            )
                        }
                    }
                    .listStyle(PlainListStyle())
                }

                // Mini Player Bar (if channel selected)
                if let current = playback.currentChannel {
                    MiniPlayerBar(channel: current) {
                        isPresentingFullscreenPlayer = true
                    }
                }
            }
            .navigationTitle("Canlı TV")
            .searchable(text: $searchText, prompt: "Kanal veya kategori ara...")
            .onChange(of: searchText, perform: { newQuery in
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 250_000_000) // 250ms debounce
                    if !Task.isCancelled {
                        let results = await store.searchChannels(
                            query: newQuery,
                            category: onlyFavorites ? "Tümü" : selectedCategory,
                            limit: 100
                        )
                        await MainActor.run {
                            self.searchResults = results
                        }
                    }
                }
            })
            .fullScreenCover(isPresented: $isPresentingFullscreenPlayer) {
                FullscreenPlayerView()
            }
        }
    }
}

public struct MiniPlayerBar: View {
    let channel: Channel
    @ObservedObject var playback = PlaybackManager.shared
    let onTap: () -> Void

    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                CachedAsyncImage(url: channel.logoURL, targetSize: CGSize(width: 72, height: 72)) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 38, height: 26)
                        .cornerRadius(4)
                } placeholder: {
                    Image(systemName: "tv.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .frame(width: 48, height: 34)
            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                    Text("Canlı")
                        .font(.caption2.bold())
                        .foregroundColor(.red)

                    if playback.isCarPlayConnected {
                        Text("• CarPlay")
                            .font(.caption2.bold())
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            Button(action: {
                playback.togglePlayPause()
            }) {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .onTapGesture {
            onTap()
        }
    }
}
