import SwiftUI

/// 类原生侧边栏菜单项风格的 Tab 按钮
/// 参考 Amperfy SideBar 的 UICollectionLayoutListConfiguration(appearance: .sidebar) 设计理念：
/// - 极简的图标+文字布局
/// - 顶部选中指示条（替代传统背景高亮）
/// - 克制的色彩变化，仅选中态使用主题色
struct SidebarTabItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                // 顶部选中指示条（类侧边栏选中高亮）
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? accentColor : .clear)
                    .frame(width: 24, height: 3)
                    .padding(.bottom, 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                // 图标
                Image(systemName: icon)
                    .font(.system(size: 21, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? accentColor : .secondary)
                    .scaleEffect(isSelected ? 1.0 : 0.95)

                // 标题文字
                Text(LocalizedStringKey(title))
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? accentColor : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 向下兼容（保持原有的 TabBarItem 名称，内部使用新设计）

struct TabBarItem: View {
    let icon: String
    let title: String
    let selectType: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        SidebarTabItem(
            icon: icon,
            title: title,
            isSelected: isSelected,
            accentColor: .blue,
            action: action
        )
    }
}