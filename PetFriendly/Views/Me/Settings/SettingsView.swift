import SwiftUI
import Alamofire

/// 1. 三态枚举，RawValue 存 UserDefaults
enum Theme: String, CaseIterable {
    case 浅色   = "light"
    case 深色   = "dark"
    case 跟随系统 = "system"
    
    func style() -> UIUserInterfaceStyle {
        switch self {
        case .浅色:      return .light
        case .深色:      return .dark
        case .跟随系统:   return .unspecified
        }
    }
}

extension Theme {
    var localizedName: String {
        switch self {
        case .浅色:   return NSLocalizedString("theme_light", comment: "")
        case .深色:   return NSLocalizedString("theme_dark", comment: "")
        case .跟随系统: return NSLocalizedString("theme_system", comment: "")
        }
    }
}

// MARK: - 业务层 API
struct AppConfigResp: Decodable {
    let code: Int
    let msg: String?
    let data: ConfigData?
    
    struct ConfigData: Decodable {
        let companyName: String?
    }
}

// 文件列表接口响应模型（POST /api/fs/list）
// 响应示例: {"code":200,"message":"success","data":{"content":[{"name":"PetFriendly-1.0.161.ipa","path":"/YOUR_SHARE_TOKEN/..."}],"total":1}}
struct OpenListResponse: Codable {
    let code: Int
    let data: OpenListData
}

struct OpenListData: Codable {
    let content: [OpenListFile]
}

struct OpenListFile: Codable {
    let name: String
    /// 发布时间（ISO8601 UTC，如 2026-08-04T09:06:30.292252432Z）
    var modified: String?
    var created: String?

    /// 发布时间（优先 modified，回退 created）
    /// 兼容带纳秒小数（如 .292252432Z）的 ISO8601 字符串
    /// 统一按 UTC 时区解析（OpenList 返回 UTC，避免本地时区解释导致时间差偏移）
    var publishTime: Date? {
        let iso = (modified ?? created)?.trimmingCharacters(in: .whitespaces)
        guard let iso, !iso.isEmpty else { return nil }
        // 去掉小数秒：ISO8601DateFormatter 的 .withInternetDateTime 不支持小数秒
        // （不能保留 .000，否则返回 nil，导致彩蛋 60 分钟窗口判断失效）
        let normalized: String
        if let dotRange = iso.range(of: "."), let zRange = iso.range(of: "Z") {
            let seconds = iso[..<dotRange.lowerBound]
            let zone = iso[zRange.lowerBound...]
            normalized = "\(seconds)\(zone)"
        } else {
            normalized = iso
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // 统一按 UTC 解析
        return formatter.date(from: normalized)
    }

    /// 从文件名解析版本号，如 "PetFriendly-1.0.169.ipa" -> "1.0.169"
    var version: String? {
        let prefix = "PetFriendly-"
        guard name.hasPrefix(prefix), name.hasSuffix(".ipa") else { return nil }
        let start = name.index(name.startIndex, offsetBy: prefix.count)
        let end = name.index(name.endIndex, offsetBy: -4)
        let v = name[start..<end]
        let parts = v.split(separator: ".")
        guard parts.count >= 2, parts.allSatisfy({ Int($0) != nil }) else { return nil }
        return String(v)
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: AccountStore
    @EnvironmentObject var uiState: UIState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    
    // 观察 AppUpdater，驱动版本检测按钮加载动画
    @ObservedObject private var updater = AppUpdater.shared
    @State private var companyName: String = NSLocalizedString("settings_company_name", comment: "")
    @State private var isLoadingCompany = false
    @State private var cacheSizeString: String = "0 KB"
    @State private var isClearing = false
    @State private var showClearConfirm = false
    
    // 版本点击彩蛋
    @State private var versionClicks = 0
    @State private var showAddressSetting = false
    @State private var tempBaseUrl = ""

    // 服务端版本号（关于页动态获取）
    @State private var serverVersion: String?
    @State private var isFetchingServerVersion = false
    
    // 隐私与数据
    @State private var isExporting = false
    @State private var showLogoutConfirm = false
    /// B 方案：注销账号确认弹窗（输入原因 + 加载态 + 成功才关）
    @State private var deleteAccountDialog: PFActionDialogConfig?
    
    // 检查更新状态由 AppUpdater.shared 统一管理
    @State private var showApiLog = false
    @State private var showCrashLogs = false
    @State private var showPerformanceSettings = false
    @State private var showServiceOrders = false
    @State private var showWallet = false

    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: PFSpacing.xl) {
                    appearanceSection
                    privacySection
                    aboutSection
                    supportSection
                    systemSettingsSection
                    
                    if store.user != nil {
                        logoutButton
                    }
                    
                    if uiState.isDebugMode {
                        closeDebugButton
                    }
                    
                    footerView
                    Spacer(minLength: 50)
                }
                .padding(.vertical, PFSpacing.lg)
            }
        }
        .navigationTitle("settings_title")
        .navigationBarTitleDisplayMode(.inline)
        .pfToyBackground()
        .onAppear {
            print("[SettingsView] Loaded! v1.0.77") // 控制台验证
            themeManager.syncInterfaceStyle()
            // 调试模式由持久化缓存驱动（首次连点版本号 10 次开启，之后保持，除非手动关闭）
            uiState.isDebugMode = store.settings.isDebugMode
            Task { await fetchCompanyConfig() }
            refreshCacheSize()
        }
        .trackScene("Settings")
        .alert("alert_clear_cache_title", isPresented: $showClearConfirm) {
            Button("alert_cancel", role: .cancel) { }
            Button("alert_confirm_clear", role: .destructive) { clearCache() }
        } message: {
            Text("alert_clear_cache_message")
        }
        .alert("debug_server_title", isPresented: $showAddressSetting) {
            TextField("debug_server_placeholder", text: $tempBaseUrl)
                .textInputAutocapitalization(.never)
            Button("alert_cancel", role: .cancel) { }
            Button("debug_save_restart") {
                store.settings.apiBaseUrl = tempBaseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                store.saveSettings()
                showSuccessHUD(message: NSLocalizedString("debug_address_changed", comment: ""))
            }
        } message: {
            Text(String(format: NSLocalizedString("debug_current_address", comment: ""), NetworkManager.shared.baseURL))
        }
        .alert("alert_logout_title", isPresented: $showLogoutConfirm) {
            Button("alert_cancel", role: .cancel) { }
            Button("settings_logout", role: .destructive) {
                Task { @MainActor in
                    AccountStore.shared.handleSession(.logoutStarted)
                    dismiss()
                    // 兜底：无论网络请求是否成功/超时，都在限定时间内强制恢复状态，
                    // 避免 /auth/logout 请求挂起导致 sessionState 卡在 .signingOut，
                    // 从而使"我的"页面永远停留在加载动画（切换无效、需重启 App）。
                    // 6 秒兜底会先于网络层 30 秒超时触发，保证 UI 尽快恢复。
                    let recoveryTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 6_000_000_000) // 6 秒
                        if AccountStore.shared.isLoggingOut {
                            NetworkManager.shared.clearToken()
                            AccountStore.shared.handleSession(.logoutFailed)
                            AccountStore.shared.logout()
                        }
                    }
                    do { try await AuthService.shared.logout() }
                    catch {
                        NetworkManager.shared.clearToken()
                        AccountStore.shared.handleSession(.logoutFailed)
                        AccountStore.shared.logout()
                    }
                    recoveryTask.cancel()
                }
            }
        }
        // B 方案：注销账号确认弹窗（输入原因 + 加载态 + 成功才关）
        .fullScreenCover(item: $deleteAccountDialog) { config in
            PFActionDialog(
                config: config,
                onConfirm: { reason in await confirmDeleteAccount(reason: reason) },
                onCancel: { deleteAccountDialog = nil }
            )
        }
        .sheet(isPresented: $showApiLog) {
            NavigationStack {
                ApiLogListView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("btn_close") { showApiLog = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showPerformanceSettings) {
            NavigationStack {
                PerformanceSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("btn_close") { showPerformanceSettings = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showServiceOrders) {
            NavigationStack {
                ServiceOrderListView(title: NSLocalizedString("settings_service_orders_title", comment: ""), type: "")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("btn_close") { showServiceOrders = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showWallet) {
            NavigationStack {
                WalletView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("btn_close") { showWallet = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showCrashLogs) {
            CrashLogListView()
        }
    }
    
    // MARK: - Sections
    
    private var appearanceSection: some View {
        settingsSection(title: "settings_appearance") {
            // 主题外观
            HStack {
                iconLabel(icon: "moon.stars.fill", color: PFColors.primary, title: "settings_theme")
                Spacer()
                Picker("settings_theme", selection: Binding(
                    get: { Theme(rawValue: store.settings.theme) ?? .浅色 },
                    set: { newValue in
                        store.settings.theme = newValue.rawValue
                        store.saveSettings()
                        themeManager.syncInterfaceStyle()
                    }
                )) {
                    ForEach(Theme.allCases, id: \.self) { t in
                        Text(t.localizedName).tag(t)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            .padding(PFSpacing.lg)
            
            Divider().padding(.leading, 48)
            
            // 特色主题色
            NavigationLink(destination: ThemeColorPickerView().environmentObject(themeManager)) {
                HStack {
                    iconLabel(icon: "paintpalette.fill", color: themeManager.accentColor(for: colorScheme), title: "settings_accent_color")
                    Spacer()
                    Text(LocalizedStringKey(themeManager.currentPreset.name))
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textSecondary)
                    Circle()
                        .fill(themeManager.accentColor(for: colorScheme))
                        .frame(width: 16, height: 16)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PFColors.textTertiary)
                }
                .padding(PFSpacing.lg)
            }
            
            Divider().padding(.leading, 48)
            
            // 主图设置
            NavigationLink(destination: HeaderImageSettingView().environmentObject(themeManager)) {
                HStack {
                    iconLabel(icon: "photo.fill", color: PFColors.primary, isGhost: true, title: "settings_header_image")
                    Spacer()
                    if !themeManager.headerBackgroundImageUrl.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(PFColors.success)
                            .font(.system(size: 14))
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PFColors.textTertiary)
                }
                .padding(PFSpacing.lg)
            }
            
            Divider().padding(.leading, 48)
            
            // 语言选择
            HStack {
                iconLabel(icon: "character.bubble.fill", color: PFColors.accent, isGhost: true, title: "settings_language")
                Spacer()
                Picker("settings_language", selection: Binding(
                    get: { store.settings.language },
                    set: { newValue in
                        store.settings.language = newValue
                        store.saveSettings()
                        Haptics.play()
                    }
                )) {
                    Text("settings_language_cn").tag("cn")
                    Text("English").tag("en")
                }
                .pickerStyle(MenuPickerStyle())
            }
            .padding(PFSpacing.lg)
        }
    }
    
    private var privacySection: some View {
        settingsSection(title: "settings_privacy_data") {
            // 数据导出
            Button(action: exportUserData) {
                HStack {
                    iconLabel(icon: "tray.and.arrow.down.fill", color: PFColors.info, isGhost: true, title: "settings_export_data")
                    Spacer()
                    if isExporting {
                        PFPetLoadingInline(size: 18)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(PFColors.textTertiary)
                    }
                }
                .padding(PFSpacing.lg)
            }
            
            Divider().padding(.leading, 48)
            
            // 账号注销
            Button(action: { presentDeleteAccountDialog() }) {
                HStack {
                    iconLabel(icon: "person.badge.minus.fill", color: PFColors.danger, isGhost: true, title: "settings_delete_account")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PFColors.textTertiary)
                }
                .padding(PFSpacing.lg)
            }
        }
    }
    
    private var aboutSection: some View {
        settingsSection(title: "settings_about") {
            HStack {
                iconLabel(icon: "info.circle.fill", color: PFColors.info, title: "settings_version")
                Spacer()
                Text("\(AppVersion.version) (Build \(AppVersion.gitHash))")
                    .font(PFFonts.callout)
                    .foregroundColor(PFColors.textSecondary)
            }
            .padding(PFSpacing.lg)
            .contentShape(Rectangle())
            .onTapGesture {
                versionClicks += 1
                if versionClicks >= 10 {
                    versionClicks = 0
                    store.settings.isDebugMode.toggle()
                    store.saveSettings()
                    uiState.isDebugMode = store.settings.isDebugMode
                    Haptics.notify(.success)
                    if uiState.isDebugMode {
                        uiState.showToast("调试模式已开启")
                    } else {
                        uiState.showToast("调试模式已关闭")
                    }
                } else if versionClicks > 7 {
                    uiState.showToast(String(format: NSLocalizedString("debug_tap_more", comment: ""), 10 - versionClicks))
                }
            }
            
            Divider().padding(.leading, 48)
            
            // 服务端版本行：动态获取，点击重新获取
            HStack {
                iconLabel(icon: "server.rack", color: PFColors.accent, title: "settings_server_version")
                Spacer()
                if isFetchingServerVersion {
                    PFPetLoadingInline(size: 16)
                } else {
                    Text(serverVersion ?? "settings_server_version_fetch")
                        .font(PFFonts.callout)
                        .foregroundColor(serverVersion == nil ? PFColors.textTertiary : PFColors.textSecondary)
                }
                Button(action: { fetchServerVersion() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PFColors.primary)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isFetchingServerVersion)
            }
            .padding(PFSpacing.lg)
            .contentShape(Rectangle())
            .onTapGesture {
                fetchServerVersion()
            }
            .onAppear {
                if serverVersion == nil { fetchServerVersion() }
            }
            
            Divider().padding(.leading, 48)
            
            Button(action: {
                checkForUpdates()
            }) {
                HStack {
                    iconLabel(icon: "arrow.clockwise.circle.fill", color: PFColors.primary, title: "settings_check_updates")
                    Spacer()
                    if updater.isChecking {
                        PFPetLoadingInline(size: 18)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(PFColors.textTertiary)
                    }
                }
                .padding(PFSpacing.lg)
            }
            .buttonStyle(PlainButtonStyle())
            
            Divider().padding(.leading, 48)
            
            // 启动时自动检查更新开关
            Toggle(isOn: Binding(
                get: { store.settings.checkUpdateOnLaunch },
                set: { newValue in
                    store.settings.checkUpdateOnLaunch = newValue
                    store.saveSettings()
                    Haptics.play()
                }
            )) {
                HStack {
                    iconLabel(icon: "bolt.fill", color: PFColors.accent, isGhost: true, title: "settings_check_update_on_launch")
                    Spacer()
                }
            }
            .padding(PFSpacing.lg)
            
            if uiState.isDebugMode {
                Divider().padding(.leading, 48)
                
                // 一键切换 API
                Toggle(isOn: Binding(
                    get: { store.settings.useLocalServer },
                    set: { newValue in
                        store.settings.useLocalServer = newValue
                        if newValue {
                            store.settings.apiBaseUrl = Secrets.localDevURL
                            uiState.showToast("已切换至本地开发环境")
                        } else {
                            store.settings.apiBaseUrl = Secrets.defaultBaseURL
                            uiState.showToast("已恢复至线上生产环境")
                        }
                        store.saveSettings()
                        // 强制更新 NetworkManager 的 baseURL
                        NetworkManager.shared.baseURL = store.settings.apiBaseUrl
                        Haptics.play()
                    }
                )) {
                    HStack {
                        iconLabel(icon: "server.rack", color: .green, isGhost: true, title: "settings_dev_server")
                        Spacer()
                    }
                }
                .padding(PFSpacing.lg)
                
                Divider().padding(.leading, 48)
                
                Button(action: {
                    tempBaseUrl = store.settings.apiBaseUrl
                    showAddressSetting = true
                }) {
                    HStack {
                        iconLabel(icon: "link.circle.fill", color: .blue, isGhost: true, title: "settings_debug_url")
                        Spacer()
                        Text(store.settings.apiBaseUrl)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(PFColors.textSecondary)
                        Image(systemName: "pencil.circle")
                            .foregroundColor(PFColors.primary)
                    }
                    .padding(PFSpacing.lg)
                }
            }
            
            Divider().padding(.leading, 48)
            
            Link(destination: URL(string: Secrets.privacyPolicyURL)!) {
                HStack {
                    iconLabel(icon: "hand.raised.fill", color: PFColors.primary, isGhost: true, title: "settings_privacy_policy")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PFColors.textTertiary)
                }
                .padding(PFSpacing.lg)
            }
            
            Divider().padding(.leading, 48)
            
            // 性能调试入口
            if uiState.isDebugMode {
                Divider().padding(.leading, 48)
                
                Button(action: { showPerformanceSettings = true }) {
                    HStack {
                        iconLabel(icon: "gauge.medium", color: .orange, isGhost: true, title: "settings_performance_test")
                        Spacer()
                        if uiState.showPerformanceFPS {
                            Text("FPS: \(PerformanceMonitor.shared.fps)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(PFColors.primary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(PFColors.textTertiary)
                    }
                    .padding(PFSpacing.lg)
                }
            }
            
                    // Telegram 绑定
        Divider().padding(.leading, 48)
        NavigationLink(destination: TelegramBindView()) {
            HStack {
                iconLabel(icon: "paperplane.fill", color: PFColors.accent, title: "tg_bind")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(PFColors.textTertiary)
            }
            .padding(PFSpacing.lg)
        }

        // 崩溃日志
        Divider().padding(.leading, 48)
        Button(action: { showCrashLogs = true }) {
            HStack {
                iconLabel(icon: "exclamationmark.triangle.fill", color: .orange, title: "crash_log_title")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(PFColors.textTertiary)
            }
            .padding(PFSpacing.lg)
        }

        // API日志（仅开发模式可见）
            if uiState.isDebugMode {
                Divider().padding(.leading, 48)
                Button(action: { showApiLog = true }) {
                    HStack {
                        iconLabel(icon: "ladybug.fill", color: .orange, isGhost: true, title: "api_log")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(PFColors.textTertiary)
                    }
                    .padding(PFSpacing.lg)
                }
            }
        }
    }
    
    private var supportSection: some View {
        settingsSection(title: "settings_support_feedback") {
            rowLink(destination: HelpFeedbackView(), icon: "questionmark.circle.fill", color: .orange, title: "settings_help_feedback")
            Divider().padding(.leading, 48)
            rowLink(destination: NotificationsView(), icon: "bell.fill", color: .red, title: "settings_notifications")
            Divider().padding(.leading, 48)
            HStack {
                iconLabel(icon: "envelope.fill", color: PFColors.accent, title: "settings_contact_us")
                Spacer()
                Text(Secrets.contactEmail)
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textSecondary)
            }
            .padding(PFSpacing.lg)
            .onTapGesture {
                UIPasteboard.general.string = Secrets.contactEmail
                showSuccessHUD(message: NSLocalizedString("settings_email_copied", comment: ""))
            }
        }
    }
    
    private var systemSettingsSection: some View {
        settingsSection(title: "settings_other") {
            rowLink(destination: PayPasswordSettingView().environmentObject(store), icon: "lock.shield.fill", color: .green, title: "settings_pay_password")
            Divider().padding(.leading, 48)
            rowLink(destination: PrivacySettingsView(), icon: "shield.fill", color: .blue, title: "settings_privacy_settings")
            Divider().padding(.leading, 48)
            rowLink(destination: NearbySharingSettingsView(), icon: "location.circle.fill", color: .green, title: "nearby_sharing_title")
            Divider().padding(.leading, 48)
            Button(action: { showServiceOrders = true }) {
                HStack {
                    iconLabel(icon: "list.bullet.rectangle.fill", color: .green, isGhost: true, title: "settings_service_orders")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PFColors.textTertiary)
                }
                .padding(PFSpacing.lg)
            }
            Divider().padding(.leading, 48)
            
            // 钱包
            Button(action: { showWallet = true }) {
                HStack {
                    iconLabel(icon: "wallet.pass.fill", color: .orange, isGhost: true, title: "settings_wallet")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PFColors.textTertiary)
                }
                .padding(PFSpacing.lg)
            }
            Divider().padding(.leading, 48)
            
            Button(action: { showClearConfirm = true }) {
                HStack {
                    iconLabel(icon: "trash.fill", color: .gray, isGhost: true, title: "settings_clear_cache")
                    Spacer()
                    if isClearing {
                        PFPetLoadingInline(size: 18)
                    } else {
                        Text(cacheSizeString)
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.textSecondary)
                    }
                }
                .padding(PFSpacing.lg)
            }
        }
    }
    
    private var logoutButton: some View {
        Button(action: { showLogoutConfirm = true }) {
            Text("settings_logout")
                .font(PFFonts.headline)
                .foregroundColor(PFColors.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: PFRadius.md)
                        .fill(PFColors.surface)
                )
                .pfCardShadow()
        }
        .padding(.horizontal, PFSpacing.lg)
        .padding(.top, PFSpacing.md)
    }
    
    private var closeDebugButton: some View {
        Button(action: {
            store.settings.isDebugMode = false
            store.saveSettings()
            uiState.isDebugMode = false
            uiState.showPerformanceFPS = false
            PerformanceMonitor.shared.stop()
            Haptics.notify(.success)
            uiState.showToast("调试模式已关闭")
        }) {
            Text(NSLocalizedString("close_debug", comment: ""))
                .font(PFFonts.headline)
                .foregroundColor(PFColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: PFRadius.md)
                        .fill(PFColors.surface)
                )
                .pfCardShadow()
        }
        .padding(.horizontal, PFSpacing.lg)
        .padding(.top, PFSpacing.sm)
    }
    
    private var footerView: some View {
        VStack(spacing: PFSpacing.xs) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 30))
                .foregroundColor(PFColors.primary.opacity(0.5))
                .padding(.bottom, 8)
            
            Text("settings_footer_title")
                .font(PFFonts.headline)
                .foregroundColor(PFColors.textSecondary)
            
            if isLoadingCompany {
                PFPetLoadingInline(size: 14)
            } else {
                Text("© 2026 \(companyName)")
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textTertiary)
            }
        }
        .padding(.top, PFSpacing.xxl)
    }

    // MARK: - Helpers
    
    private func iconLabel(icon: String, color: Color, isGhost: Bool = false, title: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isGhost ? color.opacity(0.1) : color)
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isGhost ? color : .white)
            }
            Text(LocalizedStringKey(title))
                .font(PFFonts.body)
                .foregroundColor(PFColors.textPrimary)
        }
    }
    
    private func rowLink<V: View>(destination: V, icon: String, color: Color, title: String) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                iconLabel(icon: icon, color: color, isGhost: true, title: title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(PFColors.textTertiary)
            }
            .padding(PFSpacing.lg)
        }
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringKey(title))
                .font(PFFonts.callout)
                .foregroundColor(PFColors.textSecondary)
                .padding(.horizontal, PFSpacing.xl)
                .padding(.bottom, PFSpacing.sm)
            
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: PFRadius.md)
                    .fill(PFColors.surface)
            )
            .padding(.horizontal, PFSpacing.lg)
            .pfCardShadow()
        }
    }
    
    // MARK: - Handlers
    
    private func fetchCompanyConfig() async {
        guard !isLoadingCompany else { return }
        isLoadingCompany = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        isLoadingCompany = false
    }
    
    private func refreshCacheSize() {
        let size = ImageCacheManager.shared.calculateCacheSize()
        if size < 1024 {
            cacheSizeString = "\(size) B"
        } else if size < 1024 * 1024 {
            cacheSizeString = String(format: "%.1f KB", Double(size) / 1024.0)
        } else {
            cacheSizeString = String(format: "%.1f MB", Double(size) / (1024.0 * 1024.0))
        }
    }
    
    private func clearCache() {
        isClearing = true
        // 1. 清理本地图片缓存
        ImageCacheManager.shared.clear()
        
        // 2. 清理本地字典数据缓存
        DictCacheManager.shared.clearAllCache()
        
        // 3. 延时反馈成功
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            refreshCacheSize()
            isClearing = false
            Haptics.notify(.success)
            uiState.showToast(NSLocalizedString("settings_clear_cache_success", comment: ""))
        }
    }
    
    private func exportUserData() {
        guard !isExporting else { return }
        isExporting = true
        Haptics.play()
        
        NetworkManager.shared.requestRaw("/petFriendly/client/exportData", method: .get) { result in
            isExporting = false
            switch result {
            case .success(let data):
                guard let csvString = String(data: data, encoding: .utf8) else {
                    showErrorHUD(message: NSLocalizedString("settings_export_fail_parse", comment: ""))
                    return
                }
                shareCSV(csvString)
            case .failure(let error):
                showErrorHUD(message: String(format: NSLocalizedString("settings_export_fail", comment: ""), error.localizedDescription))
            }
        }
    }
    
    private func shareCSV(_ content: String) {
        let fileName = "PetFriendly_Backup_\(Int(Date().timeIntervalSince1970)).csv"
        let path = NSTemporaryDirectory().appending(fileName)
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            let url = URL(fileURLWithPath: path)
            let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(vc, animated: true)
            }
        } catch {
            showErrorHUD(message: NSLocalizedString("settings_backup_fail", comment: ""))
        }
    }
    
    /// 弹出注销确认弹窗（B 方案：输入原因 + 加载态 + 成功才关）
    private func presentDeleteAccountDialog() {
        deleteAccountDialog = PFActionDialogConfig(
            title: NSLocalizedString("alert_delete_account_title", comment: ""),
            message: NSLocalizedString("alert_delete_account_message", comment: ""),
            confirmTitle: NSLocalizedString("delete_reason_confirm", comment: ""),
            destructive: true,
            confirmIcon: "person.badge.minus.fill",
            showTextField: true,
            textFieldPlaceholder: NSLocalizedString("delete_reason_placeholder", comment: "")
        )
    }

    /// 提交注销：返回 nil 成功（关弹窗）/ 非 nil 失败（保留弹窗）
    @MainActor
    private func confirmDeleteAccount(reason: String) async -> String? {
        Haptics.play()
        let params = ["reason": reason]
        do {
            let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                "/petFriendly/client/account/cancel",
                method: .post,
                parameters: params,
                encoding: JSONEncoding.default,
                needToken: true
            )
            if resp.code == 200 {
                showSuccessHUD(message: NSLocalizedString("delete_submitted", comment: ""))
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    store.logout()
                }
                return nil
            }
            return resp.msg ?? String(format: NSLocalizedString("settings_submit_fail", comment: ""), NSLocalizedString("common_unknown", comment: ""))
        } catch {
            return String(format: NSLocalizedString("settings_submit_fail", comment: ""), error.localizedDescription)
        }
    }
    
    /// 动态获取服务端版本号
    @MainActor
    private func fetchServerVersion() {
        guard !isFetchingServerVersion else { return }
        isFetchingServerVersion = true
        Task {
            defer { isFetchingServerVersion = false }
            do {
                struct ServerVersionResp: Decodable {
                    let code: Int
                    let data: ServerVersionData?
                    struct ServerVersionData: Decodable {
                        let version: String?
                    }
                }
                let resp: ServerVersionResp = try await NetworkManager.shared.request(
                    "/petFriendly/client/serverVersion", method: .get, needToken: false, showLoading: false)
                if resp.code == 200, let v = resp.data?.version, !v.isEmpty {
                    serverVersion = v
                } else {
                    UIState.shared.showToast(NSLocalizedString("settings_server_version_failed", comment: ""), style: .warning)
                }
            } catch {
                UIState.shared.showToast(NSLocalizedString("settings_server_version_failed", comment: ""), style: .warning)
            }
        }
    }

    private func checkForUpdates() {
        // 统一走 AppUpdater（与 App 启动检测共用同一套逻辑与「稍后/忽略/立即更新」弹窗）
        AppUpdater.shared.checkManual()
    }
}


// MARK: - 崩溃日志查看器
struct CrashLogListView: View {
    @Environment(\.dismiss) var dismiss
    @State private var logs: [CrashLog] = []
    @State private var selectedLog: CrashLog?
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            List {
                if logs.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle").font(.system(size: 48)).foregroundColor(.green)
                            Text("crash_log_empty").font(.headline).foregroundColor(.secondary)
                            Text("crash_log_empty_desc").font(.subheadline).foregroundColor(Color(.tertiaryLabel)).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity).padding(.vertical, 40)
                    }
                } else {
                    Section {
                        Button(action: {
                            let text = CrashReporter.shared.exportText
                            UIPasteboard.general.string = text
                        }) { Label("crash_log_copy_all", systemImage: "doc.on.doc") }
                        Button(role: .destructive) {
                            CrashReporter.shared.clearAll(); logs = []
                        } label: { Label("crash_log_clear", systemImage: "trash") }
                    }
                    Section(String(format: NSLocalizedString("crash_log_section", comment: ""), logs.count)) {
                        ForEach(logs) { log in
                            Button(action: { selectedLog = log }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(log.date).font(.caption).foregroundColor(.secondary)
                                    Text(log.summary).font(.body).foregroundColor(.primary).lineLimit(2)
                                    HStack {
                                        Text("v\(log.appVersion)").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2).background(Color.red.opacity(0.1)).cornerRadius(4)
                                        Text("iOS \(log.osVersion)").font(.caption2).foregroundColor(.secondary)
                                    }
                                }.padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("crash_log_title").navigationBarTitleDisplayMode(.inline)
            .onAppear { logs = CrashReporter.shared.allLogs }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("crash_log_close") { dismiss() }
                }
            }
            .sheet(item: $selectedLog) { log in
                NavigationStack { CrashLogDetailView(log: log) }
            }
        }
    }
}

struct CrashLogDetailView: View {
    let log: CrashLog
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    LabeledRow(label: NSLocalizedString("crash_log_time", comment: ""), value: log.date)
                    LabeledRow(label: NSLocalizedString("crash_log_version", comment: ""), value: "v\(log.appVersion)")
                    LabeledRow(label: NSLocalizedString("crash_log_system", comment: ""), value: "iOS \(log.osVersion)")
                    LabeledRow(label: NSLocalizedString("crash_log_device", comment: ""), value: log.deviceModel)
                }

                if let name = log.exceptionName {
                    Text("crash_log_exception_type").font(.headline).padding(.top, 8)
                    Text(name).font(.body.monospaced()).padding(8).background(Color(.systemGray6)).cornerRadius(8)
                }
                if let reason = log.exceptionReason {
                    Text("crash_log_reason").font(.headline).padding(.top, 8)
                    Text(reason).font(.body.monospaced()).padding(8).background(Color(.systemGray6)).cornerRadius(8)
                }

                Text("crash_log_call_stack").font(.headline).padding(.top, 8)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(log.callStack.enumerated()), id: \.offset) { i, frame in
                        Text("\(i) \(frame)").font(.caption.monospaced()).foregroundColor(.secondary)
                    }
                }.padding(8).background(Color(.systemGray6)).cornerRadius(8)
            }.padding()
        }
        .navigationTitle("crash_log_detail_title").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    let text = "Crash Report\nDate: \(log.date)\nApp: v\(log.appVersion) | iOS \(log.osVersion)\nDevice: \(log.deviceModel)\nException: \(log.exceptionName ?? "?")\nReason: \(log.exceptionReason ?? "?")\nStack:\n\(log.callStack.joined(separator: "\n"))"
                    UIPasteboard.general.string = text
                }) { Image(systemName: "doc.on.doc") }
            }
        }
    }
}
