import Foundation
import Combine

/// Centralized store for Electronic Program Guide (EPG) data and schedules.
public final class EPGStore: ObservableObject {
    public static let shared = EPGStore()

    /// Map of channel keys (tvgId, tvgName, or normalized channel name) to list of programs
    @Published public var epgMap: [String: [EPGProgram]] = [:]
    @Published public var lastRefreshed: Date = Date()
    @Published public var isLoading: Bool = false

    private var refreshTimer: Timer?
    private let fileManager = FileManager.default

    private var storageFileURL: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("CarPlayTV", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("epg_store.json")
    }

    public init() {
        loadFromDisk()
        startPeriodicRefreshTimer()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Periodic Timeline Advancer (Every 60s)
    private func startPeriodicRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.lastRefreshed = Date()
            }
        }
    }

    // MARK: - EPG Program Retrieval & Matching

    /// Normalizes a channel string for fuzzy matching (e.g. "TRT 1 HD" -> "trt1")
    private func normalizeKey(_ string: String) -> String {
        return string
            .lowercased()
            .replacingOccurrences(of: "hd", with: "")
            .replacingOccurrences(of: "fhd", with: "")
            .replacingOccurrences(of: "4k", with: "")
            .replacingOccurrences(of: "hevc", with: "")
            .replacingOccurrences(of: "tr:", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Finds programs associated with a given channel, falling back to dynamic procedural EPG if none is loaded.
    public func programs(for channel: Channel) -> [EPGProgram] {
        // 1. Try tvgId
        if let tvgId = channel.tvgId, !tvgId.isEmpty, let progs = epgMap[tvgId], !progs.isEmpty {
            return progs
        }

        // 2. Try tvgName
        if let tvgName = channel.tvgName, !tvgName.isEmpty, let progs = epgMap[tvgName], !progs.isEmpty {
            return progs
        }

        // 3. Try normalized channel name
        let normName = normalizeKey(channel.name)
        if let progs = epgMap[normName], !progs.isEmpty {
            return progs
        }

        // 4. Fallback: Procedural dynamic EPG for realistic 24-hour timeline
        return generateProceduralEPG(for: channel)
    }

    /// Returns the currently airing program for a channel
    public func currentProgram(for channel: Channel) -> EPGProgram? {
        let progs = programs(for: channel)
        let now = Date()
        return progs.first { now >= $0.startTime && now < $0.endTime }
    }

    /// Returns the next scheduled program for a channel
    public func nextProgram(for channel: Channel) -> EPGProgram? {
        let progs = programs(for: channel)
        let now = Date()
        return progs.first { $0.startTime >= now }
    }

    // MARK: - Loading & Ingesting EPG Data

    /// Ingests parsed XMLTV programs into the store
    public func ingestXMLTV(data: Data) {
        let parsed = EPGParser.shared.parseXMLTV(data: data)
        DispatchQueue.main.async {
            for (key, progs) in parsed {
                self.epgMap[key] = progs
                self.epgMap[self.normalizeKey(key)] = progs
            }
            self.lastRefreshed = Date()
            self.saveToDiskAsync()
        }
    }

    /// Downloads and parses an XMLTV feed from a URL
    public func loadXMLTV(from url: URL) async {
        await MainActor.run { self.isLoading = true }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            ingestXMLTV(data: data)
            await MainActor.run { self.isLoading = false }
            SanitizedLogger.info("XMLTV EPG başarıyla yüklendi: \(url.absoluteString)")
        } catch {
            await MainActor.run { self.isLoading = false }
            SanitizedLogger.error("XMLTV EPG yüklenemedi", error: error)
        }
    }

    // MARK: - Procedural Dynamic EPG Schedule Generator
    /// Generates realistic 24-hour time-synced TV schedule for Turkish/General channels
    public func generateProceduralEPG(for channel: Channel) -> [EPGProgram] {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        let isSports = channel.groupTitle.lowercased().contains("spor") || channel.name.lowercased().contains("spor")
        let isNews = channel.groupTitle.lowercased().contains("haber") || channel.name.lowercased().contains("haber")
        let isMovie = channel.groupTitle.lowercased().contains("sinema") || channel.groupTitle.lowercased().contains("film")
        let isDoc = channel.groupTitle.lowercased().contains("belgesel") || channel.groupTitle.lowercased().contains("doc")
        let isKids = channel.groupTitle.lowercased().contains("çocuk") || channel.groupTitle.lowercased().contains("kids")

        // Schedule templates (Hour offsets, Duration in minutes, Title, Desc)
        let scheduleTemplates: [(hour: Int, minute: Int, duration: Int, title: String, desc: String)]

        if isNews {
            scheduleTemplates = [
                (6, 0, 180, "Güne Başlarken", "Sabahın ilk ışıklarıyla Türkiye ve dünya gündemi."),
                (9, 0, 180, "Günün İçinden", "Siyaset ve ekonomideki son dakika gelişmeleri."),
                (12, 0, 60, "Öğle Bülteni", "Günün ortasında öne çıkan tüm sıcak haberler."),
                (13, 0, 120, "Ekonomi Raporu", "Piyasalar, borsa ve döviz kurlarındaki hareketlilik."),
                (15, 0, 120, "Gündem Özel", "Uzman konuklar ve derinlemesine siyasi analizler."),
                (17, 0, 120, "Akşama Doğru", "Günün bitiminde tüm gelişmeler ve canlı bağlantılar."),
                (19, 0, 90, "Ana Haber Bülteni", "Türkiye ve dünyanın en önemli haber başlıkları."),
                (20, 30, 150, "Tartışma Programı", "Gündemdeki konular canlı yayında masaya yatırılıyor."),
                (23, 0, 60, "Gece Bülteni", "Günün kapanışında tüm gelişmelerin özeti."),
                (24, 0, 360, "Gece Yayını & Belgesel Kuşağı", "Geceye özel analizler ve belgeseller.")
            ]
        } else if isSports {
            scheduleTemplates = [
                (7, 0, 120, "Sabah Sporu", "Dünkü maçların özetleri ve güne dair spor haberleri."),
                (9, 0, 180, "Spor Merkezi", "Futbol, basketbol ve dünyadan spor gelişmeleri."),
                (12, 0, 60, "Günün Golleri", "Avrupa ve ligin en güzel golleri ve anları."),
                (13, 0, 180, "Transfer Dosyası", "Kulüplerin transfer haberleri ve perde arkası."),
                (16, 0, 120, "Maç Önü Analiz", "Bugünkü kritik karşılaşmaların taktik analizleri."),
                (18, 0, 60, "Haber Aktif", "Takımların son antrenmanları ve muhtemel 11'leri."),
                (19, 0, 180, "Canlı Maç Yayını / Özel Karşılaşma", "Nefes kesen 90 dakika canlı yayınla ekranda!"),
                (22, 0, 120, "Maçın Ardından & Skor", "Teknik direktör açıklamaları ve hakem kararları."),
                (24, 0, 420, "Spor Gecesi & Maç Tekrarları", "Günün maçlarının geniş özetleri ve değerlendirmeler.")
            ]
        } else if isMovie {
            scheduleTemplates = [
                (8, 0, 120, "Sinema Klasiği", "Beyaz perdenin unutulmaz nostaljik filmleri."),
                (10, 0, 120, "Aile Kuşağı", "Tüm ailenin keyifle izleyeceği komedi ve macera."),
                (12, 0, 130, "Gerilim Kuşağı: Karanlık İzler", "Nefes kesen gizem ve polisiye filmi."),
                (14, 10, 140, "Bilim Kurgu: Zaman Gezginleri", "Geleceğin dünyasında fantastik bir macera."),
                (16, 30, 130, "Aksiyon Fırtınası: Hedef Dünya", "Yüksek tempolu macera ve çatışma sahneleri."),
                (18, 40, 140, "Ödüllü Sinema Kuşağı", "Uluslararası festivallerden ödülle dönen başyapıt."),
                (21, 0, 150, "Günün Filmi: Oppenheimer & Kod Adı", "Günün en yüksek bütçeli gişe rekortmeni filmi."),
                (23, 30, 150, "Gece Yarısı Korku Sineması", "Karanlık güçler ve gerilim dolu bir gece filmi."),
                (26, 0, 300, "Sabah Kuşağı Seçkisi", "Romantik ve komedi filmleri geçidi.")
            ]
        } else if isDoc {
            scheduleTemplates = [
                (7, 0, 120, "Vahşi Afrika", "Serengeti'de yaşam mücadelesi."),
                (9, 0, 120, "Büyük Okyanusun Gizemleri", "Deniz altındaki büyüleyici ekosistem."),
                (11, 0, 120, "Antik Dünyanın Harikaları", "Mısır piramitleri ve Roma mimarisinin sırları."),
                (13, 0, 120, "Mega Yapılar", "Dünyanın en zorlu mühendislik projeleri."),
                (15, 0, 120, "Evrenin Doğuşu", "Kara delikler ve galaksiler arası yolculuk."),
                (17, 0, 120, "Derin Kutuplar", "Kuzey ve Güney kutbunda hayatta kalma sanatı."),
                (19, 0, 120, "Tarihin Kırılma Noktaları", "Dünya tarihini değiştiren önemli dönüm noktaları."),
                (21, 0, 150, "Büyük Belgesel Kuşağı: İnsan ve Doğa", "Doğanın dengesi ve insanlığın geleceği."),
                (23, 30, 270, "Gece Kuşağı: Gizli Dosyalar", "Tarihin gizemli olayları ve araştırmalar.")
            ]
        } else if isKids {
            scheduleTemplates = [
                (7, 0, 90, "Neşeli Çiftlik", "Eğlenceli hayvan dostların maceraları."),
                (8, 30, 90, "Orman Muhafızları", "Doğayı koruyan sevimli kahramanlar."),
                (10, 0, 120, "Küçük Bilginler", "Eğitici bilimsel deneyler ve bulmacalar."),
                (12, 0, 90, "Renkli Dünya", "Müzik, dans ve resim etkinlikleri."),
                (13, 30, 120, "Süper Kahramanlar Okulu", "Gizli yeteneklerini keşfeden öğrencilerin öyküsü."),
                (15, 30, 90, "Uzay Kaşifleri", "Yıldızlararası neşeli macera."),
                (17, 0, 120, "Masal Treni", "Klasik çocuk masalları ve animasyonlar."),
                (19, 0, 90, "Büyük Macera: Sevimli Dostlar", "Aile boyu izlenecek çizgi film serisi."),
                (20, 30, 60, "Uyku Öncesi Masallar", "Çocuklar için huzurlu ve eğitici uyku masalları."),
                (21, 30, 570, "Çizgi Film Kuşağı Tekrarları", "Günün en sevilen bölümleri.")
            ]
        } else {
            // General / National (TRT 1, Ulusal vs.)
            scheduleTemplates = [
                (6, 30, 150, "Sabah Kuşağı & Günaydın Türkiye", "Güne keyifli ve bilgilendirici başlangıç."),
                (9, 0, 180, "Yaşamın İçinden & Sağlık", "Beslenme, sağlık ve uzman tavsiyeleri."),
                (12, 0, 60, "Günün Özeti", "Günün ilk yarısındaki tüm gelişmeler."),
                (13, 0, 150, "Gündüz Dizisi", "Duygusal ve heyecan dolu aile hikayesi."),
                (15, 30, 120, "Yemek ve Lezzet Yolculuğu", "Yöresel lezzetler ve pratik tarifler."),
                (17, 30, 90, "Akşam Kuşağı Haberleri", "Akşama özel gelişmeler ve magazin haberleri."),
                (19, 0, 60, "Ana Haber Bülteni", "Günün en önemli gelişmeleri ve özel dosyalar."),
                (20, 0, 180, "Günün Dizisi: Yeni Bölüm", "Heyecanla beklenen yeni bölüm canlı yayında!"),
                (23, 0, 90, "Gece Sineması", "Günün yorgunluğunu unutturacak keyifli bir film."),
                (24, 30, 360, "Gece Kuşağı & Dizi Tekrarları", "Sevilen dizilerin geçmiş bölümleri.")
            ]
        }

        var generated: [EPGProgram] = []

        for item in scheduleTemplates {
            guard let start = calendar.date(bySettingHour: item.hour % 24, minute: item.minute, second: 0, of: startOfDay) else {
                continue
            }
            let end = start.addingTimeInterval(TimeInterval(item.duration * 60))

            // Also offset to today / yesterday if necessary to ensure 24h continuity
            let program = EPGProgram(
                id: "epg_\(channel.id)_\(item.hour)_\(item.minute)",
                channelId: channel.id,
                title: item.title,
                description: item.desc,
                startTime: start,
                endTime: end,
                category: channel.groupTitle
            )
            generated.append(program)
        }

        return generated.sorted(by: { $0.startTime < $1.startTime })
    }

    // MARK: - Disk Persistence
    private func saveToDiskAsync() {
        let map = self.epgMap
        let file = self.storageFileURL
        DispatchQueue.global(qos: .utility).async {
            if let data = try? JSONEncoder().encode(map) {
                try? data.write(to: file, options: [.atomic])
            }
        }
    }

    private func loadFromDisk() {
        if let data = try? Data(contentsOf: storageFileURL),
           let decoded = try? JSONDecoder().decode([String: [EPGProgram]].self, from: data) {
            self.epgMap = decoded
        }
    }
}
