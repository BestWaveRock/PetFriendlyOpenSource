//
//  PetFriendlyPlace.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/8/15.
//

import Foundation
import SwiftUI
import CoreLocation
import MapKit

// MARK: - 评价模型
struct EvaluateVo: Decodable, Identifiable {
    var id: String { String(evaluateId ?? 0) }
    
    @Int64String var evaluateId: Int64?
    @Int64String var placeId: Int64?
    @Int64String var userId: Int64?
    @Int64String var petId: Int64?
    
    // rate 可能为 null，使用 Optional 变体
    @StringCodedOptionalDouble var rate: Double?
    let comments          : String?
    let pictures          : String?
    let createTime        : String?
    let userName          : String?
    let userAvatar        : String?
    let userBanner        : String?
    let petList           : [PetBrief]?
}

// MARK: - 关联简略宠物模型
struct PetBrief: Decodable, Identifiable {
    var id: String { String(petId ?? 0) }
    @Int64String var petId: Int64?
    let name: String?
    let breed: String?
}

// MARK: - String → Double 自动解码
@propertyWrapper
struct StringCodedDouble: Codable {
    var wrappedValue: Double
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            wrappedValue = 0
            return
        }
        if let str = try? container.decode(String.self),
           let double = Double(str) {
            wrappedValue = double
            return
        }
        wrappedValue = try container.decode(Double.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

// MARK: - String → Double? 自动解码（允许 null）
@propertyWrapper
struct StringCodedOptionalDouble: Codable {
    var wrappedValue: Double?

    init(wrappedValue: Double? = nil) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            wrappedValue = nil
            return
        }
        if let str = try? container.decode(String.self),
           let double = Double(str) {
            wrappedValue = double
            return
        }
        if let double = try? container.decode(Double.self) {
            wrappedValue = double
            return
        }
        wrappedValue = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

// MARK: - 数据模型
struct PetFriendlyPlace: Identifiable, Decodable {
    /// 使用 placeId 作为稳定身份标识，避免 SwiftUI 因 UUID 变化而重建视图
    var id: String { placeId.map(String.init) ?? UUID().uuidString }
    @Int64String var placeId: Int64?
    let name: String
    let status: Int?
    let type: Int?           // 场所类型 Int
    @StringCodedDouble var rate: Double        // BigDecimal -> Double
    let placeLevel: Int?     // 友好度 Int
    
    let proviceCode: String?
    let cityCode: String?
    let districtCode: String?
    
    @StringCodedDouble var longitude: Double   // ← 自动兼容 String/Double
    @StringCodedDouble var latitude: Double    // ← 自动兼容 String/Double
    
    let remark: String?
    let contactName: String?
    let contactInformation: String?
    
    let distanceM: Int?      // Distance in meters
    @Int64String var favoriteId: Int64?
    
    let evaluateVoList: [EvaluateVo]?

    let reporterName: String?
    let reporterAvatar: String?
    @Int64String var reporterUserId: Int64?
}

extension PetFriendlyPlace {
    /// 距离文本
    var distanceText: String {
        guard let m = distanceM else { return NSLocalizedString("no_data", comment: "") }
        return String(format: "%.1f km", Double(m) / 1000.0)
    }
    
    /// 评分文本
    var ratingText: String {
        String(format: "%.1f", rate)
    }
    
    /// 友好度文本: 1=很友好 2=友好 3=一般 4=不友好 5=未知
    var friendlyLevelText: String {
        switch placeLevel {
        case 1: return NSLocalizedString("place_level_vfriendly", comment: "")
        case 2: return NSLocalizedString("place_level_friendly", comment: "")
        case 3: return NSLocalizedString("place_level_average", comment: "")
        case 4: return NSLocalizedString("place_level_unfriendly", comment: "")
        case 5: return NSLocalizedString("place_level_unknown", comment: "")
        default: return NSLocalizedString("place_level_unknown", comment: "")
        }
    }
    
    /// 友好度对应颜色
    var friendlyLevelColor: Color {
        switch placeLevel {
        case 1: return Color(hex: "10B981") // 翠绿
        case 2: return Color(hex: "34D399") // 浅绿
        case 3: return Color(hex: "FBBF24") // 橙黄
        case 4: return Color(hex: "F87171") // 红色
        case 5: return Color.gray
        default: return Color.gray
        }
    }
    
    var category: String {
        guard let t = type else { return NSLocalizedString("other_type", comment: "") }
        // 0=宠物公园,1=宠物医院,2=宠物友好餐厅,3=饮水点,4=小草坪,5=公开广场,6=派出所,7=宠物摄影,8=宠物美容,9=寄养
        switch t {
        case 0: return NSLocalizedString("place_type_park", comment: "")
        case 1: return NSLocalizedString("place_type_hospital", comment: "")
        case 2: return NSLocalizedString("place_type_restaurant", comment: "")
        case 3: return NSLocalizedString("place_type_water", comment: "")
        case 4: return NSLocalizedString("place_type_lawn", comment: "")
        case 5: return NSLocalizedString("place_type_square", comment: "")
        case 6: return NSLocalizedString("place_type_police", comment: "")
        case 7: return NSLocalizedString("place_type_photo", comment: "")
        case 8: return NSLocalizedString("place_type_grooming", comment: "")
        case 9: return NSLocalizedString("place_type_boarding", comment: "")
        default: return NSLocalizedString("other_type", comment: "")
        }
    }
    
    /// 类型对应的图标
    var iconName: String {
        guard let t = type else { return "mappin.and.ellipse" }
        switch t {
        case 0: return "leaf.fill"             // 宠物公园
        case 1: return "cross.case.fill"      // 宠物医院
        case 2: return "fork.knife"           // 宠物友好餐厅
        case 3: return "drop.fill"            // 饮水点
        case 4: return "square.grid.3x3.fill" // 小草坪
        case 5: return "building.2.fill"      // 公开广场
        case 6: return "shield.fill"          // 派出所
        case 7: return "camera.fill"          // 宠物摄影
        case 8: return "scissors"             // 宠物美容
        case 9: return "house.fill"           // 寄养
        default: return "mappin"
        }
    }
    
    /// 类型对应的颜色
    var iconColor: Color {
        guard let t = type else { return .gray }
        switch t {
        case 0: return .green
        case 1: return .red
        case 2: return .orange
        case 3: return .blue
        case 4: return .green.opacity(0.8)
        case 5: return .cyan
        case 6: return .blue.opacity(0.7)
        case 7: return .purple
        case 8: return .pink
        case 9: return .brown
        default: return .gray
        }
    }
    
    /// 从评价列表中提取图片 URL（pictures 为逗号分隔字符串）
    var images: [String]? {
        let urls = (evaluateVoList ?? [])
            .compactMap { $0.pictures }
            .flatMap { $0.components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return urls.isEmpty ? nil : urls
    }
    
    /// 直接转换成地图坐标
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// 生成用于导航的 MKMapItem
    var mapItem: MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = name
        return item
    }
}

extension PetFriendlyPlace: Equatable {
    static func == (lhs: PetFriendlyPlace, rhs: PetFriendlyPlace) -> Bool {
        lhs.id == rhs.id
    }
}
