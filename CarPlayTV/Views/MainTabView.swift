import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: Int = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            ChannelListView()
                .tabItem {
                    Label("Canlı TV", systemImage: "tv.fill")
                }
                .tag(0)

            VODHomeView()
                .tabItem {
                    Label("Filmler & Diziler", systemImage: "film.stack.fill")
                }
                .tag(1)

            PlaylistManagerView()
                .tabItem {
                    Label("Listeler", systemImage: "list.bullet.rectangle.fill")
                }
                .tag(2)

            CarPlaySettingsView()
                .tabItem {
                    Label("CarPlay", systemImage: "car.fill")
                }
                .tag(3)
        }
        .accentColor(.red)
    }
}
