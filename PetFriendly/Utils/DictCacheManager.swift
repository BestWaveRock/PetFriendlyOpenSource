//
//  DictCacheModel 2.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2026/3/22.
//


//
//  DictCacheManager.swift
//  PetFriendly
//
//  Created for Dictionary Caching
//

import Foundation
import SwiftUI

struct DictCacheModel: Codable {
    let timestamp: Date
    let data: Data
}

final class DictCacheManager {
    static let shared = DictCacheManager()
    
    private let userDefaults = UserDefaults.standard
    private let cachePrefix = "dict_cache_"
    private let expirationInterval: TimeInterval = 3600 // 1 小时
    
    private init() {
        // App 启动时可选择性清理一次已过期数据
        clearExpiredCache()
    }
    
    /// 获取缓存数据
    /// - Parameter url: 请求的路径
    /// - Returns: 若存在且未过期返回 Data，否则返回 nil
    func getCache(for url: String) -> Data? {
        let key = cachePrefix + url
        
        guard let savedData = userDefaults.data(forKey: key) else {
            return nil
        }
        
        do {
            let model = try JSONDecoder().decode(DictCacheModel.self, from: savedData)
            // 验证是否过期
            if Date().timeIntervalSince(model.timestamp) < expirationInterval {
                return model.data
            } else {
                // 已过期，删除
                userDefaults.removeObject(forKey: key)
                return nil
            }
        } catch {
            // 解析失败即认为缓存无效
            userDefaults.removeObject(forKey: key)
            return nil
        }
    }
    
    /// 设置缓存数据
    /// - Parameters:
    ///   - data: 原始 JSON Data
    ///   - url: 请求的路径
    func setCache(data: Data, for url: String) {
        let key = cachePrefix + url
        let model = DictCacheModel(timestamp: Date(), data: data)
        
        do {
            let encodedData = try JSONEncoder().encode(model)
            userDefaults.set(encodedData, forKey: key)
        } catch {
            print("DictCacheManager 序列化失败: \(error)")
        }
    }
    
    /// 清理所有过期的字典缓存
    func clearExpiredCache() {
        let dictionary = userDefaults.dictionaryRepresentation()
        for key in dictionary.keys where key.hasPrefix(cachePrefix) {
            if let savedData = userDefaults.data(forKey: key),
               let model = try? JSONDecoder().decode(DictCacheModel.self, from: savedData) {
                if Date().timeIntervalSince(model.timestamp) >= expirationInterval {
                    userDefaults.removeObject(forKey: key)
                }
            } else {
                // 解析失败或格式不对，直接清理
                userDefaults.removeObject(forKey: key)
            }
        }
    }

    /// 清理所有字典缓存（不论是否过期）
    func clearAllCache() {
        let dictionary = userDefaults.dictionaryRepresentation()
        for key in dictionary.keys where key.hasPrefix(cachePrefix) {
            userDefaults.removeObject(forKey: key)
        }
    }

    /// 从字典缓存中按 dictType+value 查询 label；无缓存/查不到时返回 fallback
    /// - Parameters:
    ///   - dictType: 字典类型，如 pet_wallet_biz_type
    ///   - value: 字典值（字符串）
    ///   - fallback: 兜底文案（字典未加载或查不到时使用）
    func label(forDictType dictType: String, value: String, fallback: String) -> String {
        guard let wrapper = dictData(forDictType: dictType) else { return fallback }
        if let item = wrapper.data.first(where: { String($0.dictValue) == value }) {
            return item.dictLabel
        }
        return fallback
    }

    /// 统一获取字典 label：先查缓存，缓存未命中则请求接口并写回缓存，再返回 label
    /// - Parameters:
    ///   - dictType: 字典类型，如 pet_wallet_biz_type
    ///   - value: 字典值（字符串）
    ///   - fallback: 兜底文案（接口失败或查不到时使用）
    func fetchLabel(forDictType dictType: String, value: String, fallback: String) async -> String {
        // 1. 先查缓存
        if let wrapper = dictData(forDictType: dictType),
           let item = wrapper.data.first(where: { String($0.dictValue) == value }) {
            return item.dictLabel
        }
        // 2. 缓存未命中：请求接口
        let path = "/petFriendly/client/dictType/\(dictType)"
        do {
            let resp: DictDataResp = try await NetworkManager.shared.request(path, method: .get, needToken: false, showLoading: false)
            // 写缓存
            if let data = try? JSONEncoder().encode(resp) {
                setCache(data: data, for: path)
            }
            if let item = resp.data.first(where: { String($0.dictValue) == value }) {
                return item.dictLabel
            }
        } catch {
            // 接口失败走 fallback
        }
        return fallback
    }

    /// 从缓存解析字典数据（含缓存命中判断），供同步查询使用
    private func dictData(forDictType dictType: String) -> DictDataResp? {
        let path = "/petFriendly/client/dictType/\(dictType)"
        guard let data = getCache(for: path) else { return nil }
        // 字典接口返回 RespWrapper<[DictData]>，尝试解析 data 数组
        guard let wrapper = try? JSONDecoder().decode(DictDataResp.self, from: data) else { return nil }
        return wrapper
    }
}

/// 统一字典 label 提供者：先返回缓存 label（无缓存则 fallback），同时异步拉取接口并驱动 UI 刷新。
/// View 通过 @ObservedObject 观察，字典加载完成后自动更新为字典 label。
final class DictLabelStore: ObservableObject {
    static let shared = DictLabelStore()

    /// 记录已成功加载（写入缓存）的字典类型，避免重复请求与重复刷新
    @Published private var loadedDictTypes: Set<String> = []

    private init() {}

    /// 统一获取字典 label（非隔离同步方法，可在任意同步上下文调用）
    /// - 返回：缓存中该 value 的 label；无缓存/查不到时返回 fallback
    /// - 副作用：若缓存未命中，异步请求接口并写缓存，成功后通知 UI 刷新
    nonisolated func text(forDictType dictType: String, value: String, fallback: String) -> String {
        let cached = DictCacheManager.shared.label(forDictType: dictType, value: value, fallback: fallback)
        // 缓存未命中且尚未拉取过 → 异步拉取
        if cached == fallback || !self.loadedDictTypes.contains(dictType) {
            Task { [weak self] in
                let label = await DictCacheManager.shared.fetchLabel(forDictType: dictType, value: value, fallback: fallback)
                if label != fallback {
                    await MainActor.run {
                        self?.loadedDictTypes.insert(dictType)
                    }
                }
            }
        }
        return cached
    }
}
