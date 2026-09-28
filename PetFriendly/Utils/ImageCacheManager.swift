import UIKit
import CryptoKit

/// 图片缓存管理器 (极简高性能版 + 磁盘持久化)
class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    // 内存缓存
     private let memoryCache = NSCache<NSString, UIImage>()
    
    // 磁盘缓存路径
    private let diskCacheURL: URL = {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheBase = paths[0].appendingPathComponent("ImageCache")
        if !FileManager.default.fileExists(atPath: cacheBase.path) {
            try? FileManager.default.createDirectory(at: cacheBase, withIntermediateDirectories: true)
        }
        return cacheBase
    }()
    
    private init() {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024
        
        // 启动时检查自动清理
        checkAndCleanupIfNeeded()
    }
    
    /// 检查是否需要执行 7 天自动清理
    private func checkAndCleanupIfNeeded() {
        let lastCleanupKey = "LastImageCacheCleanupDate"
        let lastDate = UserDefaults.standard.double(forKey: lastCleanupKey)
        let now = Date().timeIntervalSince1970
        
        // 如果从未清理过，或距离上次超过 7 天 (7 * 24 * 3600)
        if lastDate == 0 || (now - lastDate) > (7 * 24 * 3600) {
            print("ImageCacheManager: 执行 7 天周期自动清理...")
            clear()
            UserDefaults.standard.set(now, forKey: lastCleanupKey)
        }
    }
    
    // MARK: - Core Methods
    
    /// 获取图片 (优先内存 -> 其次磁盘)
    func get(forKey key: String) -> UIImage? {
        // 1. 内存查找
        if let image = memoryCache.object(forKey: key as NSString) {
            return image
        }
        
        // 2. 磁盘查找
        let fileURL = diskCacheURL.appendingPathComponent(hashKey(key))
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            // 回填内存
            memoryCache.setObject(image, forKey: key as NSString)
            return image
        }
        
        return nil
    }
    
    /// 存储图片
    func set(_ image: UIImage, forKey key: String) {
        // 存入内存
        memoryCache.setObject(image, forKey: key as NSString)
        
        // 异步存入磁盘
        DispatchQueue.global(qos: .background).async {
            let fileURL = self.diskCacheURL.appendingPathComponent(self.hashKey(key))
            if let data = image.jpegData(compressionQuality: 1.0) {
                try? data.write(to: fileURL)
            }
        }
    }
    
    // MARK: - Management
    
    /// 计算缓存总大小 (返回字节)
    func calculateCacheSize() -> Int64 {
        var size: Int64 = 0
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        for file in files {
            if let attrs = try? file.resourceValues(forKeys: [.fileSizeKey]), let fileSize = attrs.fileSize {
                size += Int64(fileSize)
            }
        }
        return size
    }
    
    /// 清除所有缓存 (内存 + 磁盘)
    func clear() {
        memoryCache.removeAllObjects()
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
    
    /// 清除指定 key 的缓存
    func remove(forKey key: String) {
        memoryCache.removeObject(forKey: key as NSString)
        let fileURL = diskCacheURL.appendingPathComponent(hashKey(key))
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    // MARK: - Private Helpers
    
    private func hashKey(_ key: String) -> String {
        let inputData = Data(key.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
