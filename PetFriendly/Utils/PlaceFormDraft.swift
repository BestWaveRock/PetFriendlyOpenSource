//
//  PlaceFormDraft.swift
//  PetFriendly
//
//  上报友好地表单草稿缓存 — 每一步自动保存到 UserDefaults，App 重启后恢复
//

import Foundation

/// 表单草稿数据模型（Codable 以支持 UserDefaults 序列化）
struct PlaceFormDraft: Codable {
    var step: Int = 0
    var name: String = ""
    var address: String = ""
    var typeIndex: Int? = nil
    var placeLevel: Int = 3
    var description: String = ""
    var personalRating: Int = 3
    var imageUrl: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
}

/// 表单草稿缓存管理器
enum PlaceFormDraftManager {
    private static let key = "com.petfriendly.placeFormDraft"
    
    /// 保存草稿到 UserDefaults
    static func save(_ draft: PlaceFormDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: key)
        print("[Draft] 草稿已保存 — step: \(draft.step)")
    }
    
    /// 从 UserDefaults 加载草稿
    static func load() -> PlaceFormDraft? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        let draft = try? JSONDecoder().decode(PlaceFormDraft.self, from: data)
        if draft != nil {
            print("[Draft] 草稿已恢复 — step: \(draft!.step)")
        }
        return draft
    }
    
    /// 提交成功后清除草稿
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        print("[Draft] 草稿已清除")
    }
}
