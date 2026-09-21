import Foundation
import Combine

/// Manages multiple Xtream Codes IPTV accounts, profile switching, credential isolation, and synchronization.
public final class XtreamAccountStore: ObservableObject {
    public static let shared = XtreamAccountStore()

    @Published public var accounts: [XtreamAccount] = []
    @Published public var activeAccount: XtreamAccount?
    @Published public var isSyncing: Bool = false
    @Published public var syncProgressText: String?
    @Published public var errorMessage: String?

    private let fileManager = FileManager.default

    private var storageDirectory: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("CarPlayTV", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var accountsFileURL: URL {
        storageDirectory.appendingPathComponent("xtream_accounts.json")
    }

    public init() {
        loadAccountsFromDisk()
    }

    // MARK: - Account CRUD Operations

    /// Adds a new Xtream account, tests authentication, fetches initial channel/VOD counts and saves credentials to Keychain.
    @discardableResult
    public func addAccount(name: String, server: String, user: String, pass: String) async throws -> XtreamAccount {
        await MainActor.run {
            self.isSyncing = true
            self.syncProgressText = "Xtream sunucusuna bağlanılıyor..."
            self.errorMessage = nil
        }

        do {
            // 1. Authenticate with server
            let auth = try await XtreamCodesClient.shared.authenticate(server: server, username: user, password: pass)

            let expDateString: String?
            if let expTs = auth.userInfo?.expDate.flatMap({ Double($0) }), expTs > 0 {
                let date = Date(timeIntervalSince1970: expTs)
                let df = DateFormatter()
                df.dateStyle = .medium
                expDateString = df.string(from: date)
            } else {
                expDateString = "Süresiz / Belirsiz"
            }

            // 2. Fetch live and VOD counts
            await MainActor.run { self.syncProgressText = "Kanal listesi çekiliyor..." }
            let liveStreams = try await XtreamCodesClient.shared.fetchLiveStreams(server: server, username: user, password: pass)

            await MainActor.run { self.syncProgressText = "VOD film listesi çekiliyor..." }
            let vodStreams = (try? await XtreamCodesClient.shared.fetchVodStreams(server: server, username: user, password: pass)) ?? []

            // 3. Create account model
            let isFirstAccount = accounts.isEmpty
            let newAccount = XtreamAccount(
                name: name,
                server: server,
                username: user,
                isActive: isFirstAccount,
                channelCount: liveStreams.count,
                vodCount: vodStreams.count,
                seriesCount: 0,
                status: auth.userInfo?.status ?? "Active",
                expirationDate: expDateString,
                maxConnections: auth.userInfo?.maxCons,
                lastSynced: Date()
            )

            // 4. Save password securely to Keychain
            KeychainHelper.shared.saveString(key: "xtream_acc_pass_\(newAccount.id)", value: pass)

            // 5. Cache channels & VOD to disk for this account
            saveAccountChannels(accountId: newAccount.id, channels: liveStreams)
            saveAccountVOD(accountId: newAccount.id, movies: vodStreams)

            await MainActor.run {
                self.accounts.append(newAccount)
                if isFirstAccount {
                    self.activeAccount = newAccount
                    PlaylistStore.shared.setChannels(liveStreams)
                    VODStore.shared.setMovies(vodStreams)
                }
                self.saveAccountsToDisk()
                self.isSyncing = false
                self.syncProgressText = nil
                SanitizedLogger.info("Yeni Xtream hesabı eklendi: \(name) (\(liveStreams.count) kanal, \(vodStreams.count) film)")
            }

            return newAccount
        } catch {
            await MainActor.run {
                let safe = URLSanitizer.sanitize(error.localizedDescription)
                self.errorMessage = "Hesap eklenemedi: \(safe)"
                self.isSyncing = false
                self.syncProgressText = nil
            }
            throw error
        }
    }

    /// Updates account credentials and re-authenticates.
    public func updateAccount(id: String, name: String, server: String, user: String, pass: String) async throws {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }

        await MainActor.run {
            self.isSyncing = true
            self.syncProgressText = "Bilgiler güncelleniyor ve test ediliyor..."
            self.errorMessage = nil
        }

        do {
            let auth = try await XtreamCodesClient.shared.authenticate(server: server, username: user, password: pass)

            let expDateString: String?
            if let expTs = auth.userInfo?.expDate.flatMap({ Double($0) }), expTs > 0 {
                let date = Date(timeIntervalSince1970: expTs)
                let df = DateFormatter()
                df.dateStyle = .medium
                expDateString = df.string(from: date)
            } else {
                expDateString = "Süresiz"
            }

            await MainActor.run {
                self.accounts[index].name = name
                self.accounts[index].server = server
                self.accounts[index].username = user
                self.accounts[index].status = auth.userInfo?.status ?? "Active"
                self.accounts[index].expirationDate = expDateString
                self.accounts[index].maxConnections = auth.userInfo?.maxCons
                self.accounts[index].securePassword = pass

                if self.activeAccount?.id == id {
                    self.activeAccount = self.accounts[index]
                }
                self.saveAccountsToDisk()
                self.isSyncing = false
                self.syncProgressText = nil
                SanitizedLogger.info("Xtream hesabı güncellendi: \(name)")
            }

            // Sync channel list after credentials update
            try await syncAccount(account: accounts[index])
        } catch {
            await MainActor.run {
                let safe = URLSanitizer.sanitize(error.localizedDescription)
                self.errorMessage = "Hesap güncellenemedi: \(safe)"
                self.isSyncing = false
                self.syncProgressText = nil
            }
            throw error
        }
    }

    /// Synchronizes channel and VOD library from provider server.
    public func syncAccount(account: XtreamAccount) async throws {
        guard let pass = account.securePassword else {
            throw URLError(.userAuthenticationRequired)
        }

        await MainActor.run {
            self.isSyncing = true
            self.syncProgressText = "\(account.name) senkronize ediliyor..."
            self.errorMessage = nil
        }

        do {
            let auth = try await XtreamCodesClient.shared.authenticate(
                server: account.server,
                username: account.username,
                password: pass
            )

            let liveStreams = try await XtreamCodesClient.shared.fetchLiveStreams(
                server: account.server,
                username: account.username,
                password: pass
            )

            let vodStreams = (try? await XtreamCodesClient.shared.fetchVodStreams(
                server: account.server,
                username: account.username,
                password: pass
            )) ?? []

            let expDateString: String?
            if let expTs = auth.userInfo?.expDate.flatMap({ Double($0) }), expTs > 0 {
                let date = Date(timeIntervalSince1970: expTs)
                let df = DateFormatter()
                df.dateStyle = .medium
                expDateString = df.string(from: date)
            } else {
                expDateString = "Süresiz"
            }

            saveAccountChannels(accountId: account.id, channels: liveStreams)
            saveAccountVOD(accountId: account.id, movies: vodStreams)

            await MainActor.run {
                if let idx = self.accounts.firstIndex(where: { $0.id == account.id }) {
                    self.accounts[idx].channelCount = liveStreams.count
                    self.accounts[idx].vodCount = vodStreams.count
                    self.accounts[idx].expirationDate = expDateString
                    self.accounts[idx].status = auth.userInfo?.status ?? "Active"
                    self.accounts[idx].maxConnections = auth.userInfo?.maxCons
                    self.accounts[idx].lastSynced = Date()

                    if self.activeAccount?.id == account.id {
                        self.activeAccount = self.accounts[idx]
                        PlaylistStore.shared.setChannels(liveStreams)
                        VODStore.shared.setMovies(vodStreams)
                    }
                }

                self.saveAccountsToDisk()
                self.isSyncing = false
                self.syncProgressText = nil
                SanitizedLogger.info("Hesap senkronizasyonu tamamlandı: \(account.name)")
            }
        } catch {
            await MainActor.run {
                let safe = URLSanitizer.sanitize(error.localizedDescription)
                self.errorMessage = "Senkronizasyon hatası: \(safe)"
                self.isSyncing = false
                self.syncProgressText = nil
            }
            throw error
        }
    }

    /// Sets the active account and switches UI and CarPlay channels/VOD.
    public func setActiveAccount(account: XtreamAccount) {
        guard activeAccount?.id != account.id else { return }

        for i in 0..<accounts.count {
            accounts[i].isActive = (accounts[i].id == account.id)
        }
        self.activeAccount = account
        saveAccountsToDisk()

        // Load cached channels & VOD for the activated account
        let loadedChannels = loadAccountChannels(accountId: account.id)
        let loadedVOD = loadAccountVOD(accountId: account.id)

        PlaylistStore.shared.setChannels(loadedChannels)
        VODStore.shared.setMovies(loadedVOD)

        SanitizedLogger.info("Aktif hesap değiştirildi: \(account.name)")

        // If channels were empty in local cache, perform background sync
        if loadedChannels.isEmpty {
            Task {
                try? await self.syncAccount(account: account)
            }
        }
    }

    /// Deletes an Xtream account, purges Keychain credentials and account cache.
    public func deleteAccount(account: XtreamAccount) {
        // 1. Wipe Keychain credential
        KeychainHelper.shared.delete(key: "xtream_acc_pass_\(account.id)")

        // 2. Delete local cache files
        deleteAccountCache(accountId: account.id)

        let wasActive = (activeAccount?.id == account.id)
        accounts.removeAll(where: { $0.id == account.id })

        if wasActive {
            if let next = accounts.first {
                setActiveAccount(account: next)
            } else {
                activeAccount = nil
                PlaylistStore.shared.loadSampleChannels()
                VODStore.shared.loadSampleMovies()
            }
        }

        saveAccountsToDisk()
        SanitizedLogger.info("Xtream hesabı silindi ve temizlendi: \(account.name)")
    }

    // MARK: - Local Cache File Management per Account

    private func accountChannelsURL(accountId: String) -> URL {
        storageDirectory.appendingPathComponent("account_channels_\(accountId).json")
    }

    private func accountVODURL(accountId: String) -> URL {
        storageDirectory.appendingPathComponent("account_vod_\(accountId).json")
    }

    private func saveAccountChannels(accountId: String, channels: [Channel]) {
        let file = accountChannelsURL(accountId: accountId)
        DispatchQueue.global(qos: .utility).async {
            if let data = try? JSONEncoder().encode(channels) {
                try? data.write(to: file, options: [.atomic])
            }
        }
    }

    private func loadAccountChannels(accountId: String) -> [Channel] {
        let file = accountChannelsURL(accountId: accountId)
        if let data = try? Data(contentsOf: file),
           let decoded = try? JSONDecoder().decode([Channel].self, from: data) {
            return decoded
        }
        return []
    }

    private func saveAccountVOD(accountId: String, movies: [VODItem]) {
        let file = accountVODURL(accountId: accountId)
        DispatchQueue.global(qos: .utility).async {
            if let data = try? JSONEncoder().encode(movies) {
                try? data.write(to: file, options: [.atomic])
            }
        }
    }

    private func loadAccountVOD(accountId: String) -> [VODItem] {
        let file = accountVODURL(accountId: accountId)
        if let data = try? Data(contentsOf: file),
           let decoded = try? JSONDecoder().decode([VODItem].self, from: data) {
            return decoded
        }
        return []
    }

    private func deleteAccountCache(accountId: String) {
        try? fileManager.removeItem(at: accountChannelsURL(accountId: accountId))
        try? fileManager.removeItem(at: accountVODURL(accountId: accountId))
    }

    private func saveAccountsToDisk() {
        let list = self.accounts
        let file = self.accountsFileURL
        DispatchQueue.global(qos: .utility).async {
            if let data = try? JSONEncoder().encode(list) {
                try? data.write(to: file, options: [.atomic])
            }
        }
    }

    private func loadAccountsFromDisk() {
        if let data = try? Data(contentsOf: accountsFileURL),
           let decoded = try? JSONDecoder().decode([XtreamAccount].self, from: data) {
            self.accounts = decoded
            self.activeAccount = decoded.first(where: { $0.isActive }) ?? decoded.first
        }
    }
}
