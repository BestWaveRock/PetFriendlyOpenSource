
import SwiftUI

struct NearbyPlacesView: View {
    @State private var selectedTab: Int = 0
    @Namespace private var pageTransition
    @EnvironmentObject var uiState: UIState

    var body: some View {
        ZStack(alignment: .bottom) {
            // 内容区域
            Group {
                switch selectedTab {
                case 0: MapAndListView()
                case 1: PetService()
                case 2: Pets()
                case 3: PersonView()
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 自定义 TabBar
            // if !uiState.isTabBarHidden {
            //     customTabBar
            //         .transition(.move(edge: .bottom).combined(with: .opacity))
            //         .padding(.bottom, 10)
            //         .zIndex(100)
            // }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .ignoresSafeArea(edges: .top)
        .background(PFColors.background)
    }
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabItem(index: 0, title: NSLocalizedString("map_tab_map", comment: ""), icon: "map")
            tabItem(index: 1, title: NSLocalizedString("map_tab_service", comment: ""), icon: "heart.text.square")
            tabItem(index: 2, title: NSLocalizedString("map_tab_pets", comment: ""), icon: "pawprint")
            tabItem(index: 3, title: NSLocalizedString("map_tab_me", comment: ""), icon: "person")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 20)
    }
    
    private func tabItem(index: Int, title: String, icon: String) -> some View {
        let isSelected = selectedTab == index
        return Button(action: {
            withAnimation(PFAnimation.spring) {
                selectedTab = index
            }
            Haptics.play(.light)
        }) {
            VStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "\(icon).fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(PFGradients.brand)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(PFColors.textTertiary)
                }
                
                Text(LocalizedStringKey(title))
                    .font(PFFonts.caption2)
                    .foregroundColor(isSelected ? PFColors.primary : PFColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        PFGradients.brand.opacity(0.1)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 4)
                    } else {
                        EmptyView()
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 场所卡片（美化版）
struct PlaceCardView: View {
    let place: PetFriendlyPlace
    let onTapCard: () -> Void
    var onDetailTap: (() -> Void)? = nil
    @State private var isFavorite: Bool
    @State private var isFavLoading = false
    
    init(place: PetFriendlyPlace, onTapCard: @escaping () -> Void, onDetailTap: (() -> Void)? = nil) {
        self.place = place
        self.onTapCard = onTapCard
        self.onDetailTap = onDetailTap
        self._isFavorite = State(initialValue: place.favoriteId != nil && place.favoriteId != 0)
    }

    var body: some View {
        cardContent
    }
    
    private var cardContent: some View {
            HStack(alignment: .top, spacing: PFSpacing.md) {
                VStack(alignment: .leading, spacing: 6) {
                    // 标题行: 类型icon + 场所名称 + 感叹号(低友好度)
                    HStack(spacing: 6) {
                        // 类型小图标
                        Image(systemName: place.iconName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(place.iconColor)
                            .clipShape(Circle())
                        
                        Text(place.name)
                            .font(PFFonts.headline)
                            .foregroundColor(PFColors.textPrimary)
                            .lineLimit(1)
                        
                        // 友好度 == 4 (不友好) 时展示感叹号警告
                        if let level = place.placeLevel, level == 4 {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(PFColors.danger)
                        }
                    }
                    
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .foregroundColor(PFColors.warning)
                                .font(.system(size: 11))
                            Text(place.ratingText)
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.textSecondary)
                        }
                        
                        Text("·")
                            .foregroundColor(PFColors.textTertiary)
                        
                        Text(place.distanceText)
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.textSecondary)
                        
                        if let reviews = place.evaluateVoList, !reviews.isEmpty {
                            Text("·")
                                .foregroundColor(PFColors.textTertiary)
                            Text(String(format: NSLocalizedString("map_reviews_count", comment: ""), reviews.count))
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.textSecondary)
                        }
                    }
                    
                    if let _ = place.type {
                        HStack(spacing: 4) {
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 10))
                            Text(place.friendlyLevelText)
                                .font(PFFonts.caption)
                        }
                        .foregroundColor(place.friendlyLevelColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(place.friendlyLevelColor.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                // 场所图片 (圆角矩形，仅有图片时展示)
                if let firstImage = place.images?.first,
                   let imageUrl = URL(string: firstImage) {
                    CachedAsyncImage(url: imageUrl) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(PFColors.surfaceSecondary)
                            PFPetLoadingInline(size: 14)
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .pfImageInteractable(url: firstImage)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                }
                
                // 右侧操作列: 详情 + 收藏
                VStack(spacing: 8) {
                    // 查看详情按钮
                    if let detailAction = onDetailTap {
                        Button(action: detailAction) {
                            HStack(spacing: 2) {
                                Text("map_details")
                                    .font(.system(size: 11, weight: .medium))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(PFColors.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(PFColors.primary.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // 收藏按钮
                    Button(action: toggleFavorite) {
                        Group {
                            if isFavLoading {
                                PFPetLoadingInline(size: 14)
                                    .padding(8)
                            } else {
                                Image(systemName: isFavorite ? "heart.fill" : "heart")
                                    .font(.system(size: 14))
                                    .foregroundColor(isFavorite ? .white : PFColors.textTertiary)
                                    .padding(8)
                            }
                        }
                        .background(
                            Circle()
                                .fill(isFavorite ? PFColors.danger : PFColors.surfaceSecondary)
                        )
                        .shadow(color: isFavorite ? PFColors.danger.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isFavLoading)
                }
            }
            .padding(.horizontal, PFSpacing.lg)
            .padding(.vertical, PFSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: PFRadius.md)
                    .fill(PFColors.surface)
            )
            .pfCardShadow()
            .contentShape(Rectangle())
            .onTapGesture {
                print("📍 [PlaceCard Tap] name=\(place.name), lat=\(place.latitude), lng=\(place.longitude), placeId=\(place.placeId ?? 0)")
                onTapCard()
            }
            .onReceive(NotificationCenter.default.publisher(for: .PFPlaceFavoriteChanged)) { note in
                guard let userInfo = note.userInfo,
                      let pid = userInfo["placeId"] as? Int64,
                      pid == place.placeId,
                      let isFav = userInfo["isFavorite"] as? Bool else { return }
                self.isFavorite = isFav
            }
    }
    
    func toggleFavorite() {
        guard !isFavLoading else { return }
        isFavLoading = true
        Task {
            guard let pid = place.placeId else { return }
            let fid = place.favoriteId
            do {
                var url = "/petFriendly/client/collectPlaces?placeId=\(pid)"
                if isFavorite, let f = fid, f != 0 { url += "&favoritesId=\(f)" }
                let _: BoolResp = try await NetworkManager.shared.request(url, method: .get)
                await MainActor.run { 
                    self.isFavorite.toggle()
                    self.isFavLoading = false
                    // 发送全局通知，同步详情页和其他列表项
                    NotificationCenter.default.post(name: .PFPlaceFavoriteChanged, object: nil, userInfo: [
                        "placeId": pid,
                        "isFavorite": self.isFavorite
                    ])
                }
            } catch {
                await MainActor.run { self.isFavLoading = false }
                print("Fav error: \(error)")
            }
        }
    }
}
