//
//  NearbyPlaceRow.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/9/24.
//


import Foundation

// MARK: - 后端返回的单条场所
struct NearbyPlaceRow: Decodable {
    let placeId: String
    let name: String
    let type: Int          // 0=宠物公园 1=宠物医院 2=宠物友好餐厅 3=饮水点 4=小草坪
    let rate: String
    let placeLevel: Int    // 友好度 1=很友好 2=友好 3=一般 4=不友好 5=未知
    let longitude: String
    let latitude: String
    let distanceM: Double?     // 距离(米)
    let favoriteId: String?
    let remark: String?
    let evaluateVoList: [EvaluateVo]?
    let images: [String]?
    
    // 对外暴露成 Double，永远有值
    var rateValue: Double {
        Double(rate) ?? 0
    }
    
    var lng: Double {
        Double(longitude) ?? 0
    }
    
    var lat: Double {
        Double(latitude) ?? 0
    }
}
