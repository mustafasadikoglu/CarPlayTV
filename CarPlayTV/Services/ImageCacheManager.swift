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

    private init() {
        // Up to 500 items or 50 MB RAM
        memoryCache.countLimit = 500
        memoryCache.totalCostLimit = 50 * 1024 * 1024
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
        // 1. Check RAM Cache (0 ms)
        if let memoryImage = cachedImageFromMemory(for: url) {
            return memoryImage
        }

        // 2. Check Disk Cache (1-2 ms)
        if let diskImage = cachedImageFromDisk(for: url) {
            return diskImage
        }

        // 3. Fetch from Network
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
            let key = cacheKey(for: url)
            memoryCache.setObject(finalImage, forKey: key as NSString, cost: data.count)

            // Save to Disk (background async)
            let fileURL = diskCacheDirectory.appendingPathComponent(key)
            DispatchQueue.global(qos: .utility).async {
                try? data.write(to: fileURL, options: [.atomic])
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

        let maxDimension = max(targetSize.width, targetSize.height) * UIScreen.main.scale
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
}
