//
//  AuthService.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 22/9/25.
//

import Foundation
import Alamofire

/// 能同时接受 JSON 中的数字或字符串，最终统一成 Int64
@propertyWrapper
struct Int64String: Codable {
    var wrappedValue: Int64?
    
    init(wrappedValue: Int64? = nil) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // 尝试按数字解 (Int 或 Int64)
        if let intVal = try? container.decode(Int64.self) {
            wrappedValue = intVal
            return
        }
        // 尝试按字符串解
        if let strVal = try? container.decode(String.self),
           let intVal = Int64(strVal) {
            wrappedValue = intVal
            return
        }
        // 都失败就保持 nil
        wrappedValue = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

// MARK: - 模型保持不变
struct CodeResp: Codable {
    let code: Int
    let msg: String?
    let data: CodeData?
}
struct CodeData: Codable {
    let uuid: String?
    let img: String?
    let captchaEnabled: Bool?
}

//
//

struct LoginResp: Codable {
    let code: Int
    let msg: String
    let data: LoginData?
}
struct LoginData: Codable {
    let access_token: String?
    let refresh_token: String?
    let expire_in: Int?
    let client_id: String?
}

struct RegisterResp: Codable {
    let code: Int
    let msg: String
}

struct UserInfoResp: Decodable {
    let code: Int
    let msg: String
    let data: UserInfoData
}

struct UserInfoData: Decodable {
    let user: UserInfo
    let permissions: [String]?
    let roles: [String]?
    let petOwner: PetOwner?
}

struct UserInfo: Decodable {
    @Int64String var userId: Int64?
    @Int64String var deptId: Int64?
    let tenantId: String?
    let tenantName: String?
    let userName: String?
    let nickName: String?
    let email: String?
    let phonenumber: String?
    let sex: String?
    let avatar: String?
    let status: String?
    let loginIp: String?
    let deptName: String?
    let userType: String?
    
    // 字符串时间，先按 String 接，后面再转 Date 如果业务需要
    let loginDate: String?
    let updateTime: String?
    let createTime: String

    let remark: String?
    
    // 后端返回 null 的字段
    let roles: String?
    let roleIds: String?
    let postIds: String?
    let roleId: String?
    
    let loveLevel: Int64?
    let loveValue: Int64?
    let integralValue: Int64?
}


struct PetOwner: Decodable {
    @Int64String var loveValue: Int64?
    @Int64String var achievementNum: Int64?
    @Int64String var loveLevel: Int64?
    @Int64String var integralValue: Int64?
    @Int64String var petNum: Int64?
    @Int64String var favoritesNum: Int64?
    @Int64String var serviceNum: Int64?
    @Int64String var viewsNum: Int64?
    
    var ownerId: String?
    var petAvatar: String?
    var providerId: String?
    var name: String?
    var phoneInformation: String?
    var ext: String?
    var sex: Int?
    var tenantName: String?
}


// MARK: - 业务接口
final class AuthService {
    static let shared = AuthService()
    private init() {}
    
    @Published var user: UserInfoResp?
    
    /// 是否已登录
    func isLogin() async -> Bool {
        do {
            let resp: RespWrapper<Bool> = try await NetworkManager.shared.request("/auth/isLogin",
                                                                       method: .get,
                                                                       needToken: true)
            return resp.data ?? false
        } catch {
            return false
        }
    }
    
    /// 获取图形验证码 (基础接口)
    func getCaptcha(clientType: String? = nil) async throws -> CodeResp {
        var url = "/auth/code"
        if let type = clientType {
            url += "?clientType=\(type)"
        }
        let resp: CodeResp = try await NetworkManager.shared.request(url,
                                                                 method: .get,
                                                                 needToken: false)
        return resp
    }

    /// 获取验证码 (便捷方法，适配已有的登录逻辑)
    func fetchCaptcha() async throws -> (uuid: String, imgBase64: String) {
        let resp = try await getCaptcha(clientType: "app")
        guard let d = resp.data, let uuid = d.uuid else {
            throw BizError.biz(code: resp.code, msg: resp.msg ?? NSLocalizedString("auth_code_fail", comment: ""))
        }
        return (uuid, d.img ?? "")
    }
    
    /// 发送 Telegram 登录验证码
    func sendTelegramCode(username: String) async throws {
        let params: [String: Any] = ["username": username]
        let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
            "/auth/telegram/sendCode",
            method: .post,
            parameters: params,
            encoding: JSONEncoding.default,
            needToken: false)
        if resp.code != 200 {
            throw NSError(domain: resp.msg ?? NSLocalizedString("tg_code_fail", comment: ""), code: resp.code)
        }
    }
    
    /// 登录
    func login(username: String,
               password: String,
               code: String,
               uuid: String,
               grantType: String? = nil,
               telegramCode: String? = nil) async throws {
        await MainActor.run { AccountStore.shared.handleSession(.loginStarted) }
        do {
        var params: [String: Any] = [
            "clientId": Secrets.clientId
        ]
        
        // 如果指定了 grantType，直接使用
        if let gt = grantType {
            params["grantType"] = gt
            params["username"] = username
            if gt == "telegram" {
                params["telegramCode"] = telegramCode ?? code
            } else {
                params["password"] = password
            }
        } else {
            // 自动判断逻辑（向后兼容）
            let isEmail = username.contains("@")
            let isMobile = username.count == 11 && username.allSatisfy { $0.isNumber }
            
            if isMobile && !code.isEmpty {
                params["grantType"] = "sms"
                params["phonenumber"] = username
                params["smsCode"] = code
            } else if isEmail && !code.isEmpty {
                params["grantType"] = "email"
                params["email"] = username
                params["emailCode"] = code
            } else {
                params["grantType"] = "password"
                params["username"] = username
                params["password"] = password
            }
        }
        
        #if DEBUG
        print("Login request sent, grantType: \(params["grantType"] ?? "password")")
        #endif
        
        let resp: RespWrapper<LoginData> = try await NetworkManager.shared.request("/auth/login",
                                                                    method: .post,
                                                                    parameters: params,
                                                                    encoding: JSONEncoding.default,
                                                                    needToken: false,
                                                                    encryptFlag: true)
        print("resp: \(resp)")
        guard let d = resp.data else {
            throw NSError(domain: resp.msg!, code: resp.code)
        }
        // 保存 token
        NetworkManager.shared.setToken(d.access_token)

        // 同步 token 到 Apple Watch
        WatchConnector.shared.sendToken(d.access_token ?? "", nickname: nil, avatar: nil)

        // 并发拉用户信息（结构化并发）
        let userInfo = try await fetchUserInfo()
        
        // 缓存 + 主线程刷新（@MainActor 保证）
        await cache(userInfo)
        await MainActor.run { AccountStore.shared.handleSession(.loginSucceeded) }
        } catch {
            NetworkManager.shared.clearToken()
            await MainActor.run { AccountStore.shared.handleSession(.loginFailed) }
            throw error
        }
    }
    
    // 拉用户信息
    public func fetchUserInfo() async throws -> UserInfoResp {
        let info: UserInfoResp = try await NetworkManager.shared
            .request("/system/user/getInfo", method: .get, needToken: true)
        return info
    }

    // 获取宠物主人统计数据
    public func fetchDataStatistics() async throws -> PetOwner {
        let resp: RespWrapper<PetOwner> = try await NetworkManager.shared
            .request("/petFriendly/client/dataStatistics", method: .get, needToken: true)
        guard let data = resp.data else {
            throw NSError(domain: resp.msg ?? NSLocalizedString("auth_stats_fail", comment: ""), code: resp.code)
        }
        return data
    }

    
    // 内存刷新
    @MainActor
    public func cache(_ info: UserInfoResp) async {
        AccountStore.shared.user = info.data.user
        
        // 关键优化：/getInfo 返回的数据源自 Session，统计类数据（pets, points等）可能存在延迟。
        // 我们优先保留本地已有的最新数据，并立即触发一次全量统计刷新。
        if AccountStore.shared.petOwner == nil {
            AccountStore.shared.petOwner = info.data.petOwner
        } else if let newData = info.data.petOwner {
            // 只更新非统计类基础字段，防止覆盖最新的动态数值
            var current = AccountStore.shared.petOwner
            current?.name = newData.name
            current?.petAvatar = newData.petAvatar
            current?.ownerId = newData.ownerId
            current?.ext = newData.ext
            AccountStore.shared.petOwner = current
        }
        
        AccountStore.shared.updateSettingsFromExt(info.data.petOwner?.ext)
        ThemeManager.shared.refreshFromSettings()
        
        // 赋值
        self.user = info
        
        // 登录/刷新后立即同步最新统计与宠物列表
        PetViewModel.shared.fetchPets()
        Task {
            await AccountStore.shared.refreshStats()
        }
    }

    
    // MARK: - 注册（邮箱验证方式）
    
    /// 发送注册邮箱验证码
    /// 后端返回: {"code":200,"msg":"操作成功","data":{"hint":"验证码已发送至邮箱，请查收"}}
    /// data 是一个对象（提示文案），而非布尔值，故使用 [String: String] 承载，避免 JSON 解码类型不匹配。
    func registerSendCode(email: String) async throws {
        let params: [String: Any] = ["email": email]
        let resp: RespWrapper<[String: String]> = try await NetworkManager.shared.request(
            "/auth/register/sendCode",
            method: .post,
            parameters: params,
            encoding: JSONEncoding.default,
            needToken: false)
        if resp.code != 200 {
            throw NSError(domain: resp.msg ?? NSLocalizedString("auth_send_fail", comment: ""), code: resp.code)
        }
    }
    
    /// 邮箱验证码注册
    func registerByEmail(email: String, code: String, username: String, password: String, legalVersion: String) async throws {
        let params: [String: Any] = [
            "email": email,
            "code": code,
            "username": username,
            "password": password,
            "privacyAccepted": true,
            "termsAccepted": true,
            "legalVersion": legalVersion,
        ]
        let resp: RespWrapper<Bool> = try await NetworkManager.shared.request(
            "/auth/register/email",
            method: .post,
            parameters: params,
            encoding: JSONEncoding.default,
            needToken: false,
            encryptFlag: true)
        if resp.code != 200 {
            throw NSError(domain: resp.msg ?? NSLocalizedString("reg_fail", comment: ""), code: resp.code)
        }
    }
    
    /// 更新用户信息到 pet_owner
    func updateProfile(name: String?, avatar: String?, ext: String? = nil) async throws {
        var params: [String: Any] = [:]
        if let name = name { params["name"] = name }
        if let avatar = avatar { params["petAvatar"] = avatar }
        if let ext = ext { params["ext"] = ext }
        
        let resp: RespWrapper<Bool> = try await NetworkManager.shared.request("/petFriendly/client/updateProfile",
                                                                       method: .post,
                                                                       parameters: params,
                                                                       encoding: JSONEncoding.default,
                                                                       needToken: true)
        if resp.code == 200 {
            // 刷新缓存
            let info = try await fetchUserInfo()
            await cache(info)
        } else {
            throw NSError(domain: resp.msg ?? NSLocalizedString("auth_op_fail", comment: ""), code: resp.code)
        }
    }
    
    /// 退出登录
    @MainActor
    func logout() async throws {
        print("🚀 [AuthService] 开始调用 /auth/logout")
        defer {
            NetworkManager.shared.clearToken()
            AccountStore.shared.logout()
        }
        _ = try await NetworkManager.shared.request("/auth/logout", method: .post, parameters: nil) as RespWrapper<JSONAny>
    }
    
    // MARK: - 忘记密码
    
    /// 发送密码重置验证码
    /// 后端返回: {"code":200,"msg":"操作成功","data":{"hint":"验证码已发送至邮箱，请查收","sentVia":"email"}}
    /// data 是一个对象（提示文案），而非布尔值，故使用 [String: String] 承载，避免 JSON 解码类型不匹配。
    func sendResetCode(email: String) async throws {
        let params: [String: Any] = ["account": email]
        let resp: RespWrapper<[String: String]> = try await NetworkManager.shared.request(
            "/auth/forgotPwd/sendCode",
            method: .post,
            parameters: params,
            encoding: JSONEncoding.default,
            needToken: false)
        if resp.code != 200 {
            throw NSError(domain: resp.msg ?? NSLocalizedString("auth_send_fail", comment: ""), code: resp.code)
        }
    }
    
    /// 重置密码
    func resetPassword(email: String, code: String, newPassword: String) async throws {
        let params: [String: Any] = [
            "email": email,
            "code": code,
            "newPassword": newPassword
        ]
        let resp: RespWrapper<Bool> = try await NetworkManager.shared.request(
            "/auth/forgotPwd/reset",
            method: .post,
            parameters: params,
            encoding: JSONEncoding.default,
            needToken: false,
            encryptFlag: true)
        if resp.code != 200 {
            throw NSError(domain: resp.msg ?? NSLocalizedString("auth_reset_fail", comment: ""), code: resp.code)
        }
    }
}
