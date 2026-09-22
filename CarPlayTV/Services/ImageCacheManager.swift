import UIKit
import CryptoKit

public final class ImageCacheManager {
    public static let shared = ImageCacheManager()

    // Tier 1: In-Memory Cache (RAM)
    private let memoryCache = NSCache<NSString, UIImage>()

    // Tier 2: Persistent Disk Cache (Disk)
    private let fileManager = FileManager.default
    private var diskCacheDirectory: URL {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("ImageCache", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // Disk cache limits
    private let maxDiskCacheBytes: Int64 = 200 * 1024 * 1024   // 200 MB
    private let maxFileAge: TimeInterval = 30 * 24 * 60 * 60   // 30 gün

    // Eşzamanlı aynı URL indirmelerini tekilleştirme
    private let inFlightLock = NSLock()
    private var inFlightTasks: [String: Task<UIImage?, Never>] = [:]

    // Temizlik işlemi (serial queue + kısıtlama)
    private let cacheQueue = DispatchQueue(label: "carplaytv.imagecache", qos: .utility)
    private var lastCleanupTime: Date = .distantPast

    private init() {
        // Up to 500 items or 50 MB RAM
        memoryCache.countLimit = 500
        memoryCache.totalCostLimit = 50 * 1024 * 1024

        // Başlangıçta bayat/aşırı büyük disk önbelleğini temizle
        cacheQueue.async { [weak self] in
            self?.cleanupDiskCache()
        }
    }

    private func cacheKey(for url: URL) -> String {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    public func cachedImageFromMemory(for url: URL) -> UIImage? {
        let key = cacheKey(for: url) as NSString
        return memoryCache.object(forKey: key)
    }

    public func cachedImageFromDisk(for url: URL) -> UIImage? {
        let filename = cacheKey(for: url)
        let fileURL = diskCacheDirectory.appendingPathComponent(filename)

        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        // Promote to memory cache
        let cost = data.count
        memoryCache.setObject(image, forKey: filename as NSString, cost: cost)
        return image
    }

    public func loadImage(from url: URL, targetSize: CGSize? = nil) async -> UIImage? {
        let key = cacheKey(for: url)

        // 1. Check RAM Cache (0 ms)
        if let memoryImage = cachedImageFromMemory(for: url) {
            return memoryImage
        }

        // 2. Check Disk Cache (1-2 ms)
        if let diskImage = cachedImageFromDisk(for: url) {
            return diskImage
        }

        // 3. Tekilleştirilmiş ağ indirmesi
        inFlightLock.lock()
        if let existing = inFlightTasks[key] {
            inFlightLock.unlock()
            return await existing.value
        }

        let task = Task<UIImage?, Never> { [weak self] in
            guard let self = self else { return nil }
            return await self.fetchAndCache(url: url, key: key, targetSize: targetSize)
        }
        inFlightTasks[key] = task
        inFlightLock.unlock()

        let result = await task.value

        inFlightLock.lock()
        inFlightTasks[key] = nil
        inFlightLock.unlock()

        return result
    }

    private func fetchAndCache(url: URL, key: String, targetSize: CGSize?) async -> UIImage? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            guard let rawImage = UIImage(data: data) else { return nil }

            // Optional Downsampling to save memory
            let finalImage: UIImage
            if let size = targetSize, let downsampled = downsample(data: data, to: size) {
                finalImage = downsampled
            } else {
                finalImage = rawImage
            }

            // Save to RAM
            memoryCache.setObject(finalImage, forKey: key as NSString, cost: data.count)

            // Save to Disk (background async) + temizlik planla
            let fileURL = diskCacheDirectory.appendingPathComponent(key)
            cacheQueue.async { [weak self] in
                try? data.write(to: fileURL, options: [.atomic])
                self?.performDiskCleanupIfNeeded()
            }

            return finalImage
        } catch {
            return nil
        }
    }

    // High performance background downsampling
    private func downsample(data: Data, to targetSize: CGSize) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return nil
        }

        let screenScale: CGFloat = 3.0
        let maxDimension = max(targetSize.width, targetSize.height) * screenScale
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ] as CFDictionary

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }

        return UIImage(cgImage: downsampledImage)
    }

    public func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }

    public func clearDiskCache() {
        try? fileManager.removeItem(at: diskCacheDirectory)
    }

    // MARK: - Disk Cache Maintenance

    /// Temizliği en fazla 5 dakikada bir çalıştırır.
    private func performDiskCleanupIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastCleanupTime) > 300 else { return }
        lastCleanupTime = now
        cleanupDiskCache()
    }

    /// Bayat dosyaları, sonra gerekirse en eski dosyaları silerek disk önbelleğini sınırda tutar.
    private func cleanupDiskCache() {
        let dir = diskCacheDirectory
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        guard let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else {
            return
        }

        let now = Date()
        var total: Int64 = 0
        var entries: [(url: URL, date: Date, size: Int64)] = []

        for url in files {
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { continue }

            let size = Int64(values.fileSize ?? 0)
            let date = values.contentModificationDate ?? now

            // Süresi dolan dosyaları sil
            if now.timeIntervalSince(date) > maxFileAge {
                try? fileManager.removeItem(at: url)
                continue
            }

            total += size
            entries.append((url, date, size))
        }

        // Hâlâ limitin üzerindeyse en eskiden başlayarak sil
        if total > maxDiskCacheBytes {
            entries.sort { $0.date < $1.date }
            for entry in entries {
                if total <= maxDiskCacheBytes { break }
                try? fileManager.removeItem(at: entry.url)
                total -= entry.size
            }
        }
    }
}
