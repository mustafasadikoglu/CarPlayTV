import Foundation
import CarPlay
import Combine
import UIKit

public final class CarPlayInterfaceManager {
    public static let shared = CarPlayInterfaceManager()

    private var interfaceController: CPInterfaceController?
    private var cancellables = Set<AnyCancellable>()

    private var gridTemplate: CPGridTemplate?
    private var favoritesTemplate: CPListTemplate?
    private var categoriesTemplate: CPListTemplate?
    private var moviesTemplate: CPListTemplate?
    private var recentsTemplate: CPListTemplate?
    private var rootTabBar: CPTabBarTemplate?

    private init() {
        observeDataStore()
    }

    public func setInterfaceController(_ controller: CPInterfaceController) {
        self.interfaceController = controller
        buildRootTemplate()
    }

    public func clearInterfaceController() {
        self.interfaceController = nil
        self.rootTabBar = nil
    }

    private func observeDataStore() {
        PlaylistStore.shared.$favoriteChannels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshFavoritesTemplate()
                self?.refreshGridTemplate()
            }
            .store(in: &cancellables)

        PlaylistStore.shared.$channels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshGridTemplate()
            }
            .store(in: &cancellables)

        PlaylistStore.shared.$recentChannels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshRecentsTemplate()
            }
            .store(in: &cancellables)

        PlaylistStore.shared.$categories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshCategoriesTemplate()
            }
            .store(in: &cancellables)

        VODStore.shared.$continueWatching
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMoviesTemplate()
            }
            .store(in: &cancellables)

        VODStore.shared.$movies
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMoviesTemplate()
            }
            .store(in: &cancellables)
    }

    public func buildRootTemplate() {
        guard let controller = interfaceController else { return }

        // 1. Grid Tab (Hızlı Erişim - 1. Sekme)
        let grid = makeGridTemplate()
        self.gridTemplate = grid

        // 2. Categories Tab
        let categories = makeCategoriesTemplate()
        self.categoriesTemplate = categories

        // 3. Movies / VOD Tab
        let movies = makeMoviesTemplate()
        self.moviesTemplate = movies

        // 4. Favorites Tab
        let favorites = makeFavoritesTemplate()
        self.favoritesTemplate = favorites

        // 5. Recents Tab
        let recents = makeRecentsTemplate()
        self.recentsTemplate = recents

        // 6. Tab Bar Template
        let tabBar = CPTabBarTemplate(templates: [grid, categories, movies, favorites, recents])
        self.rootTabBar = tabBar
        controller.setRootTemplate(tabBar, animated: true, completion: nil)
    }

    // MARK: - Templates Creation
    private func makeGridTemplate() -> CPGridTemplate {
        let favorites = PlaylistStore.shared.favoriteChannels
        let allChannels = PlaylistStore.shared.channels
        let channelsToUse: [Channel]

        if !favorites.isEmpty {
            channelsToUse = Array(favorites.prefix(8))
        } else if !allChannels.isEmpty {
            channelsToUse = Array(allChannels.prefix(8))
        } else {
            channelsToUse = []
        }

        let buttons: [CPGridButton] = channelsToUse.map { channel in
            let iconImage = UIImage(systemName: "tv.fill") ?? UIImage()
            let shortTitle = String(channel.name.prefix(8))
            let button = CPGridButton(
                titleVariants: [channel.name, shortTitle],
                image: iconImage
            ) { [weak self] _ in
                self?.playChannel(channel)
            }
            return button
        }

        let template = CPGridTemplate(title: "Hızlı Erişim", gridButtons: buttons)
        template.tabTitle = "Hızlı Erişim"
        template.tabImage = UIImage(systemName: "sparkles.tv")
        return template
    }

    private func makeFavoritesTemplate() -> CPListTemplate {
        let items = PlaylistStore.shared.favoriteChannels.map { channel in
            makeListItem(for: channel)
        }
        let section = CPListSection(items: items)
        let template = CPListTemplate(title: "Favoriler", sections: [section])
        template.tabTitle = "Favoriler"
        template.tabImage = UIImage(systemName: "star.fill")
        template.emptyViewTitleVariants = ["Favori Kanal Bulunamadı"]
        template.emptyViewSubtitleVariants = ["Telefondan yıldız simgesine basarak favori kanal ekleyin."]
        return template
    }

    private func makeCategoriesTemplate() -> CPListTemplate {
        var sections: [CPListSection] = []

        // Xtream Account Profile Switcher Section
        if !XtreamAccountStore.shared.accounts.isEmpty {
            let activeName = XtreamAccountStore.shared.activeAccount?.name ?? "Seçilmedi"
            let accountItem = CPListItem(
                text: "Aktif Xtream Hesabı",
                detailText: "\(activeName) (Değiştirmek için dokunun)"
            )
            accountItem.setImage(UIImage(systemName: "server.rack"))
            accountItem.handler = { [weak self] _, completion in
                self?.showAccountsTemplate()
                completion()
            }
            sections.append(CPListSection(items: [accountItem], header: "Hesap & Profil", sectionIndexTitle: "H"))
        }

        let items = PlaylistStore.shared.categories.map { cat -> CPListItem in
            let item = CPListItem(text: cat.name, detailText: "\(cat.channelCount) Kanal")
            item.setImage(UIImage(systemName: cat.iconName))
            item.handler = { [weak self] _, completion in
                self?.showCategoryChannels(category: cat.name)
                completion()
            }
            return item
        }
        sections.append(CPListSection(items: items, header: "Kategoriler", sectionIndexTitle: "K"))

        let template = CPListTemplate(title: "Kategoriler", sections: sections)
        template.tabTitle = "Kategoriler"
        template.tabImage = UIImage(systemName: "square.grid.2x2.fill")
        return template
    }

    private func showAccountsTemplate() {
        guard let controller = interfaceController else { return }
        let accounts = XtreamAccountStore.shared.accounts

        let items = accounts.map { acc -> CPListItem in
            let isCurrent = acc.id == XtreamAccountStore.shared.activeAccount?.id
            let item = CPListItem(
                text: acc.name,
                detailText: "\(acc.channelCount) Kanal • \(acc.hostDisplayName)"
            )
            if isCurrent {
                item.setImage(UIImage(systemName: "checkmark.circle.fill"))
            } else {
                item.setImage(UIImage(systemName: "circle"))
            }
            item.handler = { [weak self] _, completion in
                XtreamAccountStore.shared.setActiveAccount(account: acc)
                controller.popTemplate(animated: true, completion: nil)
                completion()
            }
            return item
        }

        let section = CPListSection(items: items)
        let template = CPListTemplate(title: "Xtream Hesapları", sections: [section])
        controller.pushTemplate(template, animated: true, completion: nil)
    }

    private func makeRecentsTemplate() -> CPListTemplate {
        let items = PlaylistStore.shared.recentChannels.map { channel in
            makeListItem(for: channel)
        }
        let section = CPListSection(items: items)
        let template = CPListTemplate(title: "Son İzlenenler", sections: [section])
        template.tabTitle = "Son İzlenenler"
        template.tabImage = UIImage(systemName: "clock.fill")
        template.emptyViewTitleVariants = ["Geçmiş Boş"]
        template.emptyViewSubtitleVariants = ["İzlediğiniz kanallar burada listelenir."]
        return template
    }

    private func makeMoviesTemplate() -> CPListTemplate {
        var sections: [CPListSection] = []

        // 1. Continue Watching Section (if available)
        if !VODStore.shared.continueWatching.isEmpty {
            let continueItems = VODStore.shared.continueWatching.prefix(5).map { vod in
                makeMovieListItem(for: vod, isResume: true)
            }
            sections.append(CPListSection(items: Array(continueItems), header: "İzlemeye Devam Et", sectionIndexTitle: "D"))
        }

        // 2. Movies Section
        let movieItems = VODStore.shared.movies.map { vod in
            makeMovieListItem(for: vod, isResume: false)
        }
        sections.append(CPListSection(items: movieItems, header: "Tüm Filmler", sectionIndexTitle: "F"))

        let template = CPListTemplate(title: "Filmler", sections: sections)
        template.tabTitle = "Filmler"
        template.tabImage = UIImage(systemName: "film.fill")
        template.emptyViewTitleVariants = ["Film Bulunamadı"]
        template.emptyViewSubtitleVariants = ["Telefondan film arşivi ekleyebilirsiniz."]
        return template
    }

    private func makeMovieListItem(for item: VODItem, isResume: Bool) -> CPListItem {
        let subtitle: String
        if isResume && item.lastPosition > 0 {
            subtitle = "Kaldığın Yerden: \(item.formattedDuration)"
        } else {
            subtitle = "\(item.categoryName) • \(item.formattedDuration)"
        }

        let listItem = CPListItem(text: item.title, detailText: subtitle)

        if let posterURL = item.posterURL, let cached = ImageCacheManager.shared.cachedImageFromMemory(for: posterURL) {
            listItem.setImage(cached)
        } else {
            listItem.setImage(UIImage(systemName: "film"))
            if let posterURL = item.posterURL {
                Task {
                    if let img = await ImageCacheManager.shared.loadImage(from: posterURL, targetSize: CGSize(width: 60, height: 90)) {
                        await MainActor.run {
                            listItem.setImage(img)
                        }
                    }
                }
            }
        }

        listItem.handler = { [weak self] _, completion in
            self?.playVODItem(item)
            completion()
        }
        return listItem
    }

    private func playVODItem(_ item: VODItem) {
        PlaybackManager.shared.playVOD(item: item, startFromBeginning: false)

        if PlaybackManager.shared.carPlayVideoMode == .forceExternalWindow {
            CarPlayVideoWindowController.shared.checkAndAttachExternalVideo()
        }

        if let controller = interfaceController {
            let nowPlaying = CPNowPlayingTemplate.shared
            controller.pushTemplate(nowPlaying, animated: true, completion: nil)
        }
    }

    private func showCategoryChannels(category: String) {
        guard let controller = interfaceController else { return }
        let channels = PlaylistStore.shared.channels(for: category)
        let items = channels.map { makeListItem(for: $0) }
        let section = CPListSection(items: items)
        let template = CPListTemplate(title: category, sections: [section])
        controller.pushTemplate(template, animated: true, completion: nil)
    }

    private func makeListItem(for channel: Channel) -> CPListItem {
        let currentProg = EPGStore.shared.currentProgram(for: channel)
        let detailText: String
        if let prog = currentProg {
            detailText = "Şu an: \(prog.title) (\(prog.timeRangeString))"
        } else {
            detailText = channel.groupTitle
        }

        let item = CPListItem(text: channel.name, detailText: detailText)

        if let logoURL = channel.logoURL, let cached = ImageCacheManager.shared.cachedImageFromMemory(for: logoURL) {
            item.setImage(cached)
        } else {
            item.setImage(UIImage(systemName: "play.tv.fill"))
            if let logoURL = channel.logoURL {
                Task {
                    if let img = await ImageCacheManager.shared.loadImage(from: logoURL, targetSize: CGSize(width: 60, height: 60)) {
                        await MainActor.run {
                            item.setImage(img)
                        }
                    }
                }
            }
        }

        item.handler = { [weak self] _, completion in
            self?.playChannel(channel)
            completion()
        }
        return item
    }

    private func playChannel(_ channel: Channel) {
        PlaybackManager.shared.play(channel: channel)

        // If force external video mode is active, ensure video window is attached
        if PlaybackManager.shared.carPlayVideoMode == .forceExternalWindow {
            CarPlayVideoWindowController.shared.checkAndAttachExternalVideo()
        }

        // Push Now Playing template or CarPlay video screen
        if let controller = interfaceController {
            let nowPlaying = CPNowPlayingTemplate.shared
            controller.pushTemplate(nowPlaying, animated: true, completion: nil)
        }
    }

    // MARK: - Live Refresh
    private func refreshFavoritesTemplate() {
        let items = PlaylistStore.shared.favoriteChannels.map { makeListItem(for: $0) }
        favoritesTemplate?.updateSections([CPListSection(items: items)])
    }

    private func refreshRecentsTemplate() {
        let items = PlaylistStore.shared.recentChannels.map { makeListItem(for: $0) }
        recentsTemplate?.updateSections([CPListSection(items: items)])
    }

    private func refreshMoviesTemplate() {
        var sections: [CPListSection] = []
        if !VODStore.shared.continueWatching.isEmpty {
            let continueItems = VODStore.shared.continueWatching.prefix(5).map { vod in
                makeMovieListItem(for: vod, isResume: true)
            }
            sections.append(CPListSection(items: Array(continueItems), header: "İzlemeye Devam Et", sectionIndexTitle: "D"))
        }
        let movieItems = VODStore.shared.movies.map { vod in
            makeMovieListItem(for: vod, isResume: false)
        }
        sections.append(CPListSection(items: movieItems, header: "Tüm Filmler", sectionIndexTitle: "F"))
        moviesTemplate?.updateSections(sections)
    }

    private func refreshCategoriesTemplate() {
        let items = PlaylistStore.shared.categories.map { cat -> CPListItem in
            let item = CPListItem(text: cat.name, detailText: "\(cat.channelCount) Kanal")
            item.setImage(UIImage(systemName: cat.iconName))
            item.handler = { [weak self] _, completion in
                self?.showCategoryChannels(category: cat.name)
                completion()
            }
            return item
        }
        categoriesTemplate?.updateSections([CPListSection(items: items)])
    }

    private func refreshGridTemplate() {
        let newGrid = makeGridTemplate()
        self.gridTemplate = newGrid

        var templates: [CPTemplate] = []
        if let g = gridTemplate { templates.append(g) }
        if let c = categoriesTemplate { templates.append(c) }
        if let m = moviesTemplate { templates.append(m) }
        if let f = favoritesTemplate { templates.append(f) }
        if let r = recentsTemplate { templates.append(r) }

        rootTabBar?.updateTemplates(templates)
    }
}


