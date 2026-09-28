//
//  DesignSystem.swift
//  PetFriendly
//
//  设计系统 — 统一色彩、渐变、阴影、字体、动画
//

import SwiftUI
import UIKit

// MARK: - 语义化颜色体系
struct PFColors {
    // 品牌主色 (动态绑定 ThemeManager)
    @MainActor
    static var primary: Color { ThemeManager.shared.dynamicColor }
    @MainActor
    static var primaryLight: Color { ThemeManager.shared.dynamicColorLight }
    @MainActor
    static var primaryDark: Color { ThemeManager.shared.dynamicColor } // 简化，暂与主色一致或深色模式下的主色
    
    // 辅助色
    static let accent        = Color(hex: "F472B6")   // 玫瑰粉
    static let accentLight   = Color(hex: "FBCFE8")
    
    // 功能色
    static let success       = Color(hex: "34D399")
    static let warning       = Color(hex: "FBBF24")
    static let danger        = Color(hex: "F87171")
    static let info          = Color(hex: "60A5FA")
    
    // 背景层级
    static var background: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? .black : UIColor(red: 248/255, green: 247/255, blue: 255/255, alpha: 1)
        })
    }
    static var surface: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1) : .white
        })
    }
    static var surfaceSecondary: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(red: 44/255, green: 44/255, blue: 46/255, alpha: 1) : UIColor(red: 243/255, green: 240/255, blue: 255/255, alpha: 1)
        })
    }
    
    // 文字层级
    static var textPrimary: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? .white : UIColor(red: 31/255, green: 41/255, blue: 55/255, alpha: 1)
        })
    }
    static var textSecondary: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(white: 0.7, alpha: 1) : UIColor(red: 107/255, green: 114/255, blue: 128/255, alpha: 1)
        })
    }
    static var textTertiary: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(white: 0.5, alpha: 1) : UIColor(red: 156/255, green: 163/255, blue: 175/255, alpha: 1)
        })
    }
    
    // 分割线
    static let divider       = Color(hex: "E5E7EB").opacity(0.6)
    
    // 卡片背景（毛玻璃）
    static let cardGlass     = Color.white.opacity(0.85)
    
    // Gender 颜色
    static let genderMale    = Color(hex: "60A5FA")
    static let genderFemale  = Color(hex: "F472B6")
}

// MARK: - 渐变预设
@MainActor
struct PFGradients {
    // 品牌渐变 (支持主题色-浅色-主题色要求)
    static var brand: LinearGradient {
        LinearGradient(
            colors: [PFColors.primary, PFColors.primaryLight, PFColors.primary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // 品牌渐变（水平）
    static var brandHorizontal: LinearGradient {
        LinearGradient(
            colors: [PFColors.primary, PFColors.primaryLight],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // 急救红
    static let emergency = LinearGradient(
        colors: [Color(hex: "EF4444"), Color(hex: "F97316")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 成就金
    static let achievement = LinearGradient(
        colors: [Color(hex: "F59E0B"), Color(hex: "FBBF24")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 健康绿
    static let health = LinearGradient(
        colors: [Color(hex: "10B981"), Color(hex: "34D399")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 头部背景
    static let headerOverlay = LinearGradient(
        colors: [Color.black.opacity(0.5), Color.clear],
        startPoint: .bottom,
        endPoint: .center
    )
    
    // 美容紫
    static let beauty = LinearGradient(
        colors: [Color(hex: "8B5CF6"), Color(hex: "A78BFA")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 生日粉
    static let birthday = LinearGradient(
        colors: [Color(hex: "EC4899"), Color(hex: "F472B6")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 疫苗蓝
    static let vaccine = LinearGradient(
        colors: [Color(hex: "3B82F6"), Color(hex: "60A5FA")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 卡片微渐变
    static let cardSubtle = LinearGradient(
        colors: [Color.white, Color(hex: "F8F7FF")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // 徽章金色渐变
    static let badgeGold = LinearGradient(
        colors: [Color(hex: "F6D365"), Color(hex: "FDA085")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 徽章深色背景
    static let badgeDarkBg = RadialGradient(
        colors: [Color(hex: "1A1A2E"), Color(hex: "0F0F1A")],
        center: .center,
        startRadius: 50,
        endRadius: 400
    )
    
    // 彩虹渐变 (描边用)
    static let rainbow = AngularGradient(
        colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
        center: .center
    )
    
    // 液态玻璃基础渐变
    static var liquidGlass: LinearGradient {
        LinearGradient(
            colors: [.white.opacity(0.15), .white.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - 阴影预设
@MainActor
struct PFShadows {
    /// 轻阴影 — 卡片
    static func card(_ color: Color = .black) -> some ViewModifier {
        ShadowModifier(color: color.opacity(0.08), radius: 12, x: 0, y: 4)
    }
    
    /// 浮起阴影 — 按钮、FAB
    static func elevated(_ color: Color? = nil) -> some ViewModifier {
        ShadowModifier(color: (color ?? PFColors.primary).opacity(0.3), radius: 16, x: 0, y: 8)
    }
    
    /// 底部阴影 — 导航栏
    static func bottom() -> some ViewModifier {
        ShadowModifier(color: .black.opacity(0.06), radius: 8, x: 0, y: -2)
    }
}

private struct ShadowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    
    func body(content: Content) -> some View {
        content.shadow(color: color, radius: radius, x: x, y: y)
    }
}

@MainActor
extension View {
    func pfCardShadow() -> some View {
        self.modifier(PFShadows.card())
    }
    
    /// 追踪当前场景名称（用于性能监控日志）
    func trackScene(_ name: String) -> some View {
        self.onAppear {
            UIState.shared.currentSceneName = name
            print("[SCENE] Entered: \(name)")
        }
    }
    
    func pfElevatedShadow(_ color: Color? = nil) -> some View {
        self.modifier(PFShadows.elevated(color))
    }
    
    /// 流体玻璃风格修饰符 (Fluid Glass - 极致有机感，iOS 26/27 动态流体版 - 纯净液态无主题色版)
    func liquidGlass(cornerRadius: CGFloat = 24) -> some View {
        self.background(
            TimelineView(.animation) { timeline in
                let date = timeline.date
                let timeInterval = date.timeIntervalSince1970
                let angle = Angle.degrees(timeInterval.remainder(dividingBy: 8) * 45) // 每8秒旋转一圈，丝滑柔和
                
                ZStack {
                    // 1. 基底：超薄无磨砂透明材质
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(0.07))
                    
                    // 2. 动态液态流态层：模拟内部液态折射光晕 (纯白色调)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            AngularGradient(
                                colors: [
                                    .white.opacity(0.25),
                                    .clear,
                                    .white.opacity(0.12),
                                    .white.opacity(0.18),
                                    .white.opacity(0.08),
                                    .clear
                                ],
                                center: .center,
                                angle: angle
                            )
                        )
                        .blur(radius: 6)
                    
                    // 3. 动态光感边缘层：随时间流动的边缘折射高光 (纯白色调)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    .white.opacity(0.85),
                                    .white.opacity(0.25),
                                    .white.opacity(0.7),
                                    .white.opacity(0.25),
                                    .white.opacity(0.85)
                                ],
                                center: .center,
                                angle: angle
                            ),
                            lineWidth: 1.3
                        )
                }
            }
        )
        // 4. 定向立体投影
        .shadow(color: Color.black.opacity(0.18), radius: 15, x: 0, y: 8)
    }
    
    /// 流体毛玻璃风格修饰符 (适配深浅模式的液态+毛玻璃效果)
    func liquidFrostedGlass(cornerRadius: CGFloat = 24) -> some View {
        self.background(
            TimelineView(.animation) { timeline in
                let date = timeline.date
                let timeInterval = date.timeIntervalSince1970
                let angle = Angle.degrees(timeInterval.remainder(dividingBy: 8) * 45) // 每8秒旋转一圈，丝滑柔和
                
                ZStack {
                    // 1. 基底：原生毛玻璃材质 (适配深浅模式)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                    
                    // 2. 动态液态流态层：纯白色调液态折射光晕
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            AngularGradient(
                                colors: [
                                    .white.opacity(0.25),
                                    .clear,
                                    .white.opacity(0.18),
                                    .white.opacity(0.08),
                                    .clear
                                ],
                                center: .center,
                                angle: angle
                            )
                        )
                        .blur(radius: 6)
                    
                    // 3. 动态光感边缘层：随时间流动的边缘折射高光 (纯白色调)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    .white.opacity(0.85),
                                    .white.opacity(0.25),
                                    .white.opacity(0.7),
                                    .white.opacity(0.25),
                                    .white.opacity(0.85)
                                ],
                                center: .center,
                                angle: angle
                            ),
                            lineWidth: 1.3
                        )
                }
            }
        )
        // 4. 定向立体投影
        .shadow(color: Color.black.opacity(0.18), radius: 15, x: 0, y: 8)
    }
}

// MARK: - 字体层级
struct PFFonts {
    static let largeTitle  = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title       = Font.system(size: 22, weight: .bold, design: .rounded)
    static let title2      = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let headline    = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let subheadline = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let body        = Font.system(size: 15, weight: .regular)
    static let callout     = Font.system(size: 14, weight: .medium)
    static let caption     = Font.system(size: 12, weight: .regular)
    static let caption2    = Font.system(size: 11, weight: .medium)
}

// MARK: - 动画曲线
struct PFAnimation {
    static let spring       = Animation.spring(response: 0.4, dampingFraction: 0.75)
    static let springGentle = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let springBouncy = Animation.spring(response: 0.35, dampingFraction: 0.6)
    static let ease         = Animation.easeInOut(duration: 0.3)
    static let easeOut      = Animation.easeOut(duration: 0.25)
}

// MARK: - 间距常量
struct PFSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
    
    /// 标准头部高度 (基于屏幕比例) — 使用安全的 PFScreen 而非已弃用的 UIScreen.main
    static var headerHeight: CGFloat { PFScreen.width * 2.4 / 16 }
}

// MARK: - 屏幕尺寸安全访问器
/// 替代已弃用的 UIScreen.main.bounds — 从活跃的 UIWindowScene 获取屏幕尺寸
enum PFScreen {
    /// 当前活跃窗口场景
    private static var activeScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
    }
    
    static var width: CGFloat { activeScene?.screen.bounds.width ?? 375 }
    static var height: CGFloat { activeScene?.screen.bounds.height ?? 812 }
    
    /// 安全区域顶部 inset
    static var safeAreaTop: CGFloat {
        activeScene?.windows.first?.safeAreaInsets.top ?? 47
    }
    
    /// 安全区域底部 inset
    static var safeAreaBottom: CGFloat {
        activeScene?.windows.first?.safeAreaInsets.bottom ?? 34
    }
}

// MARK: - 圆角常量
struct PFRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let full: CGFloat = 100
}

// MARK: - 通用毛玻璃卡片容器
struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = PFSpacing.lg
    
    init(padding: CGFloat = PFSpacing.lg, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: PFRadius.lg)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: PFRadius.lg)
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
            )
            .pfCardShadow()
    }
}

// MARK: - 渐变按钮
struct PFButton: View {
    let title: LocalizedStringKey
    let icon: String?
    let gradient: LinearGradient
    let isOutline: Bool
    let isLoading: Bool
    let action: () -> Void
    
    init(_ title: LocalizedStringKey, icon: String? = nil, gradient: LinearGradient? = nil, isOutline: Bool = false, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.gradient = gradient ?? PFGradients.brand
        self.isOutline = isOutline
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            if !isLoading {
                action()
            }
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: isOutline ? PFColors.primary : .white))
                        .scaleEffect(0.8)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(PFFonts.callout)
            }
            .foregroundColor(isOutline ? PFColors.primary : .white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Group {
                    if isOutline {
                        Capsule()
                            .stroke(PFColors.primary, lineWidth: 1.5)
                            .background(Color.clear)
                    } else {
                        Capsule()
                            .fill(gradient)
                    }
                }
            )
            .pfElevatedShadow()
        }
        .disabled(isLoading)
    }
}

// MARK: - 通用按压按钮样式（原生轻压感 + 透明度反馈）
struct PFSimplePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - 地图工具按钮按压样式（Apple Maps 风格轻按压反馈）
struct PFMapToolButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .overlay(
                Rectangle()
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.06 : 0))
                    .allowsHitTesting(false)
            )
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}


// MARK: - 渐变标签
struct PFTag: View {
    let text: LocalizedStringKey
    let gradient: LinearGradient
    
    init(text: LocalizedStringKey, gradient: LinearGradient) {
        self.text = text
        self.gradient = gradient
    }
    
    var body: some View {
        Text(text)
            .font(PFFonts.caption2)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(gradient)
            .clipShape(Capsule())
    }
}

// MARK: - 光晕头像容器
@MainActor
struct GlowAvatar: View {
    let url: URL?
    let size: CGFloat
    let glowColor: Color
    
    init(url: URL?, size: CGFloat = 72, glowColor: Color? = nil) {
        self.url = url
        self.size = size
        self.glowColor = glowColor ?? PFColors.primary
    }
    
    var body: some View {
        Group {
            if let url = url {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ZStack {
                        Circle().fill(PFColors.surfaceSecondary)
                        PFPetLoadingInline(size: 14)
                    }
                }
            } else {
                Image("PetLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.2)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [glowColor.opacity(0.6), glowColor.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
        )
        .shadow(color: glowColor.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 脉冲动画效果
struct PulseEffect: ViewModifier {
    @State private var isPulsing = false
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .stroke(color.opacity(0.4), lineWidth: 2)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(
                        Animation.easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            )
            .onAppear { isPulsing = true }
    }
}

extension View {
    func pulseEffect(color: Color = Color(hex: "F87171")) -> some View {
        self.modifier(PulseEffect(color: color))
    }
}

// MARK: - 滚动追踪与 UI 状态
/// 全局 UI 状态，用于管理 TabBar 隐藏等逻辑
/// 地图底部弹窗的三态枚举
enum MapSheetDetent: Int, CaseIterable {
    case collapsed = 0  // 仅搜索框
    case half = 1       // 半屏
    case full = 2       // 全屏
}

class UIState: ObservableObject {
    static let shared = UIState()
    @Published var isTabBarHidden: Bool = false
    @Published var navigationProgress: CGFloat = 0 // 0: Expanded two rows, 1: Merged one row
    @Published var selectedTab: Int = 0
    @Published var hasVisitedPets: Bool = false
    @Published var isMapListExpanded: Bool = false

    // 自定义菜单栏高度常量（供地图弹窗定位使用）
    static let tabBarBarHeight: CGFloat = 56      // 胶囊条本身高度
    static let tabBarPadding: CGFloat = 8         // 底部间距
    static var tabBarTotalHeight: CGFloat {        // 含安全区总高度
        tabBarBarHeight + tabBarPadding + PFScreen.safeAreaBottom
    }
    
    // 地图底部弹窗状态
    @Published var mapSheetDetent: MapSheetDetent = .half
    @Published var mapSheetTopY: CGFloat = PFScreen.height * 0.45 // 弹窗顶部Y坐标
    @Published var showGlobalLogin: Bool = false {
        didSet {
            if showGlobalLogin {
                currentSceneName = "GlobalLogin"
            }
        }
    }
    
    @Published var isSearching: Bool = false {
        didSet {
            if isSearching {
                currentSceneName = "GlobalSearch"
            }
        }
    }
    
    @Published var searchText: String = ""
    
    // 全局上传状态
    @Published var isUploading: Bool = false {
        didSet {
            if isUploading {
                currentSceneName = "GlobalUpload"
            }
        }
    }
    @Published var uploadProgress: Double = 0
    @Published var isUploadFinished: Bool = false
    
    // Toast 提示（AirPods 风格上半屏悬浮胶囊：浅/深色毛玻璃 + 类型配色）
    // 通过独立 UIWindow（windowLevel = statusBar + 1）承载，确保永远悬浮在一切 sheet/cover/浮窗之上。
    @Published var toastMessage: String? = nil
    @Published var toastStyle: ToastStyle = .normal
    @Published var toastIcon: String? = nil
    private var toastTimer: Timer?
    private var toastWindow: UIWindow?
    private var toastHostingController: UIHostingController<ToastOverlayView>?
    
    // 性能监控与调试
    @Published var isDebugMode: Bool = false
    @Published var showPerformanceFPS: Bool = false
    @Published var currentSceneName: String = "Unknown"
    
    @MainActor
    func showToast(_ message: String) {
        showToast(message, style: .normal, icon: nil)
    }

    /// 统一提示弹窗。style 决定配色、默认图标与触感强度（normal/warning/error 逐级增强）。
    /// icon 为可选 SF Symbol，传 nil 时使用 style 的默认图标；触感按 style 级别递增。
    /// 通过独立窗口承载，始终悬浮在最前，不被任何 sheet/cover/浮窗盖住。
    @MainActor
    func showToast(_ message: String, style: ToastStyle = .normal, icon: String? = nil) {
        let hadWindow = toastWindow != nil
        toastStyle = style
        // icon 未指定时使用该级别的默认图标
        toastIcon = icon ?? style.defaultIcon

        // 提示内容出现时按级别触发震动（light → medium → heavy 逐级增强）
        let (hapticStyle, intensity) = style.haptic
        Haptics.play(hapticStyle, intensity: intensity)

        // 首次创建：先建好空窗口（ToastOverlayView 空态布局），下一 RunLoop 再写入内容，
        // 确保顶部滑入动画从空态→内容 完整触发
        if !hadWindow {
            presentToastWindowIfNeeded()
            toastMessage = nil
            DispatchQueue.main.async { [weak self] in
                self?.toastMessage = message
            }
        } else {
            // 窗口已存在：直接更新内容触发滑入
            toastMessage = message
        }

        // 无论是否复用窗口，都重置自动消失计时器
        toastTimer?.invalidate()
        toastTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismissToastWindow()
            }
        }
    }

    /// 创建/复用全局 toast 悬浮窗口（windowLevel 高于所有弹层）
    @MainActor
    private func presentToastWindowIfNeeded() {
        guard toastWindow == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .statusBar + 1   // 盖过一切正常窗口与弹层
        window.isUserInteractionEnabled = false
        window.backgroundColor = .clear
        // 对齐当前深浅主题，确保 ToastView 的 @Environment(\.colorScheme) 正确解析
        window.overrideUserInterfaceStyle = ThemeManager.shared.currentStyle

        let overlay = ToastOverlayView()
        let host = UIHostingController(rootView: overlay)
        host.view.backgroundColor = .clear
        window.rootViewController = host
        // 注意：不调用 makeKeyAndVisible，避免抢走真实 keyWindow 的焦点（如正在输入的文字）
        window.isHidden = false

        toastWindow = window
        toastHostingController = host
    }

    /// 淡出并移除全局 toast 悬浮窗口
    @MainActor
    private func dismissToastWindow() {
        guard let window = toastWindow else { return }
        // 给宿主内的下滑出动画一点时间再移除窗口（与滑入一致，平缓淡出）
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut, animations: {
            window.alpha = 0
        }) { _ in
            window.isHidden = true
            self.toastWindow = nil
            self.toastHostingController = nil
            self.toastMessage = nil
        }
    }
    
    // 跨页跳转标志位
    @Published var pendingMapFilter: String? = nil // 例如 "饮水地"
    @Published var pendingMapRadius: Int? = nil    // 例如 20000
    
    // 是否强制隐藏（如在二级页面中）
    @Published var isTabBarForceHidden: Bool = false
    
    // 记录最后一次滑动的 Y 坐标
    private var lastY: CGFloat = 0
    // 阈值，滑动超过此距离才触发隐藏/显示
    private let threshold: CGFloat = 10
    
    func updateScroll(offset: CGFloat) {
        let diff = offset - lastY
        
        // 如果处于强制隐藏状态，不响应滚动自动显示
        if isTabBarForceHidden { return }
        
        if diff > threshold {
            // 向下滚动 -> 隐藏
            if !isTabBarHidden {
                withAnimation(.spring()) {
                    isTabBarHidden = true
                }
            }
        } else if diff < -threshold {
            // 向上滚动 -> 显示
            if isTabBarHidden {
                withAnimation(.spring()) {
                    isTabBarHidden = false
                }
            }
        }
        
        lastY = offset
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollViewOffsetTracker: View {
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("scroll")).minY)
        }
        .frame(height: 0)
    }
}


struct ScrollBounceModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.scrollBounceBehavior(.basedOnSize)
        } else {
            content
        }
    }
}

// MARK: - 圆角辅助工具
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - 图像保存助手
class ImageSaver: NSObject {
    var onSuccess: (() -> Void)?
    var onError: ((Error) -> Void)?
    
    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }
    
    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            onError?(error)
        } else {
            onSuccess?()
        }
    }
}

// MARK: - Image Interaction Components
struct ImageDetailView: View {
    let imageUrl: String?
    let image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    @State private var showSaveAlert = false
    
    private let loader = ImageSaver()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Group {
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                } else if let urlStr = imageUrl, let url = URL(string: NetworkManager.fullUrl(urlStr)?.absoluteString ?? "") {
                    CachedAsyncImage(url: url) { img in
                        img.resizable()
                    } placeholder: {
                        PFPetLoadingInline(size: 14)
                    }
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                }
            }
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastScale
                        lastScale = value
                        scale *= delta
                    }
                    .onEnded { _ in
                        lastScale = 1.0
                        if scale < 1.0 {
                            withAnimation(.spring()) {
                                scale = 1.0
                                offset = .zero
                            }
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        if scale > 1.0 {
                            offset = CGSize(width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height)
                        }
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring()) {
                    if scale > 1.0 {
                        scale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = 2.0
                    }
                }
            }
            .onLongPressGesture {
                Haptics.play(.medium)
                showSaveAlert = true
            }
            
            // Top Close Button
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.7))
                            .padding()
                    }
                    Spacer()
                }
                Spacer()
            }
        }
        .confirmationDialog(NSLocalizedString("mall_save_image_confirm", comment: ""), isPresented: $showSaveAlert) {
            Button("alert_save") {
                saveImage()
            }
            Button("alert_cancel", role: .cancel) { }
        }
    }
    
    private func saveImage() {
        if let uiImage = image {
            performSave(uiImage)
        } else if let urlStr = imageUrl {
            Task {
                if let url = URL(string: NetworkManager.fullUrl(urlStr)?.absoluteString ?? "") {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let downloadedImage = UIImage(data: data) {
                            performSave(downloadedImage)
                        }
                    } catch {
                        print("Download failed: \(error)")
                    }
                }
            }
        }
    }
    
    private func performSave(_ uiImage: UIImage) {
        loader.onSuccess = {
            showSuccessHUD(message: NSLocalizedString("alert_save_success", comment: ""))
        }
        loader.onError = { error in
            showErrorAlert(error)
        }
        loader.writeToPhotoAlbum(image: uiImage)
    }
}

struct PFImageInteractable: ViewModifier {
    let imageUrl: String?
    let image: UIImage?
    
    @State private var showFullScreen = false
    @State private var showSaveAlert = false
    
    private let loader = ImageSaver()
    
    func body(content: Content) -> some View {
        content
            .onTapGesture(count: 2) {
                Haptics.play(.medium)
                showFullScreen = true
            }
            .onLongPressGesture {
                Haptics.play(.heavy)
                showSaveAlert = true
            }
            .fullScreenCover(isPresented: $showFullScreen) {
                ImageDetailView(imageUrl: imageUrl, image: image)
            }
            .confirmationDialog(NSLocalizedString("mall_save_image_confirm", comment: ""), isPresented: $showSaveAlert) {
                Button("alert_save") {
                    saveImage()
                }
                Button("alert_cancel", role: .cancel) { }
            }
    }
    
    private func saveImage() {
        if let uiImage = image {
            performSave(uiImage)
        } else if let urlStr = imageUrl {
            Task {
                if let url = URL(string: NetworkManager.fullUrl(urlStr)?.absoluteString ?? "") {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let downloadedImage = UIImage(data: data) {
                            performSave(downloadedImage)
                        }
                    } catch {
                        print("Download failed: \(error)")
                    }
                }
            }
        }
    }
    
    private func performSave(_ uiImage: UIImage) {
        loader.onSuccess = {
            showSuccessHUD(message: NSLocalizedString("alert_save_success", comment: ""))
        }
        loader.onError = { error in
            showErrorAlert(error)
        }
        loader.writeToPhotoAlbum(image: uiImage)
    }
}

extension View {
    func pfImageInteractable(url: String? = nil, image: UIImage? = nil) -> some View {
        self.modifier(PFImageInteractable(imageUrl: url, image: image))
    }
}

// MARK: - Toast 提示（AirPods 风格上半屏悬浮胶囊）

/// 提示样式三级体系：normal 普通、warning 警告、error 错误。
/// 显示与触感逐级增强：
/// - normal：默认图标（info），轻触感
/// - warning：警示图标，中触感
/// - error：明显错误图标，重触感
enum ToastStyle {
    case normal, warning, error

    /// 该级别默认图标（SF Symbol），可被调用方传入的 icon 覆盖
    var defaultIcon: String? {
        switch self {
        case .normal: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "exclamationmark.octagon.fill"
        }
    }

    /// 该级别默认触感（逐级增强：medium → heavy → 最重）
    /// 1.2.0：整体提档一档，避免最低档(light)在真机上几乎无感
    var haptic: (UIImpactFeedbackGenerator.FeedbackStyle, CGFloat) {
        switch self {
        case .normal: return (.medium, 0.8)
        case .warning: return (.heavy, 0.9)
        case .error: return (.heavy, 1.0)
        }
    }
}

struct ToastView: View {
    let message: String
    var style: ToastStyle = .normal
    var icon: String? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    /// 主题化背景填充色
    private var fillColor: Color {
        switch style {
        case .normal:
            // 浅色=纯白，深色=纯黑
            return isDark ? Color(hex: "000000") : Color.white
        case .warning:
            return isDark ? Color(hex: "7A5B00") : Color(hex: "FFF3CD")
        case .error:
            return isDark ? Color(hex: "8C1D18") : Color(hex: "FDE2E1")
        }
    }

    /// 主题化外阴影描边色：浅色=浅灰，深色=深灰
    private var borderColor: Color {
        isDark ? Color.white.opacity(0.18) : Color.black.opacity(0.12)
    }

    /// 加粗文字颜色：浅色=黑色，深色=白色
    private var foregroundColor: Color {
        isDark ? Color.white : Color.black
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
            }
            Text(message)
                .font(PFFonts.callout.weight(.bold))
                .tracking(1.1)
                .lineLimit(3)
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: PFScreen.width * 0.75)
        .background(
            Capsule()
                .fill(fillColor)
                .overlay(Capsule().strokeBorder(borderColor, lineWidth: 1))
        )
        .shadow(color: borderColor, radius: 10, x: 0, y: 4)
        // 从顶部下滑入 / 上滑出
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// 承载全局 Toast 的悬浮层视图（独立窗口内，永远置顶）。
/// 根据 UIState.toastMessage 的有无自动滑入/滑出。
struct ToastOverlayView: View {
    @ObservedObject private var uiState = UIState.shared

    var body: some View {
        ZStack {
            if let message = uiState.toastMessage {
                VStack {
                    HStack {
                        Spacer()
                        ToastView(
                            message: message,
                            style: uiState.toastStyle,
                            icon: uiState.toastIcon
                        )
                        .padding(.top, 12)
                        Spacer()
                    }
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // 线性且优雅的滑入/滑出：easeInOut 让起止都平缓、中间匀速，时长略长更从容
        .animation(.easeInOut(duration: 0.5), value: uiState.toastMessage)
    }
}

// MARK: - App 版本更新检测（AppUpdater）
/// 统一的新版本检测器。
/// - 支持「稍后 / 忽略 / 立即更新」三个选项。
/// - 忽略的版本会持久化记录（UserDefaults），后续不再提示，直到出现更新的版本。
/// - 用于 App 启动检测与设置页手动检测，二者共用同一套逻辑与弹窗。
@MainActor
final class AppUpdater: ObservableObject {
    static let shared = AppUpdater()

    // 弹窗状态：有新版本时弹一个 alert，同时承载「版本更新」与（60 分钟内可用的）「彩蛋领取」，
    // 根据 easterEggAvailable 动态展示文案与按钮，且不向用户透露 60 分钟时效
    enum AppUpdaterAlert: Int, Identifiable {
        case update = 0 // 有新版本（更新 + 可选彩蛋）
        var id: Int { rawValue }
    }
    @Published var activeAlert: AppUpdaterAlert? = nil
    /// 彩蛋领取中（弹窗显示加载动画，等接口完成再关）
    @Published var isClaiming = false
    @Published var latestVersion = ""
    @Published var updateURL = ""
    /// 待领取彩蛋的版本号
    var latestEasterEggVersion = ""
    /// 最新版本发布时间（用于展示"X 分钟前更新"）
    @Published var latestPublishTime: Date? = nil
    /// 是否处于彩蛋可领取窗口（发布时间 < 60 分钟）
    @Published var easterEggAvailable = false
    /// 最新版本发布时间距现在多少分钟（用于"X 分钟前更新"）
    var easterEggMinutesAgo: Int {
        guard let t = latestPublishTime else { return 0 }
        return max(0, Int(Date().timeIntervalSince(t) / 60))
    }
    /// "X 分钟前发布"文案（不透露 60 分钟时效）
    var easterEggPublishText: String {
        String(format: NSLocalizedString("easter_egg_publish_minutes", comment: ""), easterEggMinutesAgo)
    }
    /// 是否正在检测（设置页用于展示加载态）
    @Published var isChecking = false

    // 文件分享根地址，IPA 下载链接格式: \(baseURL)/PetFriendly-x.y.z.ipa
    private let fileHostBase = Secrets.fileHostBaseURL
    private let fileListAPI = Secrets.fileListURL
    private let ignoredVersionKey = "ignoredUpdateVersion"

    /// 当前被忽略的版本（一直忽略，直到出现更新版本）
    var ignoredVersion: String? {
        get { UserDefaults.standard.string(forKey: ignoredVersionKey) }
        set { UserDefaults.standard.set(newValue, forKey: ignoredVersionKey) }
    }

    /// App 启动检测：失败静默、有新版且未被忽略才弹窗
    func checkOnLaunch() {
        check(silent: true)
    }

    /// 设置页手动检测：失败/已最新给出 toast 反馈，有新版弹窗
    func checkManual() {
        check(silent: false)
    }

    private func check(silent: Bool) {
        isChecking = true
        guard let url = URL(string: fileListAPI) else {
            isChecking = false
            if !silent { UIState.shared.showToast(NSLocalizedString("update_check_fail", comment: ""), style: .error, icon: "exclamationmark.triangle.fill") }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "path": Secrets.fileSharePath,
            "password": "",
            "page": 1,
            "per_page": 0,
            "refresh": false
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isChecking = false

                if let error = error {
                    if !silent { UIState.shared.showToast(String(format: NSLocalizedString("update_check_fail_detail", comment: ""), error.localizedDescription), style: .error, icon: "exclamationmark.triangle.fill") }
                    return
                }
                guard let data = data else {
                    if !silent { UIState.shared.showToast(NSLocalizedString("update_no_data", comment: ""), style: .warning, icon: "exclamationmark.circle") }
                    return
                }

                do {
                    let resp = try JSONDecoder().decode(OpenListResponse.self, from: data)
                    guard resp.code == 200 else {
                        if !silent { UIState.shared.showToast(NSLocalizedString("update_check_fail", comment: ""), style: .error, icon: "exclamationmark.triangle.fill") }
                        return
                    }

                    // 从文件列表解析出所有版本（含发布时间），取最新
                    let files = resp.data.content
                        .compactMap { file -> (version: String, time: Date?)? in
                            guard let v = file.version else { return nil }
                            return (v, file.publishTime)
                        }
                        .sorted { self.isNewerVersion(latest: $0.version, current: $1.version) }

                    guard let latestFile = files.first else {
                        if !silent { UIState.shared.showToast(NSLocalizedString("update_no_pkg", comment: "")) }
                        return
                    }

                    let latest = latestFile.version
                    let current = AppVersion.version
                    if self.isNewerVersion(latest: latest, current: current) {
                        self.latestVersion = latest
                        self.latestPublishTime = latestFile.time
                        self.updateURL = "\(self.fileHostBase)/PetFriendly-\(latest).ipa"
                        // 被忽略的版本不再弹窗提示；手动检查时按"已是最新版本"给出反馈
                        if latest == self.ignoredVersion {
                            if !silent {
                                UIState.shared.showToast(String(format: NSLocalizedString("update_uptodate", comment: ""), latest), style: .normal, icon: "checkmark.circle.fill")
                            }
                            return
                        }
                        // 更新时间距当前 < 60 分钟时彩蛋可领取；否则不显示彩蛋（但不告知用户时效）
                        self.easterEggAvailable = self.isEasterEggFresh(version: latest, publishTime: latestFile.time)
                        self.activeAlert = .update
                    } else if !silent {
                        UIState.shared.showToast(String(format: NSLocalizedString("update_uptodate", comment: ""), latest), style: .normal, icon: "checkmark.circle.fill")
                    }
                } catch {
                    if !silent { UIState.shared.showToast(NSLocalizedString("update_parse_fail", comment: "")) }
                }
            }
        }.resume()
    }

    // MARK: - 三个选项动作

    /// 稍后再说：本次关闭，下次进入再提示
    func dismissLater() {
        activeAlert = nil
    }

    /// 忽略此版本：持久化记录，一直忽略
    func ignoreVersion() {
        ignoredVersion = latestVersion
        activeAlert = nil
    }

    /// 立即更新：跳转浏览器下载
    func updateNow() {
        if let url = URL(string: updateURL) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: fileHostBase) {
            UIApplication.shared.open(url)
        }
        activeAlert = nil
    }

    // MARK: - 新版本彩蛋

    /// 发布时间距当前是否 < 60 分钟（用于判断是否弹彩蛋领取弹窗）
    private func isEasterEggFresh(version: String, publishTime: Date?) -> Bool {
        guard let publishTime, publishTime < Date() else { return false }
        let gap = Date().timeIntervalSince(publishTime)
        guard gap >= 0, gap < 60 * 60 else { return false }
        latestEasterEggVersion = version
        return true
    }

    /// 领取彩蛋积分（100）
    /// 领取彩蛋积分（100）：显示加载动画，等接口响应完毕后再关闭弹窗
    func claimEasterEgg() {
        let version = latestEasterEggVersion
        guard !version.isEmpty, !isClaiming else { return }
        isClaiming = true
        Task {
            do {
                let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                    "/petFriendly/client/easterEgg/claimNewVersion",
                    method: .post,
                    parameters: ["version": version],
                    needToken: true,
                    showLoading: false
                )
                await MainActor.run {
                    isClaiming = false
                    if resp.code == 200 {
                        UIState.shared.showToast(resp.msg ?? NSLocalizedString("easter_egg_claim_success", comment: ""), style: .normal, icon: "party.popper.fill")
                        activeAlert = nil   // 成功才关闭弹窗
                    } else {
                        UIState.shared.showToast(resp.msg ?? "彩蛋领取失败", style: .warning, icon: "party.popper.fill")
                    }
                }
            } catch {
                await MainActor.run {
                    isClaiming = false
                    // 展示后端返回的具体提示（如"该版本彩蛋积分已领取过，感谢参与"），解析失败再兜底
                    let bizError = error as? BizError
                    UIState.shared.showToast(bizError?.errorDescription ?? "彩蛋领取失败", style: .warning, icon: "party.popper.fill")
                }
            }
        }
    }

    /// 距发布时间过去了多少分钟（用于"X 分钟前更新"文案）
    static func minutesSince(_ time: Date?) -> Int? {
        guard let time else { return nil }
        let gap = Date().timeIntervalSince(time)
        guard gap >= 0 else { return nil }
        return Int(gap / 60)
    }

    /// 从文件名中解析版本号，如 "PetFriendly-1.0.161.ipa" -> "1.0.161"
    private static func extractVersion(fromFileName name: String) -> String? {
        let prefix = "PetFriendly-"
        guard name.hasPrefix(prefix), name.hasSuffix(".ipa") else { return nil }
        let start = name.index(name.startIndex, offsetBy: prefix.count)
        let end = name.index(name.endIndex, offsetBy: -4)
        let version = name[start..<end]
        let parts = version.split(separator: ".")
        guard parts.count >= 2, parts.allSatisfy({ Int($0) != nil }) else { return nil }
        return String(version)
    }

    private func isNewerVersion(latest: String, current: String) -> Bool {
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let count = max(latestParts.count, currentParts.count)
        for i in 0..<count {
            let latestVal = i < latestParts.count ? latestParts[i] : 0
            let currentVal = i < currentParts.count ? currentParts[i] : 0
            if latestVal > currentVal { return true }
            else if latestVal < currentVal { return false }
        }
        return false
    }
}
