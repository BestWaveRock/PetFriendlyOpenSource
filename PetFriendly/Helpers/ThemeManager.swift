//
//  ThemeManager.swift
//  PetFriendly
//
//  主题色管理器 — 10 种预设主题色，持久化存储，深浅模式自适应
//

import SwiftUI

/// UIKit may resolve dynamic colors from SwiftUI's background renderer.
/// Keep this provider outside `ThemeManager`'s MainActor isolation and only capture immutable snapshots.
private func makeTraitAdaptiveColor(light: UIColor, dark: UIColor, alpha: CGFloat = 1) -> Color {
    Color(UIColor { traitCollection in
        let resolved = traitCollection.userInterfaceStyle == .dark ? dark : light
        return alpha == 1 ? resolved : resolved.withAlphaComponent(alpha)
    })
}

// MARK: - 主题预设
struct ThemePreset: Identifiable, Equatable {
    let id: String       // hex 值作为唯一标识
    let name: String
    let hex: String
    
    /// 浅色模式下的颜色
    var color: Color { Color(hex: hex) }
    
    /// 深色模式下颜色（降低亮度 30%，保持辨识度）
    var darkColor: Color {
        let c = UIColor(Color(hex: hex))
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h),
                     saturation: Double(s * 0.85),
                     brightness: Double(b * 0.7))
    }
    
    static func == (lhs: ThemePreset, rhs: ThemePreset) -> Bool {
        lhs.hex == rhs.hex
    }
}

// MARK: - 10 种预设主题色
extension ThemePreset {
    static let all: [ThemePreset] = [
        .init(id: "6C63FF", name: "theme_violet", hex: "6C63FF"),
        .init(id: "F472B6", name: "theme_rose", hex: "F472B6"),
        .init(id: "EC4899", name: "theme_sakura",   hex: "EC4899"),
        .init(id: "F97316", name: "theme_coral", hex: "F97316"),
        .init(id: "F59E0B", name: "theme_amber", hex: "F59E0B"),
        .init(id: "10B981", name: "theme_emerald", hex: "10B981"),
        .init(id: "3B82F6", name: "theme_sky", hex: "3B82F6"),
        .init(id: "6366F1", name: "theme_indigo",   hex: "6366F1"),
        .init(id: "6B7280", name: "theme_graphite", hex: "6B7280"),
        .init(id: "EF4444", name: "theme_classic_red", hex: "EF4444"),
    ]
    
    /// 默认主题
    static let `default` = all[0] // 紫罗兰
    
    /// 根据 hex 查找预设
    static func find(hex: String) -> ThemePreset {
        all.first(where: { $0.hex == hex }) ?? .default
    }
}

// MARK: - 主题管理器
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    enum Theme: String {
        case light, dark, system
        func style() -> UIUserInterfaceStyle {
            switch self {
            case .light: return .light
            case .dark: return .dark
            case .system: return .unspecified
            }
        }
    }
    
    /// 顶部背景图 URL
    var headerBackgroundImageUrl: String {
        AccountStore.shared.settings.headerBackgroundImageUrl
    }
    
    /// 当前生效的主题预设
    @Published var currentPreset: ThemePreset

    /// 当前生效的深浅模式（供独立窗口如 Toast 悬浮窗初始化时对齐主题）
    var currentStyle: UIUserInterfaceStyle {
        let themeStr = AccountStore.shared.settings.theme
        let theme = Theme(rawValue: themeStr) ?? .system
        return theme.style()
    }
    
    private init() {
        // 先从 AccountStore 取，如果没有则取本地持久化
        let hex = AccountStore.shared.settings.accentColorHex
        self.currentPreset = ThemePreset.find(hex: hex)
    }
    
    /// 确认切换主题色
    func applyPreset(_ preset: ThemePreset) {
        AccountStore.shared.settings.accentColorHex = preset.hex
        AccountStore.shared.saveSettings()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPreset = preset
        }
    }
    
    func refreshFromSettings() {
        let hex = AccountStore.shared.settings.accentColorHex
        withAnimation(.easeInOut) {
            self.currentPreset = ThemePreset.find(hex: hex)
        }
        syncInterfaceStyle() // 这里会触发全窗口样式刷新
        objectWillChange.send()
    }
    
    func syncInterfaceStyle() {
        let themeStr = AccountStore.shared.settings.theme
        let theme = Theme(rawValue: themeStr) ?? .system // 修改默认解析为 system
        
        let style = theme.style()
        
        // 遍历所有 Window 并应用样式，确保全页面立即生效
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .forEach { scene in
                scene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = style
                }
            }
    }
    
    func updateHeaderImage(_ url: String) {
        AccountStore.shared.settings.headerBackgroundImageUrl = url
        AccountStore.shared.saveSettings()
        objectWillChange.send() // 强制刷新
    }
    
    /// 根据当前颜色模式返回合适的主题色
    func accentColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? currentPreset.darkColor : currentPreset.color
    }
    
    /// 浅色模式主题色（始终正常亮度）
    var lightAccent: Color { currentPreset.color }
    
    /// 深色模式主题色（降低亮度）
    var darkAccent: Color { currentPreset.darkColor }
    
    /// 自动适应深浅模式的主题主色 (用 UIKit 动态颜色构造)
    var dynamicColor: Color {
        let light = UIColor(lightAccent)
        let dark = UIColor(darkAccent)
        return makeTraitAdaptiveColor(light: light, dark: dark)
    }
    
    /// 自动适应深浅模式的主题浅色（用于渐变中间色，或次级背景）
    var dynamicColorLight: Color {
        let light = UIColor(lightAccent)
        let dark = UIColor(darkAccent)
        return makeTraitAdaptiveColor(light: light, dark: dark, alpha: 0.6)
    }
}
