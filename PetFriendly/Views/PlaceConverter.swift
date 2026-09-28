//
//  PlaceConverter.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/9/24.
//

//import Foundation
//
//extension PetFriendlyPlace {
//    /// 网络 → 本地
//    init(from remote: NearbyPlaceRow) {
//        let categoryMap: [Int: String] = [
//            0: "宠物公园",
//            1: "宠物医院",
//            2: "宠物友好餐厅",
//            3: "饮水点", 
//            4: "小草坪"
//        ]
//        self.init(
//            placeId: remote.placeId,
//            name: remote.name,
//            category: categoryMap[remote.type] ?? "其他",
//            distance: Double(remote.distanceM ?? 0) / 1000,   // 米→公里
//            rating: Double(remote.rate) ?? 1.00,
//            latitude: Double(remote.latitude) ?? 0.00,
//            longitude: Double(remote.longitude) ?? 0.00,
//            friendliness: Self.friendlinessText(remote.placeLevel),
//            favoriteId: remote.favoriteId,
//            remark: remote.remark,
//            evaluateVoList: remote.evaluateVoList,
//            images: remote.images
//        )
//    }
//    
//    private static func friendlinessText(_ level: Int) -> String {
//        switch level {
//        case 1: return "优质"
//        case 2: return "友好"
//        case 3: return "一般"
//        case 4: return "不友好"
//        default: return "未知"
//        }
//    }
//}
