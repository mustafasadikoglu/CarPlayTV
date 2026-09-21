import SwiftUI

public struct PlaylistManagerView: View {
    @ObservedObject var store = PlaylistStore.shared
    @State private var isShowingAddSheet: Bool = false

    public var body: some View {
        NavigationStack {
            List {
                Section("Aktif Çalma Listeleri (\(store.playlists.count))") {
                    if store.playlists.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Özel liste eklenmedi")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Varsayılan test yayınları aktif. Kendi listenizi eklemek için aşağıdaki butonu kullanın.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        ForEach(store.playlists) { pl in
                            HStack {
                                Image(systemName: pl.type == .m3u ? "list.bullet.rectangle" : "server.rack")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pl.name)
                                        .font(.headline)
                                    Text("\(pl.channelCount) Kanal • \(pl.type == .m3u ? "M3U Link" : "Xtream API")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: store.deletePlaylist)
                    }
                }

                Section("Hızlı İşlemler") {
                    Button(action: {
                        isShowingAddSheet = true
                    }) {
                        Label("Yeni Liste Ekle (M3U / Xtream)", systemImage: "plus.circle.fill")
                    }

                    Button(action: {
                        store.loadSampleChannels()
                    }) {
                        Label("Örnek Canlı Yayınları Yeniden Yükle", systemImage: "arrow.clockwise")
                    }
                }

                Section("İstatistikler") {
                    HStack {
                        Text("Toplam Kanal")
                        Spacer()
                        Text("\(store.channels.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Favori Kanallar")
                        Spacer()
                        Text("\(store.favoriteChannels.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Kategori Sayısı")
                        Spacer()
                        Text("\(store.categories.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Çalma Listeleri")
            .sheet(isPresented: $isShowingAddSheet) {
                AddPlaylistSheet()
            }
        }
    }
}
