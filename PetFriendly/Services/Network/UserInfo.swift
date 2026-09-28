//
//  UserInfo.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/9/23.
//


import Foundation
import Alamofire


// MARK: - 业务接口
final class UserInfoService {
    static let shared = UserInfoService()
    private init() {}
    
    @Published var user: UserInfoResp?
    
    /// 是否已登录
    func isLogin() async -> Bool {
        do {
            let resp: BoolResp = try await NetworkManager.shared.request("/auth/isLogin",
                                                                         method: .get,
                                                                         needToken: true)
            return resp.data ?? false
        } catch {
            return false
        }
    }
}
