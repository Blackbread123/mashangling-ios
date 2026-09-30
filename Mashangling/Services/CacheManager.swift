import Foundation
import UIKit

// MARK: - 离线缓存管理
actor CacheManager {
    static let shared = CacheManager()

    private let cacheDir: URL
    private let fileManager = FileManager.default

    init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDir = caches.appendingPathComponent("MashanglingCache", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: - 橱窗列表缓存（按 tagId+sort 分 key）
    func cacheFeed(items: [Showcase], key: String) {
        let url = cacheDir.appendingPathComponent("feed_\(key).json")
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: url)
        }
    }

    func loadFeed(key: String) -> [Showcase]? {
        let url = cacheDir.appendingPathComponent("feed_\(key).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Showcase].self, from: data)
    }

    // MARK: - 橱窗详情缓存
    func cacheShowcase(_ showcase: Showcase) {
        let url = cacheDir.appendingPathComponent("showcase_\(showcase.id).json")
        if let data = try? JSONEncoder().encode(showcase) {
            try? data.write(to: url)
        }
    }

    func loadShowcase(id: Int) -> Showcase? {
        let url = cacheDir.appendingPathComponent("showcase_\(id).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Showcase.self, from: data)
    }

    // MARK: - 图片缓存
    func cacheImage(_ image: UIImage, key: String) {
        let url = cacheDir.appendingPathComponent("img_\(key.hash)")
        if let data = image.pngData() {
            try? data.write(to: url)
        }
    }

    func loadImage(key: String) -> UIImage? {
        let url = cacheDir.appendingPathComponent("img_\(key.hash)")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - 清理过期缓存（超过 7 天）
    func cleanExpiredCache() {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        for file in files {
            if let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               date < cutoff {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}

// MARK: - 图片加载器（带缓存）
struct ImageLoader {
    static func load(url: String) async throws -> UIImage? {
        // 先查内存缓存
        if let cached = await CacheManager.shared.loadImage(key: url) {
            return cached
        }
        guard let url = URL(string: url) else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let img = UIImage(data: data) else { return nil }
        await CacheManager.shared.cacheImage(img, key: url.absoluteString)
        return img
    }
}
