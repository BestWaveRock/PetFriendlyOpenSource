//
//  PlaceDetail.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/10/15.
//
import SwiftUI
import MapKit

// MARK: - 详情页 (优化版)
struct PlaceDetailView: View {
    @State var place: PetFriendlyPlace
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isFavorite: Bool
    @State private var showAllReviews = false
    @State private var showEvaluateForm = false
    @State private var showLoginAlert = false
    @State private var showLoginSheet = false
    @State private var isLoggedIn = false
    @State private var isFavLoading = false
    @State private var isEvalLoading = false
    @State private var reportTarget: ContentReportTarget?
    
    // 用于 sheet(item:) 的包装
    struct UserIdWrapper: Identifiable {
        let id: Int64
    }
    @State private var selectedUserIdItem: UserIdWrapper? = nil
    
    init(place: PetFriendlyPlace) {
        self._place = State(initialValue: place)
        self._isFavorite = State(initialValue: place.favoriteId != nil && place.favoriteId != 0)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            PFColors.background.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // 1. 顶部图片 Banner
                    imageHeader
                    
                    VStack(spacing: PFSpacing.xl) {
                        // 2. 基础信息卡片
                        basicInfoSection
                        
                        // 3. 用户评价
                        reviewsSection
                        
                        // 4. 详细参数 (两栏) - 位置信息
                        detailStatsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, -20) // 向上叠加到图片之下
                    .padding(.bottom, 120) // 为底部按钮留空
                }
            }
            .ignoresSafeArea(edges: .top)
            
            // 顶部返回按钮
            headerOverlay
            
            // 底部导航按钮
            bottomActionBar
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showAllReviews) {
            AllReviewsView(reviews: place.evaluateVoList ?? [], selectedUserIdItem: $selectedUserIdItem)
        }
        .sheet(isPresented: $showEvaluateForm) {
            if let placeId = place.placeId {
                EvaluateFormView(placeId: placeId, onReviewSubmitted: {
                    Task { await loadPlaceDetail() }
                })
            }
        }
        .alert(isPresented: $showLoginAlert) {
            Alert(
                title: Text("map_login_required"),
                message: Text("map_eval_login_msg"),
                primaryButton: .default(Text("map_goto_login")) {
                    showLoginSheet = true
                },
                secondaryButton: .cancel(Text("map_got_it"))
            )
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginPage()
        }
        .sheet(item: $selectedUserIdItem) { item in
            UserNamecardView(userId: item.id)
        }
        .sheet(item: $reportTarget) { target in
            ContentReportView(target: target)
        }
        .onAppear {
            checkLogin()
        }
    }

    private func checkLogin() {
        isLoggedIn = NetworkManager.shared.token != nil
        if isLoggedIn {
            // Refresh user info in background (non-blocking)
            Task {
                if let info = try? await AuthService.shared.fetchUserInfo() {
                    await AuthService.shared.cache(info)
                }
                recordBrowse()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var imageHeader: some View {
        ZStack(alignment: .bottom) {
            TabView {
                if (place.images ?? []).isEmpty {
                    CachedAsyncImage(url: URL(string: Secrets.defaultBannerURL)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(PFColors.surfaceSecondary)
                            .overlay(PFPetLoadingInline(size: 14))
                    }
                } else {
                    ForEach(place.images ?? [], id: \.self) { imgUrl in
                        CachedAsyncImage(url: NetworkManager.fullUrl(imgUrl)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(PFColors.surfaceSecondary)
                                .overlay(PFPetLoadingInline(size: 14))
                        }
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .frame(height: 320)
            
            // 底部渐变，确保文字过渡自然
            LinearGradient(
                colors: [.clear, PFColors.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 60)
        }
    }
    
    private var headerOverlay: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(PFColors.textPrimary)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
            }
            Spacer()
            
            Button(action: sharePlace) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(PFColors.textPrimary)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
            }

            if NetworkManager.shared.token != nil {
                Button {
                    reportTarget = ContentReportTarget(
                        type: "place", targetId: place.placeId, targetUserId: place.reporterUserId)
                } label: {
                    Image(systemName: "exclamationmark.bubble")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(PFColors.danger)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .accessibilityLabel(Text("report_place_accessibility"))
            }
        }
        .padding(.top, 50)
        .padding(.horizontal, 20)
    }
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(place.name)
                    .font(PFFonts.largeTitle)
                    .foregroundColor(PFColors.textPrimary)
                
                Spacer()
                
                // 评分
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(PFColors.warning)
                        .font(.system(size: 14))
                    Text(place.ratingText)
                        .font(PFFonts.headline)
                        .foregroundColor(PFColors.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(PFColors.surfaceSecondary)
                .clipShape(Capsule())
            }
            
            HStack(spacing: 12) {
                PFTag(text: LocalizedStringKey(place.category), gradient: PFGradients.brand)
                
                HStack(spacing: 4) {
                    Image(systemName: "pawprint.fill")
                    Text(place.friendlyLevelText)
                }
                .font(PFFonts.caption)
                .foregroundColor(place.friendlyLevelColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(place.friendlyLevelColor.opacity(0.1))
                .clipShape(Capsule())
                
                Spacer()
                
                Text(place.distanceText)
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textSecondary)
            }
            
            // 上报人信息
            if let reporterId = place.reporterUserId, reporterId != 0 {
                Button(action: {
                    selectedUserIdItem = UserIdWrapper(id: reporterId)
                }) {
                    HStack(spacing: 8) {
                        if let avatar = place.reporterAvatar, !avatar.isEmpty {
                            CachedAsyncImage(url: NetworkManager.fullUrl(avatar)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(PFColors.surfaceSecondary)
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(PFColors.textTertiary)
                        }
                        
                        Text(String(format: NSLocalizedString("detail_reported_by", comment: ""), place.reporterName ?? "User"))
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.textSecondary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(PFColors.textTertiary)
                    }
                    .padding(10)
                    .background(PFColors.surfaceSecondary.opacity(0.5))
                    .cornerRadius(12)
                }
            }
            
            if let remark = place.remark, !remark.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("detail_intro")
                        .font(PFFonts.headline)
                        .foregroundColor(PFColors.textPrimary)
                    
                    Text(remark)
                        .font(PFFonts.body)
                        .foregroundColor(PFColors.textSecondary)
                        .lineSpacing(4)
                }
                .padding(.top, 8)
            }
        }
        .padding(PFSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(PFColors.surface)
                .pfCardShadow()
        )
    }
    
    private var detailStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("detail_location_info")
                .font(PFFonts.headline)
                .padding(.horizontal, 8)
            
            HStack(spacing: 12) {
                // 优化经纬度展示，添加可复制的手势反馈
                StatView(icon: "mappin.and.ellipse", title: NSLocalizedString("detail_longitude", comment: ""), value: String(format: "%.6f", place.longitude))
                    .onTapGesture {
                        UIPasteboard.general.string = String(format: "%.6f", place.longitude)
                        Haptics.play(.light)
                    }
                StatView(icon: "mappin.and.ellipse", title: NSLocalizedString("detail_latitude", comment: ""), value: String(format: "%.6f", place.latitude))
                    .onTapGesture {
                        UIPasteboard.general.string = String(format: "%.6f", place.latitude)
                        Haptics.play(.light)
                    }
            }
            Text("detail_copy_hint")
                .font(PFFonts.caption2)
                .foregroundColor(PFColors.textTertiary)
                .padding(.horizontal, 12)
        }
    }
    
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("detail_reviews")
                    .font(PFFonts.headline)
                Spacer()
                if !(place.evaluateVoList ?? []).isEmpty {
                    Button(action: { showAllReviews = true }) {
                        Text("detail_view_all")
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(PFColors.primary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 8)
            
            if (place.evaluateVoList ?? []).isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 32))
                            .foregroundColor(PFColors.textTertiary)
                        Text("detail_no_reviews")
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.textTertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, 30)
                .background(PFColors.surface)
                .cornerRadius(20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(place.evaluateVoList ?? []) { review in
                            ReviewCard(review: review, showAllReviews: $showAllReviews)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }
    
    private var bottomActionBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                // 收藏按钮
                Button(action: {
                    guard !isFavLoading else { return }
                    guard NetworkManager.shared.token != nil else {
                        showLoginAlert = true
                        return
                    }
                    toggleFavorite()
                }) {
                    Group {
                        if isFavLoading {
                            PFPetLoadingInline(size: 20)
                                .frame(width: 56, height: 56)
                        } else {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 20))
                                .foregroundColor(isFavorite ? .white : PFColors.textPrimary)
                                .frame(width: 56, height: 56)
                        }
                    }
                    .background(isFavorite ? PFColors.danger : PFColors.surface)
                    .clipShape(Circle())
                    .pfCardShadow()
                }
                .disabled(isFavLoading)
                
                // 导航按钮
                HStack(spacing: 12) {
                    // 评价按钮
                    Button(action: {
                        guard !isEvalLoading else { return }
                        guard NetworkManager.shared.token != nil else {
                            showLoginAlert = true
                            return
                        }
                        showEvaluateForm = true
                    }) {
                        HStack(spacing: 4) {
                            if isEvalLoading {
                                PFPetLoadingInline(size: 16)
                            } else {
                                Image(systemName: "square.and.pencil")
                            }
                            Text("detail_evaluate")
                                .font(PFFonts.headline)
                        }
                        .foregroundColor(PFColors.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(PFColors.primary.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .disabled(isEvalLoading)
                    
                    Button(action: {
                        place.mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                            Text("detail_navigate")
                                .font(PFFonts.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(PFGradients.brand)
                        .clipShape(Capsule())
                        .pfElevatedShadow()
                    }
                }
            }
            .padding(.horizontal, 20)
            // .padding(.bottom, 34)
            .padding(.top, 12)
            .background(
                PFColors.surface.opacity(0.8)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
            )
        }
    }
    
    private func toggleFavorite() {
        guard !isFavLoading else { return }
        isFavLoading = true
        Task {
            guard let pid = place.placeId else { return }
            do {
                var url = "/petFriendly/client/collectPlaces?placeId=\(pid)"
                if isFavorite, let fid = place.favoriteId, fid != 0 {
                    url += "&favoritesId=\(fid)"
                }
                let _: BoolResp = try await NetworkManager.shared.request(url, method: .get)
                await MainActor.run { 
                    self.isFavorite.toggle()
                    self.isFavLoading = false
                    Haptics.play(.medium)
                    
                    // 发送全局通知，同步地图列表
                    NotificationCenter.default.post(name: .PFPlaceFavoriteChanged, object: nil, userInfo: [
                        "placeId": pid,
                        "isFavorite": self.isFavorite
                    ])
                    
                    if self.isFavorite {
                        showSuccessHUD(message: NSLocalizedString("detail_fav_added", comment: ""))
                    } else {
                        showSuccessHUD(message: NSLocalizedString("detail_fav_removed", comment: ""))
                    }
                }
            } catch {
                await MainActor.run { self.isFavLoading = false }
                print("Fav error: \(error)")
            }
        }
    }
    
    private func sharePlace() {
        Haptics.play(.light)
        
        Task {
            var items: [Any] = []
            
            // 1. 文案内容
            let shareText = String(format: NSLocalizedString("share_template", comment: ""), place.name, place.category)
            items.append(shareText)
            
            // 2. 尝试抓取第一张图，这会极大提高小红书/微信等社交平台的推荐权重和预览效果
            if let firstImg = place.images?.first, let url = NetworkManager.fullUrl(firstImg) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        items.append(image)
                    }
                } catch {
                    print("分享图片下载失败: \(error)")
                }
            } else {
                // 如果场所没图，分享 App 的高清 Logo 确保权重和美观
                if let logoImage = UIImage(named: "PetLogo") {
                    items.append(logoImage)
                }
            }
            
            // 3. 在主线程弹出分享窗口
            await MainActor.run {
                let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
                
                if let topVC = UIApplication.shared.topMostViewController() {
                    // 如果是 iPad，需要设置 popoverPresentationController 避免崩溃
                    if let popover = activityVC.popoverPresentationController {
                        popover.sourceView = topVC.view
                        popover.sourceRect = CGRect(x: PFScreen.width / 2, y: PFScreen.height / 2, width: 0, height: 0)
                        popover.permittedArrowDirections = []
                    }
                    topVC.present(activityVC, animated: true)
                }
            }
        }
    }

    private func recordBrowse() {
        Task {
            guard let pid = place.placeId else { return }
            do {
                let url = "/petFriendly/client/behavior/browse?placeId=\(pid)"
                let _: BoolResp = try await NetworkManager.shared.request(url, method: .get)
            } catch {
                print("Browse record error: \(error)")
            }
        }
    }
    
    /// 提交评价后从服务端重新加载场所详情（含最新评价列表和评分）
    private func loadPlaceDetail() async {
        guard let pid = place.placeId else { return }
        do {
            struct PlaceDetailResp: Decodable {
                let code: Int
                let msg: String?
                let data: PetFriendlyPlace?
            }
            let resp: PlaceDetailResp = try await NetworkManager.shared.request(
                "/petFriendly/client/getPlaceDetail",
                method: .get,
                parameters: ["placeId": pid],
                showLoading: false
            )
            if let freshPlace = resp.data {
                await MainActor.run {
                    self.place = freshPlace
                    self.isFavorite = freshPlace.favoriteId != nil && freshPlace.favoriteId != 0
                }
            }
        } catch {
            print("loadPlaceDetail error: \(error)")
        }
    }
}

// MARK: - UIApplication Extension for Top ViewController
extension UIApplication {
    func topMostViewController() -> UIViewController? {
        guard let windowScene = connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        var topController = window.rootViewController
        while let presentedController = topController?.presentedViewController {
            topController = presentedController
        }
        return topController
    }
}

// MARK: - Components

private struct StatView: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(PFColors.primary)
                .frame(width: 36, height: 36)
                .background(PFColors.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textSecondary)
                Text(value)
                    .font(PFFonts.callout)
                    .foregroundColor(PFColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(PFColors.surface)
        .cornerRadius(16)
        .pfCardShadow()
    }
}

private struct ReviewCard: View {
    let review: EvaluateVo
    @Binding var showAllReviews: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    if let avatarStr = review.userAvatar, !avatarStr.isEmpty {
                        CachedAsyncImage(url: NetworkManager.fullUrl(avatarStr)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(PFColors.surfaceSecondary)
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(PFGradients.brand.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String((review.userName ?? "U").prefix(1)))
                                    .font(PFFonts.caption2)
                                    .foregroundColor(PFColors.primary)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(review.userName ?? NSLocalizedString("detail_anonymous", comment: ""))
                            .font(PFFonts.caption2)
                            .foregroundColor((review.userBanner?.isEmpty ?? true) ? PFColors.textPrimary : .white)
                        Text(review.createTime ?? "")
                            .font(.system(size: 9))
                            .foregroundColor((review.userBanner?.isEmpty ?? true) ? PFColors.textTertiary : .white.opacity(0.8))
                    }
                }
                .onTapGesture {
                    showAllReviews = true
                    Haptics.play(.light)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    ZStack {
                        if let banner = review.userBanner, !banner.isEmpty {
                            CachedAsyncImage(url: NetworkManager.fullUrl(banner)) { image in
                                image.resizable().scaledToFill()
                                    .overlay(Color.black.opacity(0.3))
                            } placeholder: {
                                Color.clear
                            }
                        }
                    }
                )
                .clipShape(Capsule())
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .foregroundColor(PFColors.warning)
                        .font(.system(size: 10))
                    Text(String(format: "%.1f", review.rate ?? 0))
                        .font(.system(size: 10, weight: .bold))
                }
            }
            
            Text(review.comments ?? NSLocalizedString("detail_no_comments", comment: ""))
                .font(PFFonts.caption)
                .foregroundColor(PFColors.textSecondary)
                .lineLimit(2)
                .lineSpacing(3)
                .onTapGesture {
                    showAllReviews = true
                    Haptics.play(.light)
                }
            
            // 评论附图
            if let pics = review.pictures, !pics.isEmpty {
                let urls = pics.components(separatedBy: ",")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(urls, id: \.self) { url in
                            CachedAsyncImage(url: NetworkManager.fullUrl(url)) { image in
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(6)
                            } placeholder: {
                                Rectangle().fill(PFColors.surfaceSecondary)
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(6)
                            }
                            .pfImageInteractable(url: url)
                        }
                    }
                }
            } else {
                // 无图时使用空占位保证所有卡片内容顶部对齐
                Color.clear
                    .frame(height: 0)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 240, height: 160)
        .background(PFColors.surface)
        .cornerRadius(16)
        .pfCardShadow()
    }
}

// MARK: - 所有评价列表
struct AllReviewsView: View {
    let reviews: [EvaluateVo]
    @Environment(\.dismiss) var dismiss
    @Binding var selectedUserIdItem: PlaceDetailView.UserIdWrapper?
    @State private var reportTarget: ContentReportTarget?
    
    var body: some View {
        NavigationStack {
            ZStack {
                PFColors.background.ignoresSafeArea()
                
                if reviews.isEmpty {
                    Text("detail_no_reviews")
                        .foregroundColor(PFColors.textTertiary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(reviews) { review in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        HStack(spacing: 12) {
                                            if let avatarStr = review.userAvatar, !avatarStr.isEmpty {
                                                CachedAsyncImage(url: NetworkManager.fullUrl(avatarStr)) { image in
                                                    image.resizable().scaledToFill()
                                                } placeholder: {
                                                    Circle().fill(PFColors.surfaceSecondary)
                                                }
                                                .frame(width: 40, height: 40)
                                                .clipShape(Circle())
                                            } else {
                                                Circle()
                                                    .fill(PFGradients.brand.opacity(0.2))
                                                    .frame(width: 40, height: 40)
                                                    .overlay(Text(String((review.userName ?? "U").prefix(1))).foregroundColor(PFColors.primary))
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(review.userName ?? NSLocalizedString("detail_anonymous", comment: ""))
                                                    .font(PFFonts.headline)
                                                    .foregroundColor((review.userBanner?.isEmpty ?? true) ? PFColors.textPrimary : .white)
                                                Text(review.createTime ?? "")
                                                    .font(PFFonts.caption)
                                                    .foregroundColor((review.userBanner?.isEmpty ?? true) ? PFColors.textSecondary : .white.opacity(0.8))
                                            }
                                        }
                                        .onTapGesture {
                                            if let uid = review.userId, uid != 0 {
                                                selectedUserIdItem = PlaceDetailView.UserIdWrapper(id: uid)
                                            } else {
                                                Haptics.play(.light)
                                                showSuccessHUD(message: NSLocalizedString("anonymous_hush", comment: ""))
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            ZStack {
                                                if let banner = review.userBanner, !banner.isEmpty {
                                                    CachedAsyncImage(url: NetworkManager.fullUrl(banner)) { image in
                                                        image.resizable().scaledToFill()
                                                            .overlay(Color.black.opacity(0.3))
                                                    } placeholder: {
                                                        Color.clear
                                                    }
                                                }
                                            }
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 2) {
                                            Image(systemName: "star.fill")
                                                .foregroundColor(PFColors.warning)
                                            Text(String(format: "%.1f", review.rate ?? 0))
                                                .font(PFFonts.headline)
                                        }

                                        if NetworkManager.shared.token != nil {
                                            Menu {
                                                Button(role: .destructive) {
                                                    reportTarget = ContentReportTarget(
                                                        type: "review",
                                                        targetId: review.evaluateId,
                                                        targetUserId: review.userId)
                                                } label: {
                                                    Label("report_review", systemImage: "exclamationmark.bubble")
                                                }
                                            } label: {
                                                Image(systemName: "ellipsis")
                                                    .foregroundColor(PFColors.textSecondary)
                                                    .padding(8)
                                            }
                                        }
                                    }
                                    
                                    Text(review.comments ?? NSLocalizedString("detail_no_content", comment: ""))
                                        .font(PFFonts.body)
                                        .foregroundColor(PFColors.textPrimary)
                                        .lineSpacing(4)
                                    
                                    // 详情页展示大图
                                    if let pics = review.pictures, !pics.isEmpty {
                                        let urls = pics.components(separatedBy: ",")
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 12) {
                                                ForEach(urls, id: \.self) { url in
                                                    CachedAsyncImage(url: NetworkManager.fullUrl(url)) { image in
                                                        image.resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                            .frame(width: 120, height: 120)
                                                            .cornerRadius(12)
                                                    } placeholder: {
                                                        Rectangle().fill(PFColors.surfaceSecondary)
                                                            .frame(width: 120, height: 120)
                                                            .cornerRadius(12)
                                                    }
                                                    .pfImageInteractable(url: url)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(16)
                                .background(PFColors.surface)
                                .cornerRadius(20)
                                .pfCardShadow()
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("detail_all_reviews")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common_close") { dismiss() }
                }
            }
            .sheet(item: $selectedUserIdItem) { item in
                UserNamecardView(userId: item.id)
            }
            .sheet(item: $reportTarget) { target in
                ContentReportView(target: target)
            }
        }
    }
}
