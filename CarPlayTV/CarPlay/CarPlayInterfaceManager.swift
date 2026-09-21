import Foundation
import CarPlay
import Combine
import UIKit

public final class CarPlayInterfaceManager {
    public static let shared = CarPlayInterfaceManager()

    private var interfaceController: CPInterfaceController?
    private var cancellables = Set<AnyCancellable>()

    private var favoritesTemplate: CPListTemplate?
    private var categoriesTemplate: CPListTemplate?
    private var recentsTemplate: CPListTemplate?

    private init() {
        observeDataStore()
    }

    public func setInterfaceController(_ controller: CPInterfaceController) {
        self.interfaceController = controller
        buildRootTemplate()
    }

    public func clearInterfaceController() {
        self.interfaceController = nil
    }

    private func observeDataStore() {
        PlaylistStore.shared.$favoriteChannels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshFavoritesTemplate()
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
    }

    public func buildRootTemplate() {
        guard let controller = interfaceController else { return }

        // 1. Favorites Tab
        let favorites = makeFavoritesTemplate()
        self.favoritesTemplate = favorites

        // 2. Categories Tab
        let categories = makeCategoriesTemplate()
        self.categoriesTemplate = categories

        // 3. Recents Tab
        let recents = makeRecentsTemplate()
        self.recentsTemplate = recents

        // 4. Tab Bar Template
        let tabBar = CPTabBarTemplate(templates: [favorites, categories, recents])
        controller.setRootTemplate(tabBar, animated: true, completion: nil)
    }

    // MARK: - Templates Creation
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
        let items = PlaylistStore.shared.categories.map { cat -> CPListItem in
            let item = CPListItem(text: cat.name, detailText: "\(cat.channelCount) Kanal")
            item.setImage(UIImage(systemName: cat.iconName))
            item.handler = { [weak self] _, completion in
                self?.showCategoryChannels(category: cat.name)
                completion()
            }
            return item
        }
        let section = CPListSection(items: items)
        let template = CPListTemplate(title: "Kategoriler", sections: [section])
        template.tabTitle = "Kategoriler"
        template.tabImage = UIImage(systemName: "square.grid.2x2.fill")
        return template
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

    private func showCategoryChannels(category: String) {
        guard let controller = interfaceController else { return }
        let channels = PlaylistStore.shared.channels(for: category)
        let items = channels.map { makeListItem(for: $0) }
        let section = CPListSection(items: items)
        let template = CPListTemplate(title: category, sections: [section])
        controller.pushTemplate(template, animated: true, completion: nil)
    }

    private func makeListItem(for channel: Channel) -> CPListItem {
        let item = CPListItem(text: channel.name, detailText: channel.groupTitle)
        item.setImage(UIImage(systemName: "play.tv.fill"))
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
}
