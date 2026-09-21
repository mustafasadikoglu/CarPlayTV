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
            ZStack {
                LiquidGlassBackground()

                VStack(spacing: 0) {
                    // Progressive Parsing Banner
                    if let progress = store.parseProgressText {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text(progress)
                                .font(.caption.bold())
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.3))
                        .liquidGlass(cornerRadius: 0)
                    }

                    // Category Pills (Large 44pt Touch Targets)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            // Favorites quick toggle pill
                            Button(action: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                    onlyFavorites.toggle()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 14))
                                    Text("Favoriler (\(store.favoriteChannels.count))")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                                .background(
                                    ZStack {
                                        if onlyFavorites {
                                            Color.yellow
                                        } else {
                                            Color.white.opacity(0.08)
                                        }
                                    }
                                )
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(
                                        onlyFavorites ? Color.white.opacity(0.6) : Color.white.opacity(0.18),
                                        lineWidth: 1
                                    )
                                )
                                .foregroundColor(onlyFavorites ? .black : .white)
                            }

                            if !onlyFavorites {
                                ForEach(store.categories) { cat in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                            selectedCategory = cat.name
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: cat.iconName)
                                                .font(.system(size: 14))
                                            Text(cat.name)
                                                .font(.system(size: 14, weight: .bold))
                                            Text("(\(cat.channelCount))")
                                                .font(.caption2.bold())
                                                .foregroundColor(selectedCategory == cat.name ? .white.opacity(0.9) : .white.opacity(0.5))
                                        }
                                        .padding(.horizontal, 16)
                                        .frame(height: 44)
                                        .background(
                                            ZStack {
                                                if selectedCategory == cat.name {
                                                    Color.accentColor
                                                } else {
                                                    Color.white.opacity(0.08)
                                                }
                                            }
                                        )
                                        .background(.ultraThinMaterial)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().stroke(
                                                selectedCategory == cat.name ? Color.white.opacity(0.6) : Color.white.opacity(0.18),
                                                lineWidth: 1
                                            )
                                        )
                                        .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }

                    // Channel List
                    if displayedChannels.isEmpty {
                        VStack(spacing: 14) {
                            Spacer()
                            Image(systemName: "tv.slash")
                                .font(.system(size: 54))
                                .foregroundColor(.white.opacity(0.4))
                            Text(onlyFavorites ? "Henüz favori kanalınız yok" : "Kanal bulunamadı")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            Text("Listeler sekmesinden M3U veya Xtream linki ekleyebilirsiniz.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
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
                                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .scrollContentBackground(.hidden)
                    }

                    // Mini Player Floating Bar (if playing)
                    if let current = playback.currentChannel {
                        MiniPlayerBar(channel: current) {
                            isPresentingFullscreenPlayer = true
                        }
                    }
                }
            }
            .navigationTitle("Canlı TV")
            .searchable(text: $searchText, prompt: "Kanal veya kategori ara...")
            .onChange(of: searchText, perform: { newQuery in
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 250_000_000)
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
        HStack(spacing: 14) {
            ZStack {
                CachedAsyncImage(url: channel.logoURL, targetSize: CGSize(width: 80, height: 80)) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 32)
                        .cornerRadius(6)
                } placeholder: {
                    Image(systemName: "tv.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .frame(width: 54, height: 40)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                    Text("Canlı")
                        .font(.caption2.bold())
                        .foregroundColor(.red)

                    if playback.isCarPlayConnected {
                        Text("• CarPlay")
                            .font(.caption2.bold())
                            .foregroundColor(.cyan)
                    }
                }
            }

            Spacer()

            // Large 48x48pt Play / Pause button
            Button(action: {
                playback.togglePlayPause()
            }) {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.4), lineWidth: 1.2)
                    )
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 8, x: 0, y: 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .liquidGlass(cornerRadius: 18)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .onTapGesture {
            onTap()
        }
    }
}
