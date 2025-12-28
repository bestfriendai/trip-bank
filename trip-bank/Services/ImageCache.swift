import SwiftUI
import UIKit

/// High-performance image cache with memory and disk caching
/// Designed for signed Convex URLs with TTL support
actor ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCachePath: URL
    private let maxMemoryCost: Int = 100 * 1024 * 1024 // 100MB memory
    private let maxDiskSize: Int = 500 * 1024 * 1024 // 500MB disk

    private init() {
        // Set memory cache limits
        memoryCache.totalCostLimit = maxMemoryCost

        // Setup disk cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCachePath = cacheDir.appendingPathComponent("ImageCache", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: diskCachePath, withIntermediateDirectories: true)

        // Start periodic cleanup
        Task {
            await periodicCleanup()
        }
    }

    // MARK: - Cache Key

    /// Generate a cache key from a URL (strips query params for signed URLs)
    private func cacheKey(for url: URL) -> String {
        // For signed URLs, use path without query params (signature changes)
        // Keep the storage ID portion for uniqueness
        let path = url.path
        return path.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? url.absoluteString
    }

    // MARK: - Public API

    /// Get image from cache (memory first, then disk)
    func get(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)

        // Check memory cache first
        if let image = memoryCache.object(forKey: key as NSString) {
            return image
        }

        // Check disk cache
        if let image = loadFromDisk(key: key) {
            // Promote to memory cache
            let cost = estimatedCost(for: image)
            memoryCache.setObject(image, forKey: key as NSString, cost: cost)
            return image
        }

        return nil
    }

    /// Store image in cache
    func set(_ image: UIImage, for url: URL) {
        let key = cacheKey(for: url)
        let cost = estimatedCost(for: image)

        // Store in memory
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)

        // Store on disk async
        saveToDisk(image: image, key: key)
    }

    /// Fetch image from URL with caching
    func fetch(url: URL) async throws -> UIImage {
        // Check cache first
        if let cached = get(for: url) {
            return cached
        }

        // Fetch from network
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageCacheError.fetchFailed
        }

        guard let image = UIImage(data: data) else {
            throw ImageCacheError.invalidImage
        }

        // Cache the result
        set(image, for: url)

        return image
    }

    /// Clear all caches
    func clearAll() {
        memoryCache.removeAllObjects()

        // Clear disk cache
        try? FileManager.default.removeItem(at: diskCachePath)
        try? FileManager.default.createDirectory(at: diskCachePath, withIntermediateDirectories: true)
    }

    /// Clear memory cache only (keep disk)
    func clearMemory() {
        memoryCache.removeAllObjects()
    }

    // MARK: - Disk Operations

    private func diskPath(for key: String) -> URL {
        diskCachePath.appendingPathComponent(key)
    }

    private func loadFromDisk(key: String) -> UIImage? {
        let path = diskPath(for: key)
        guard FileManager.default.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: path),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    private func saveToDisk(image: UIImage, key: String) {
        let path = diskPath(for: key)

        // ✅ FIXED: Preserve PNG transparency - check if image has alpha channel
        let hasAlpha = image.cgImage?.alphaInfo != .none &&
                       image.cgImage?.alphaInfo != .noneSkipFirst &&
                       image.cgImage?.alphaInfo != .noneSkipLast

        let data: Data?
        if hasAlpha {
            // Use PNG to preserve transparency
            data = image.pngData()
        } else {
            // Use JPEG for better compression on non-transparent images
            data = image.jpegData(compressionQuality: 0.9)
        }

        guard let imageData = data else { return }
        try? imageData.write(to: path, options: .atomic)
    }

    // MARK: - Memory Management

    private func estimatedCost(for image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }

    private func periodicCleanup() async {
        // Run cleanup every 5 minutes
        while true {
            try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
            await trimDiskCache()
        }
    }

    private func trimDiskCache() async {
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(
            at: diskCachePath,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        // Get file info sorted by creation date (oldest first)
        var fileInfos: [(url: URL, size: Int, date: Date)] = []
        for file in files {
            guard let attrs = try? file.resourceValues(forKeys: [.fileSizeKey, .creationDateKey]),
                  let size = attrs.fileSize,
                  let date = attrs.creationDate else { continue }
            fileInfos.append((file, size, date))
        }

        // Sort by date (oldest first)
        fileInfos.sort { $0.date < $1.date }

        // Calculate total size
        var totalSize = fileInfos.reduce(0) { $0 + $1.size }

        // Delete oldest files until under limit
        for info in fileInfos {
            if totalSize <= maxDiskSize { break }
            try? fileManager.removeItem(at: info.url)
            totalSize -= info.size
        }
    }

    // MARK: - Error Types

    enum ImageCacheError: Error {
        case fetchFailed
        case invalidImage
    }
}

// MARK: - SwiftUI AsyncImage with Caching

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image = loadedImage {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url = url else { return }

        isLoading = true

        do {
            let image = try await ImageCache.shared.fetch(url: url)
            await MainActor.run {
                self.loadedImage = image
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
