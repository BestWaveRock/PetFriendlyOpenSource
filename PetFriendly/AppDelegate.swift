import UIKit
import SwiftUI
import Alamofire
import UserNotifications

// 全局共享的登录状态

@MainActor
final class AccountStore: ObservableObject {
    static let shared = AccountStore()
    @Published var user: UserInfo?
    @Published var petOwner: PetOwner?
    @Published private(set) var sessionState: AccountSessionState = .signedOut
    var isLoggingOut: Bool { sessionState == .signingOut }
    @Published var avatarVersion: String = "" // 用于强制刷新头像缓存
    @Published var settings = PetOwnerSettings() {
        didSet {
            // 同步到 UserDefaults 以供持久化和 NetworkManager 非隔离访问
            if let data = try? JSONEncoder().encode(settings) {
                UserDefaults.standard.set(data, forKey: "last_known_settings")
            }
            UserDefaults.standard.set(settings.apiBaseUrl, forKey: "api_base_url")
            // 同步 API 日志记录开关（由调试模式控制）
            ApiLogger.shared.setEnabled(settings.isDebugMode)
        }
    }

    private init() {
        // 尝试从本地缓存加载之前的配置
        if let data = UserDefaults.standard.data(forKey: "last_known_settings"),
           let decoded = try? JSONDecoder().decode(PetOwnerSettings.self, from: data) {
            self._settings = Published(initialValue: decoded)
        }
        // 启动时同步 API 日志记录开关（didSet 在 init 里不触发）
        ApiLogger.shared.setEnabled(self.settings.isDebugMode)
    }

    
    /// 每日签到逻辑：首次打开 APP 提示自动签到成功
    /// 1.2.0：先判断 token 已登录 + 自动签到开关；若 user 未就绪（App 重启异步恢复前）先拉取用户信息恢复，再执行签到
    func checkDailyLogin() {
        // 有 token 才可能自动签到（已登录）
        guard NetworkManager.shared.token != nil else { return }

        // 1.1.0：自动签到开关（默认开启），关闭则跳过自动签到
        let autoCheckin = UserDefaults.standard.object(forKey: "autoCheckin") as? Bool ?? true
        guard autoCheckin else {
            print("📅 Auto check-in disabled, skip")
            return
        }

        // 按本地时区计算"今天"，避免 UTC 日期在凌晨时差导致签到判断错乱
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: Date())

        Task {
            // 若 user 未就绪（App 重启后尚未恢复登录态），先拉取并缓存，确保能拿到 userId
            if self.user == nil {
                do {
                    let info = try await AuthService.shared.fetchUserInfo()
                    await AuthService.shared.cache(info)
                } catch {
                    print("Daily Check-in: user info fetch failed: \(error)")
                    return
                }
            }
            guard let userId = self.user?.userId else { return }

            let lastCheckKey = "last_checkin_date_\(userId)"
            let lastCheckDate = UserDefaults.standard.string(forKey: lastCheckKey)

            guard lastCheckDate != todayStr else { return }
            print("📅 Daily Check-in: First login today (\(todayStr))")

            do {
                // 调用后端签到接口（data 为字符串提示，如"签到成功，积分+5，爱心值+1"，不能用 BoolResp）
                let resp: RespWrapper<String> = try await NetworkManager.shared.request(
                    "/petFriendly/client/checkIn",
                    method: .post
                )

                if resp.code == 200 {
                    UserDefaults.standard.set(todayStr, forKey: lastCheckKey)

                    // 随机表情包
                    let petEmojis = ["🐱❤️", "🐶❤️", "😺💕", "🐶💓", "😸💖", "🐕❣️", "🐾✨"]
                    let randomEmoji = petEmojis.randomElement() ?? "🐱❤️"

                    await MainActor.run {
                        // 本地同步积分 (增加5分)
                        if let current = self.petOwner?.integralValue {
                            self.petOwner?.integralValue = current + 5
                        }

                        // 显示国际化提示
                        let msg = String(format: NSLocalizedString("checkin_success_format", comment: ""), randomEmoji)
                        showSuccessHUD(message: msg)
                    }
                }
            } catch {
                print("Daily Check-in failed: \(error)")
            }
        }
    }
    
    @MainActor
    func logout() {
        user = nil                    // SwiftUI 自动刷新
        petOwner = nil
        settings = PetOwnerSettings()
        PetViewModel.shared.clear()   // 清空宠物列表缓存
        ThemeManager.shared.refreshFromSettings()
        NotificationCenter.default.post(name: .logout, object: nil) // UIKit 用
        sessionState.reduce(.logoutSucceeded)
    }

    func handleSession(_ event: AccountSessionEvent) { sessionState.reduce(event) }

    /// 从 ext 字符串同步到 settings 对象
    func updateSettingsFromExt(_ ext: String?) {
        guard let ext = ext, !ext.isEmpty,
              let data = ext.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(PetOwnerSettings.self, from: data) else {
            // 如果解析失败或为空，不重置为默认，可能只是还没存过
            return
        }
        self.settings = decoded
        // 同步到 UserDefaults 以供 NetworkManager 非隔离访问
        UserDefaults.standard.set(decoded.apiBaseUrl, forKey: "api_base_url")
        ThemeManager.shared.refreshFromSettings()
    }

    /// 将 settings 对象同步到 ext 字符串
    func settingsToExt() -> String? {
        guard let data = try? JSONEncoder().encode(settings),
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }

    /// 发送到后端更新
    func saveSettings() {
        // 未登录时（无 Token）不调用同步接口，防止报错
        guard NetworkManager.shared.token != nil else {
            print("AccountStore: No token, skip server sync.")
            return
        }
        
        let ext = settingsToExt()
        Task {
            do {
                try await AuthService.shared.updateProfile(name: nil, avatar: nil, ext: ext)
                print("Settings synced to server")
            } catch {
                print("Failed to sync settings: \(error)")
            }
        }
    }

    /// 与服务器同步配置
    func syncWithServer() {
        guard NetworkManager.shared.token != nil else { return }
        Task {
            do {
                let info = try await AuthService.shared.fetchUserInfo()
                await AuthService.shared.cache(info)
                print("AccountStore: Settings synced with server")
                // 同步完基本信息后，顺便刷新下统计数据
                await refreshStats()
            } catch {
                print("AccountStore: Server sync failed, using local configuration. \(error)")
            }
        }
    }

    /// 刷新宠物统计数据
    func refreshStats() async {
        guard NetworkManager.shared.token != nil else { return }
        do {
            let stats = try await AuthService.shared.fetchDataStatistics()
            await MainActor.run {
                self.petOwner = stats
            }
        } catch {
            print("AccountStore: Refresh stats failed: \(error)")
        }
    }
}



/// 宠物主人个性化设置模型
struct PetOwnerSettings: Codable {
    var theme: String = "system"                // light, dark, system
    var accentColorHex: String = "6C63FF"       // 默认主题色 (紫罗兰)
    var headerBackgroundImageUrl: String = ""   // 自定义主图 URL
    var privacyMode: Bool = true                // 隐私开关
    var pushNotification: Bool = true           // 消息通知开关
    var allowLocationTracking: Bool = true      // 位置跟踪
    var allowPersonalizedAds: Bool = false      // 个性化广告
    var allowDataAnalysis: Bool = true          // 数据分析
    var apiBaseUrl: String = Secrets.defaultBaseURL { // 默认后端地址
        didSet {
            NetworkManager.shared.baseURL = apiBaseUrl
        }
    }
    var language: String = "cn"                 // cn=中文 (宠物友好指南), en=英文 (PetFriendly)
    var isDebugMode: Bool = false               // 是否开启调试模式
    var useLocalServer: Bool = false            // 是否使用本地开发服务器
    var checkUpdateOnLaunch: Bool = true        // App 启动时是否自动检查更新
    
    var locale: Locale {
        switch language {
        case "en": return Locale(identifier: "en")
        default:   return Locale(identifier: "zh-Hans")
        }
    }
}

extension Notification.Name {
    static let logout = Notification.Name("logout")
    static let PFPlaceFavoriteChanged = Notification.Name("PFPlaceFavoriteChanged")
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 抑制 MapKit 产生的沙盒及遥测遥测冗余日志 (OS noise)
        // 修复 NSCocoaErrorDomain 4099 及 PPSClientDonation 报错
        setenv("OS_ACTIVITY_MODE", "disable", 1)

        // 激活 WatchConnectivity，用于同步 token 到 Watch
        WatchConnector.shared.activate()

        CrashReporter.shared.install()
        UNUserNotificationCenter.current().delegate = self

        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

extension String {
    var presence: String? { isEmpty ? nil : self }
}
