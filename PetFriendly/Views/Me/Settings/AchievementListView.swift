import SwiftUI

struct AchievementListView: View {
    typealias Achievement = AchievementCard.Achievement
    
    @EnvironmentObject var store: AccountStore
    @Environment(\.dismiss) var dismiss
    
    @State private var achievements: [Achievement] = []
    @State private var isLoading = false
    
    // 详情弹窗状态 (使用 item 模式确保每次弹出都是全新的 View 实例，解决 StateObject 初始化数据延迟问题)
    @State private var selectedAchievement: Achievement?
    
    var achievedList: [Achievement] {
        achievements.filter { $0.achieved ?? false }
    }
    
    var ongoingList: [Achievement] {
        achievements.filter { !($0.achieved ?? false) }
    }
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            if isLoading && achievements.isEmpty {
                // 骨架屏：加载中占位卡片（与「我的足迹」加载一致，避免高度突变跳动）
                ScrollView {
                    VStack(spacing: PFSpacing.xxl) {
                        VStack(alignment: .leading, spacing: PFSpacing.lg) {
                            HStack {
                                Text(NSLocalizedString("achievement_section_ongoing", comment: ""))
                                    .font(PFFonts.headline)
                                    .foregroundColor(PFColors.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, PFSpacing.xl)
                            ForEach(0..<4, id: \.self) { _ in
                                SkeletonAchievementRow()
                            }
                        }
                    }
                    .padding(.vertical, PFSpacing.lg)
                }
            } else {
                ScrollView {
                    VStack(spacing: PFSpacing.xxl) {
                        sectionView(
                            title: "achievement_section_ongoing",
                            items: ongoingList,
                            emptyText: "achievement_empty_ongoing"
                        )
                        
                        sectionView(
                            title: "achievement_section_achieved",
                            items: achievedList,
                            emptyText: "person_achievements_empty"
                        )
                    }
                    .padding(.vertical, PFSpacing.lg)
                }
                .refreshable {
                    fetchAchievements()
                }
            }
        }
        .navigationTitle("achievement_list_title")
        .navigationBarTitleDisplayMode(.inline)
        .pfToyBackground()
        .onAppear {
            if achievements.isEmpty {
                fetchAchievements()
            }
        }
        // 使用 item 模式，完全绕开 NavigationStack 深度 bug 且保证数据实时刷新
        .fullScreenCover(item: $selectedAchievement) { item in
            AchievementDetailView(
                id: item.id,
                title: item.title ?? "未知",
                icon: item.icon ?? "star.fill",
                color: getColor(for: item.color)
            )
            .trackScene("AchievementDetail")
        }
    }
    
    // MARK: - 区域视图
    @ViewBuilder
    private func sectionView(title: String, items: [Achievement], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: PFSpacing.lg) {
            HStack {
                Text(NSLocalizedString(title, comment: ""))
                    .font(PFFonts.headline)
                    .foregroundColor(PFColors.textPrimary)
                
                Text("\(items.count)")
                    .font(PFFonts.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(title.contains("ongoing") ? PFGradients.emergency : PFGradients.brand)
                    .clipShape(Capsule())
                
                Spacer()
            }
            .padding(.horizontal, PFSpacing.xl)
            
            if items.isEmpty {
                HStack {
                    Spacer()
                    Text(NSLocalizedString(emptyText, comment: ""))
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textTertiary)
                        .padding()
                    Spacer()
                }
                .background(PFColors.surface)
                .cornerRadius(PFRadius.lg)
                .padding(.horizontal, PFSpacing.xl)
            } else {
                VStack(spacing: PFSpacing.md) {
                    ForEach(items) { item in
                        Button {
                            selectedAchievement = item
                        } label: {
                            achievementRow(item)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, PFSpacing.xl)
            }
        }
    }
    
    // MARK: - 行视图
    @ViewBuilder
    private func achievementRow(_ item: Achievement) -> some View {
        let isAchieved = item.achieved ?? false
        let uiColor = getColor(for: item.color)
        
        HStack(spacing: PFSpacing.md) {
            ZStack {
                Circle()
                    .fill(uiColor.opacity(0.12))
                    .frame(width: 54, height: 54)
                
                Image(systemName: item.icon ?? "star.fill")
                    .font(.system(size: 24))
                    .foregroundColor(uiColor)
                    .grayscale(isAchieved ? 0 : 1)
                    .opacity(isAchieved ? 1 : 0.4)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title ?? "")
                    .font(PFFonts.subheadline)
                    .foregroundColor(PFColors.textPrimary)
                
                Text(item.subtitle ?? "")
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textSecondary)
                    .lineLimit(1)
                
                if !isAchieved, let progress = item.progress {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(PFColors.surfaceSecondary)
                                .frame(height: 4)
                            
                            Capsule()
                                .fill(uiColor)
                                .frame(width: geo.size.width * CGFloat(progress), height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 4)
                }
            }
            
            Spacer()
            
            if isAchieved {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(PFColors.success)
                    .font(.system(size: 20))
            } else if let progress = item.progress {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(item.currentValue ?? 0)/\(item.thresholdValue ?? 0)")
                        .font(PFFonts.caption2)
                        .foregroundColor(PFColors.textSecondary)
                    Text("\(Int(progress * 100))%")
                        .font(PFFonts.caption2.bold())
                        .foregroundColor(uiColor)
                }
            }
        }
        .padding(PFSpacing.lg)
        .background(PFColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PFRadius.lg))
        .pfCardShadow()
        .contentShape(RoundedRectangle(cornerRadius: PFRadius.lg))
    }
    
    // MARK: - 数据
    private func fetchAchievements() {
        isLoading = true
        Task {
            do {
                let resp: AchievementListResp = try await NetworkManager.shared.request("/petFriendly/client/achievementsList", method: .get, needToken: true)
                await MainActor.run {
                    self.achievements = resp.rows
                    self.isLoading = false
                }
            } catch {
                print("获取成就列表失败: \(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }
    
    private func getColor(for color: String?) -> Color {
        switch color {
        case "warning": return PFColors.warning
        case "info": return PFColors.info
        case "accent": return PFColors.accent
        case "success": return PFColors.success
        case "danger": return PFColors.danger
        default: return PFColors.primary
        }
    }
}

// MARK: - 骨架屏：加载中占位卡片（与「我的足迹」加载动画一致）
struct SkeletonAchievementRow: View {
    @State private var opacity: Double = 0.3

    var body: some View {
        HStack(spacing: PFSpacing.md) {
            // 图标占位
            Circle()
                .fill(PFColors.divider)
                .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 8) {
                // 标题占位
                RoundedRectangle(cornerRadius: 4)
                    .fill(PFColors.divider)
                    .frame(width: 120, height: 14)
                // 副标题占位
                RoundedRectangle(cornerRadius: 4)
                    .fill(PFColors.divider)
                    .frame(width: 160, height: 10)
                // 进度条占位
                Capsule()
                    .fill(PFColors.divider)
                    .frame(height: 4)
            }

            Spacer()
        }
        .padding(PFSpacing.lg)
        .background(PFColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PFRadius.lg))
        .pfCardShadow()
        .padding(.horizontal, PFSpacing.xl)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                opacity = 0.7
            }
        }
    }
}
