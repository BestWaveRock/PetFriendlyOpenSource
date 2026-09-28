//
//  ProviderQualificationModels.swift
//  PetFriendly
//
//  服务商资质相关 DTO 模型
//

import Foundation

// MARK: - 资质审核状态
struct ProviderQualificationResp: Decodable {
    let code: Int
    let msg: String?
    let data: ProviderQualification?
}

struct ProviderQualification: Decodable {
    @Int64String var qualificationId: Int64?
    @Int64String var providerId: Int64?
    @Int64String var providerOwnerId: Int64?
    @Int64String var providerUserId: Int64?
    
    // 实名认证
    let realName: String?
    let idCardNumber: String?
    let idCardFrontImg: String?
    let idCardBackImg: String?
    let realNameAuthStatus: Int?
    let realNameAuthRemark: String?
    @SafeDateString var realNameAuthTime: String?
    
    // 芝麻信用
    let sesameCreditAuthorized: Int?
    let sesameCreditScore: Int?
    let sesameCreditImg: String?
    let sesameCreditAuthStatus: Int?
    let sesameCreditAuthRemark: String?
    @SafeDateString var sesameCreditAuthTime: String?
    
    // 无犯罪证明
    let criminalRecordImg: String?
    let criminalRecordAuthStatus: Int?
    let criminalRecordAuthRemark: String?
    @SafeDateString var criminalRecordAuthTime: String?
    
    // 整体状态
    let overallStatus: Int?
    
    // 用户信息
    let userName: String?
    let phone: String?
    
    @SafeDateString var createTime: String?
    @SafeDateString var updateTime: String?
}

// MARK: - 派单大厅模型
struct DispatchHallResp: Decodable {
    let code: Int
    let msg: String?
    let rows: [DispatchOrder]?
    let total: Int64?
}

struct DispatchOrder: Identifiable, Decodable {
    @Int64String var dispatchId: Int64?
    var id: String { dispatchId.map(String.init) ?? UUID().uuidString }
    
    @Int64String var consumerId: Int64?
    @Int64String var providerId: Int64?
    let dispatchStatus: Int?
    
    // 关联预约单信息
    @Int64String var petId: Int64?
    let petName: String?
    let petAvatar: String?
    let serviceType: Int?
    let serviceName: String?
    let reserveInformation: String?
    @SafeDateString var reserveStartTime: String?
    @SafeDateString var reserveEndTime: String?
    @SafeDateString var appointmentTime: String?
    @StringCodedOptionalDouble var consumptionAmount: Double?
    let ownerName: String?
    let ownerPhone: String?
    let ownerAddress: String?

    // 宠物更多信息（详情接口）
    let petSpecies: String?
    let petSex: String?
    let petBreeds: String?

    // 消费记录备注与坐标（详情接口）
    let consumerRemark: String?
    @StringCodedOptionalDouble var consumerLongitude: Double?
    @StringCodedOptionalDouble var consumerLatitude: Double?
    let ext1: String?
    let ext2: String?

    // 距离和时间
    let distance: Int64?
    let travelTime: Int?
    @StringCodedOptionalDouble var estimatedIncome: Double?
    
    // 服务证明（可能不返回）
    let serviceCertificate: String?
    // 完成时间（可能不返回）
    @SafeDateString var completeTime: String?
    // 评价相关（可能不返回）
    let commentRate: Int?
    let commentContent: String?
    
    let createTime: String?
    let updateTime: String?
    
    enum CodingKeys: String, CodingKey {
        case dispatchId, consumerId, providerId, dispatchStatus
        case petId, petName, petAvatar, serviceType, serviceName
        case reserveInformation, reserveStartTime, reserveEndTime
        case appointmentTime, consumptionAmount
        case ownerName, ownerPhone, ownerAddress
        case petSpecies, petSex, petBreeds
        case consumerRemark, consumerLongitude, consumerLatitude, ext1, ext2
        case distance, travelTime, estimatedIncome
        case serviceCertificate, completeTime, commentRate, commentContent
        case createTime, updateTime
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _dispatchId = (try? container.decodeIfPresent(Int64String.self, forKey: .dispatchId)) ?? Int64String(wrappedValue: nil)
        _consumerId = (try? container.decodeIfPresent(Int64String.self, forKey: .consumerId)) ?? Int64String(wrappedValue: nil)
        _providerId = (try? container.decodeIfPresent(Int64String.self, forKey: .providerId)) ?? Int64String(wrappedValue: nil)
        dispatchStatus = try? container.decodeIfPresent(Int.self, forKey: .dispatchStatus) ?? nil
        _petId = (try? container.decodeIfPresent(Int64String.self, forKey: .petId)) ?? Int64String(wrappedValue: nil)
        petName = try? container.decodeIfPresent(String.self, forKey: .petName) ?? nil
        petAvatar = try? container.decodeIfPresent(String.self, forKey: .petAvatar) ?? nil
        serviceType = try? container.decodeIfPresent(Int.self, forKey: .serviceType) ?? nil
        serviceName = try? container.decodeIfPresent(String.self, forKey: .serviceName) ?? nil
        reserveInformation = try? container.decodeIfPresent(String.self, forKey: .reserveInformation) ?? nil
        _reserveStartTime = (try? container.decodeIfPresent(SafeDateString.self, forKey: .reserveStartTime)) ?? SafeDateString(wrappedValue: nil)
        _reserveEndTime = (try? container.decodeIfPresent(SafeDateString.self, forKey: .reserveEndTime)) ?? SafeDateString(wrappedValue: nil)
        _appointmentTime = (try? container.decodeIfPresent(SafeDateString.self, forKey: .appointmentTime)) ?? SafeDateString(wrappedValue: nil)
        _consumptionAmount = (try? container.decodeIfPresent(StringCodedOptionalDouble.self, forKey: .consumptionAmount)) ?? StringCodedOptionalDouble(wrappedValue: nil)
        ownerName = try? container.decodeIfPresent(String.self, forKey: .ownerName) ?? nil
        ownerPhone = try? container.decodeIfPresent(String.self, forKey: .ownerPhone) ?? nil
        ownerAddress = try? container.decodeIfPresent(String.self, forKey: .ownerAddress) ?? nil
        petSpecies = try? container.decodeIfPresent(String.self, forKey: .petSpecies) ?? nil
        petSex = try? container.decodeIfPresent(String.self, forKey: .petSex) ?? nil
        petBreeds = try? container.decodeIfPresent(String.self, forKey: .petBreeds) ?? nil
        consumerRemark = try? container.decodeIfPresent(String.self, forKey: .consumerRemark) ?? nil
        _consumerLongitude = (try? container.decodeIfPresent(StringCodedOptionalDouble.self, forKey: .consumerLongitude)) ?? StringCodedOptionalDouble(wrappedValue: nil)
        _consumerLatitude = (try? container.decodeIfPresent(StringCodedOptionalDouble.self, forKey: .consumerLatitude)) ?? StringCodedOptionalDouble(wrappedValue: nil)
        ext1 = try? container.decodeIfPresent(String.self, forKey: .ext1) ?? nil
        ext2 = try? container.decodeIfPresent(String.self, forKey: .ext2) ?? nil
        distance = try? container.decodeIfPresent(Int64.self, forKey: .distance) ?? nil
        travelTime = try? container.decodeIfPresent(Int.self, forKey: .travelTime) ?? nil
        _estimatedIncome = (try? container.decodeIfPresent(StringCodedOptionalDouble.self, forKey: .estimatedIncome)) ?? StringCodedOptionalDouble(wrappedValue: nil)
        serviceCertificate = try? container.decodeIfPresent(String.self, forKey: .serviceCertificate) ?? nil
        _completeTime = (try? container.decodeIfPresent(SafeDateString.self, forKey: .completeTime)) ?? SafeDateString(wrappedValue: nil)
        commentRate = try? container.decodeIfPresent(Int.self, forKey: .commentRate) ?? nil
        commentContent = try? container.decodeIfPresent(String.self, forKey: .commentContent) ?? nil
        createTime = try? container.decodeIfPresent(String.self, forKey: .createTime) ?? nil
        updateTime = try? container.decodeIfPresent(String.self, forKey: .updateTime) ?? nil
    }
}

// MARK: - 状态枚举扩展
extension Int {
    /// 资质审核状态文本
    var qualificationStatusText: String {
        switch self {
        case 0: return NSLocalizedString("qual_status_not_submitted", comment: "未提交")
        case 1: return NSLocalizedString("qual_status_reviewing", comment: "审核中")
        case 2: return NSLocalizedString("qual_status_approved", comment: "已通过")
        case 3: return NSLocalizedString("qual_status_rejected", comment: "已驳回")
        default: return NSLocalizedString("qual_status_unknown", comment: "未知")
        }
    }
    
    /// 资质审核状态颜色名
    var qualificationStatusColor: String {
        switch self {
        case 0: return "textSecondary"
        case 1: return "warning"
        case 2: return "success"
        case 3: return "danger"
        default: return "textSecondary"
        }
    }
    
    /// 派单状态文本
    var dispatchStatusText: String {
        switch self {
        case 0: return NSLocalizedString("dispatch_waiting", comment: "待接单")
        case 1: return NSLocalizedString("dispatch_grabbed", comment: "已被抢")
        case 2: return NSLocalizedString("dispatch_provider_cancelled", comment: "服务商取消")
        case 3: return NSLocalizedString("dispatch_user_cancelled", comment: "用户取消")
        case 4: return NSLocalizedString("dispatch_system_cancelled", comment: "系统取消")
        case 5: return NSLocalizedString("dispatch_completed", comment: "已完成")
        default: return NSLocalizedString("dispatch_unknown", comment: "未知")
        }
    }
    
    /// 整体审核状态
    var overallQualificationText: String {
        switch self {
        case 0: return NSLocalizedString("qual_overall_not_submitted", comment: "未提交")
        case 1: return NSLocalizedString("qual_overall_reviewing", comment: "审核中")
        case 2: return NSLocalizedString("qual_overall_all_passed", comment: "全部通过")
        case 3: return NSLocalizedString("qual_overall_partial_rejected", comment: "部分驳回")
        default: return NSLocalizedString("qual_overall_unknown", comment: "未知")
        }
    }
}
