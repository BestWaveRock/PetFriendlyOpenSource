//
//  AchievementDetailView.swift
//  PetFriendly
//
//  Created by PetFriendly Team.
//  Redesigned: Grow-style premium badge detail with celebratory animations.
//

import SwiftUI

// MARK: - API 模型
struct AchievementDetailResp: Decodable {
    let code: Int
    let msg: String?
    let data: AchievementDetailData?
}

struct AchievementDetailData: Decodable {
    @Int64String var id: Int64?
    let name: String?
    let description: String?
    let iconUrl: String?
    let acquired: Bool?
    let acquireTime: String?
    let progress: Double? // 0.0 ~ 1.0
    let currentValue: Int?
    let thresholdValue: Int?
    let ruleDetail: RuleDetail?
}

// 规则详情模型
struct RuleDetail: Decodable {
    let howToObtain: String?
    let conditions: [RuleCondition]?
    let relation: String? // "and" / "or" / nil (single)
    let estimatedTime: String?
    let obtainMethod: String?
    let difficulty: Int? // 1-5
    let rewards: [String]?
}

struct RuleCondition: Decodable, Identifiable {
    var id: String { name ?? UUID().uuidString }
    let name: String?
    let target: String?
    let method: String?
}

// MARK: - 视图模型
@MainActor
class AchievementDetailViewModel: ObservableObject {
    @Published var detail: AchievementDetailData?
    @Published var isLoading = false
    
    private let achievementId: Int64
    private let targetUserId: Int64?
    
    init(achievementId: Int64, targetUserId: Int64? = nil) {
        self.achievementId = achievementId
        self.targetUserId = targetUserId
    }
    
    func fetchDetail() async {
        isLoading = true
        
        let path = "/petFriendly/client/achievementDetail"
        var params: [String: Any] = ["id": String(achievementId)]
        if let targetUserId { params["targetUserId"] = String(targetUserId) }
        
        do {
            let resp: AchievementDetailResp = try await NetworkManager.shared.request(
                path, method: .get, parameters: params, needToken: true
            )
            if resp.code == 200 { self.detail = resp.data }
        } catch {
            print("获取成就详情失败: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - ✦ 单个闪烁粒子
private struct SparkleParticle: Identifiable {
    let id = UUID()
    let x: CGFloat      // -1...1 归一化坐标
    let y: CGFloat
    let size: CGFloat
    let delay: Double
    let duration: Double
}

// MARK: - ✦ 光芒放射层
private struct LightRaysView: View {
    let color: Color
    @Binding var isAnimating: Bool
    
    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) * 30.0
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.25), color.opacity(0)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: 200)
                    .offset(y: -100)
                    .rotationEffect(.degrees(angle))
            }
        }
        .rotationEffect(.degrees(isAnimating ? 360 : 0))
        .animation(
            .linear(duration: 30).repeatForever(autoreverses: false),
            value: isAnimating
        )
        .opacity(isAnimating ? 1.0 : 0.0)
        .animation(.easeIn(duration: 0.8), value: isAnimating)
    }
}

// MARK: - ✦ 粒子庆祝层
private struct SparkleOverlay: View {
    @Binding var isVisible: Bool
    let color: Color
    
    private let particles: [SparkleParticle] = (0..<24).map { _ in
        SparkleParticle(
            x: CGFloat.random(in: -1...1),
            y: CGFloat.random(in: -1...1),
            size: CGFloat.random(in: 4...10),
            delay: Double.random(in: 0...0.6),
            duration: Double.random(in: 0.8...1.6)
        )
    }
    
    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height * 0.35 // 以徽章中心为原点
            
            ForEach(particles) { p in
                Image(systemName: "sparkle")
                    .font(.system(size: p.size, weight: .bold))
                    .foregroundColor(color)
                    .position(
                        x: cx + p.x * (isVisible ? 160 : 0),
                        y: cy + p.y * (isVisible ? 160 : 0)
                    )
                    .opacity(isVisible ? 0 : 1)
                    .animation(
                        .easeOut(duration: p.duration).delay(p.delay),
                        value: isVisible
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - ✦ 圆形进度环
private struct CircularProgressRing: View {
    let progress: Double
    let color: Color
    @Binding var animatedProgress: Double
    
    var body: some View {
        ZStack {
            // 底圈
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 6)
            
            // 进度弧
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.6), color, color.opacity(0.8)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            // 中心数字
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("achievement_completion")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(width: 80, height: 80)
    }
}

// MARK: - ✦ 详情页视图
struct AchievementDetailView: View {
    let achievementId: Int64
    let initialTitle: String
    let initialIcon: String
    let initialColor: Color
    
    @StateObject private var viewModel: AchievementDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    // 动画状态
    @State private var showRays = false
    @State private var showBadge = false
    @State private var showParticles = false
    @State private var showText = false
    @State private var showCard = false
    @State private var breathe = false
    @State private var ringProgress: Double = 0
    
    init(id: String, title: String, icon: String, color: Color, targetUserId: Int64? = nil) {
        self.achievementId = Int64(id) ?? 0
        self.initialTitle = title
        self.initialIcon = icon
        self.initialColor = color
        _viewModel = StateObject(wrappedValue: AchievementDetailViewModel(achievementId: Int64(id) ?? 0, targetUserId: targetUserId))
    }
    
    // 徽章主色（已获得用品牌色，未获得用灰色）
    private var badgeColor: Color {
        viewModel.detail?.acquired == true ? initialColor : Color.gray
    }
    
    // 金色高光
    private var goldColor: Color { Color(hex: "F6D365") }
    
    var body: some View {
        ZStack {
            // ── 1. 深色背景 ──
            Color(hex: "0F0F1A").ignoresSafeArea()
            
            // 品牌色径向光晕
            RadialGradient(
                colors: [badgeColor.opacity(0.15), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 350
            )
            .offset(y: -60)
            .ignoresSafeArea()
            
            // ── 2. 光芒层 ──
            LightRaysView(color: badgeColor, isAnimating: $showRays)
                .offset(y: -60)

            // ── 3. 粒子层 ──
            if viewModel.detail?.acquired == true {
                SparkleOverlay(isVisible: $showParticles, color: goldColor)
            }

            // ── 4. 主内容 ──
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    // ─ 徽章区域 ─
                    badgeSection

                    Spacer().frame(height: 36)

                    // ─ 标题与状态 ─
                    titleSection

                    Spacer().frame(height: 32)

                    // ─ 信息卡片 ─
                    infoCard

                    Spacer().frame(height: 100)
                }
            }
            .opacity(viewModel.isLoading ? 0 : 1)

            // ── Loading 指示器（覆盖在内容之上，不触发视图树切换） ──
            if viewModel.isLoading {
                PFPetLoadingView(size: 36)
                    .scaleEffect(1.2)
            }
            
            // ── 5. 顶部返回按钮 ──
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("achievement_detail")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .trackScene("AchievementDetail")
        .onAppear {
            Task {
                await viewModel.fetchDetail()
                // 数据加载完成后再启动动画，避免 loading → 内容切换时的闪动
                startAnimationSequence()
            }
        }
    }
    
    // MARK: - 动画时序
    private func startAnimationSequence() {
        // T+0.2s: 光芒启动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showRays = true
        }
        // T+0.4s: 徽章弹入
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
                showBadge = true
            }
        }
        // T+0.8s: 粒子爆发
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showParticles = true
        }
        // T+0.9s: 文字渐显
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.6)) {
                showText = true
            }
        }
        // T+1.1s: 卡片上滑
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showCard = true
            }
        }
        // T+1.3s: 呼吸动画 + 进度环
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                breathe = true
            }
            withAnimation(.easeOut(duration: 1.2)) {
                ringProgress = viewModel.detail?.progress ?? 0
            }
        }
    }
    
    // MARK: - 徽章区域
    private var badgeSection: some View {
        ZStack {
            // 外圈旋转光环
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            badgeColor.opacity(0.6),
                            badgeColor.opacity(0.1),
                            goldColor.opacity(0.4),
                            badgeColor.opacity(0.1),
                            badgeColor.opacity(0.6)
                        ],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(showRays ? 360 : 0))
                .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: showRays)
            
            // 内部发光底盘
            Circle()
                .fill(
                    RadialGradient(
                        colors: [badgeColor.opacity(0.25), badgeColor.opacity(0.05)],
                        center: .center,
                        startRadius: 10,
                        endRadius: 70
                    )
                )
                .frame(width: 150, height: 150)
            
            // 毛玻璃内圈
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 120, height: 120)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            
            // 徽章图标
            Image(systemName: initialIcon)
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: viewModel.detail?.acquired == true
                            ? [badgeColor, goldColor]
                            : [Color.gray.opacity(0.5), Color.gray.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: badgeColor.opacity(0.6), radius: 16, x: 0, y: 4)
        }
        .scaleEffect(showBadge ? (breathe ? 1.03 : 1.0) : 0.3)
        .opacity(showBadge ? 1 : 0)
    }
    
    // MARK: - 标题区
    private var titleSection: some View {
        VStack(spacing: 12) {
            // 徽章名
            Text(viewModel.detail?.name ?? initialTitle)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // 状态标签
            if viewModel.detail?.acquired == true {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                    Text("achievement_acquired")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundColor(Color(hex: "1A1A2E"))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [goldColor, Color(hex: "FDA085")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                )
                .shadow(color: goldColor.opacity(0.4), radius: 8, x: 0, y: 4)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                    Text("achievement_locked")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
        }
        .opacity(showText ? 1 : 0)
        .offset(y: showText ? 0 : 20)
    }
    
    // MARK: - 信息卡片
    private var infoCard: some View {
        VStack(spacing: 24) {
            // ─ 描述 ─
            VStack(alignment: .leading, spacing: 8) {
                Label("achievement_description", systemImage: "text.quote")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                
                Text(viewModel.detail?.description ?? NSLocalizedString("achievement_default_desc", comment: ""))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // ─ 分隔线 ─
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
            
            // ─ 进度 ─
            VStack(alignment: .leading, spacing: 16) {
                Text("achievement_current_progress")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                
                // 进度数字展示
                if let cur = viewModel.detail?.currentValue,
                   let tgt = viewModel.detail?.thresholdValue {
                    HStack {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(cur)")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("/ \(tgt)")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        if let progress = viewModel.detail?.progress {
                            let isAcquired = viewModel.detail?.acquired ?? false
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(isAcquired ? goldColor : badgeColor)
                        }
                    }
                    
                    // 线性进度条 (已获得和进行中均展示)
                    GeometryReader { geo in
                        let isAcquired = viewModel.detail?.acquired ?? false
                        let progressVal = viewModel.detail?.progress ?? 0
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 8)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: isAcquired
                                            ? [goldColor.opacity(0.8), goldColor]
                                            : [badgeColor.opacity(0.7), badgeColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progressVal, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                
                // 完成状态提示
                if viewModel.detail?.acquired == true {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(goldColor)
                        Text("achievement_task_completed")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(goldColor)
                    }
                }
            }
            
            // ─ 规则说明 ─
            if let rule = viewModel.detail?.ruleDetail {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                
                VStack(alignment: .leading, spacing: 16) {
                    // 如何获得
                    if let how = rule.howToObtain {
                        ruleRow(icon: "lightbulb.fill", title: "如何获得", value: how, color: .yellow)
                    }
                    
                    // 获得条件
                    if let conditions = rule.conditions, !conditions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("cond_label", systemImage: "checklist")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.4))
                            
                            if let relation = rule.relation {
                                HStack(spacing: 4) {
                                    Text(NSLocalizedString("need_label", comment: ""))
                                        .foregroundColor(.white.opacity(0.5))
                                    Text(relation == "or" ? NSLocalizedString("any_met", comment: "") : "全部满足")
                                        .foregroundColor(relation == "or" ? .orange : badgeColor)
                                        .fontWeight(.bold)
                                    Text(NSLocalizedString("conditions_below", comment: ""))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .font(.system(size: 13, design: .rounded))
                            }
                            
                            ForEach(conditions) { cond in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(badgeColor.opacity(0.6))
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 6)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(cond.name ?? "")
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundColor(.white.opacity(0.9))
                                            Spacer()
                                            Text("≥ \(cond.target ?? "")")
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(badgeColor)
                                        }
                                        if let method = cond.method {
                                            Text(method)
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.45))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // 预计用时
                    if let time = rule.estimatedTime {
                        ruleRow(icon: "clock.fill", title: "预计用时", value: time, color: .cyan)
                    }
                    
                    // 获得方式
                    if let method = rule.obtainMethod {
                        ruleRow(icon: "gear.badge.checkmark", title: "获得方式", value: method, color: .mint)
                    }
                    
                    // 获得难度
                    if let difficulty = rule.difficulty {
                        HStack {
                            Label("difficulty_label", systemImage: "flame.fill")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.4))
                            Spacer()
                            HStack(spacing: 3) {
                                ForEach(1...5, id: \.self) { i in
                                    Image(systemName: i <= difficulty ? "star.fill" : "star")
                                        .font(.system(size: 12))
                                        .foregroundColor(i <= difficulty ? .orange : .white.opacity(0.15))
                                }
                            }
                        }
                    }
                    
                    // 奖励机制
                    if let rewards = rule.rewards, !rewards.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("reward_label", systemImage: "gift.fill")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.4))
                            
                            HStack(spacing: 8) {
                                ForEach(rewards, id: \.self) { reward in
                                    Text(reward)
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.85))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            Capsule()
                                                .fill(goldColor.opacity(0.15))
                                                .overlay(Capsule().stroke(goldColor.opacity(0.25), lineWidth: 0.5))
                                        )
                                }
                            }
                        }
                    }
                }
            }
            
            // ─ 获得时间 ─
            if let acquireTime = viewModel.detail?.acquireTime,
               viewModel.detail?.acquired == true {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                
                HStack {
                    Label("achievement_acquired_at", systemImage: "calendar.badge.checkmark")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Text(acquireTime)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
        .opacity(showCard ? 1 : 0)
        .offset(y: showCard ? 0 : 40)
    }
    
    // MARK: - 规则行辅助视图
    @ViewBuilder
    private func ruleRow(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
            
            Text(value)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
