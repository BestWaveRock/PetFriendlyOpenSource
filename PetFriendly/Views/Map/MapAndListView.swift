
import SwiftUI
import MapKit
import SafariServices

struct MapAndListView: View {
    static let shared = MapAndListView()
    @EnvironmentObject private var vm: MapViewModel
    @EnvironmentObject private var uiState: UIState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var accountStore: AccountStore
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var nearbyFriendsService = NearbyPetFriendsService.shared
    
    @State private var mapView: MKMapView?
    @State private var shouldZoomToFit = true
    
    // Sheet
    @State private var sheetOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false
    
    // Filter popup
    @State private var showFilterPopup = false
    
    // Sheets
    @State private var isReporting = false
    @State private var reportCoordinate: CLLocationCoordinate2D?
    @State private var showFeedback = false
    @State private var showTermsOfService = false
    @State private var showLoginAlert = false
    @State private var showLoginSheet = false
    @State private var loginAlertMessage = ""
    @State private var showNearbyFriends = false
    @State private var selectedNearbyFriend: NearbyFriend?
    
    private enum ActiveSheet: Identifiable, Equatable {
        case detail(PetFriendlyPlace)
        case filter
        case login
        case report(CLLocationCoordinate2D?)
        
        var id: String {
            switch self {
            case .detail(let place):
                return "detail-\(place.placeId ?? 0)"
            case .filter:
                return "filter"
            case .login:
                return "login"
            case .report(let coord):
                if let coord = coord {
                    return "report-\(coord.latitude)-\(coord.longitude)"
                } else {
                    return "report-none"
                }
            }
        }
        
        static func == (lhs: ActiveSheet, rhs: ActiveSheet) -> Bool {
            switch (lhs, rhs) {
            case (.detail(let lPlace), .detail(let rPlace)):
                return lPlace.id == rPlace.id
            case (.filter, .filter):
                return true
            case (.login, .login):
                return true
            case (.report(let lCoord), .report(let rCoord)):
                switch (lCoord, rCoord) {
                case (let l?, let r?):
                    return l.latitude == r.latitude && l.longitude == r.longitude
                case (nil, nil):
                    return true
                default:
                    return false
                }
            default:
                return false
            }
        }
    }
    @State private var activeSheet: ActiveSheet?
    
    // Right floating button group press state
    
    // Search
    @FocusState private var isSearchFocused: Bool
    @State private var localSearchText = ""
    
    // Screen dimensions — 使用 PFScreen 替代已弃用的 UIScreen.main
    private var screenHeight: CGFloat { PFScreen.height }
    private var screenWidth: CGFloat { PFScreen.width }
    
    // Sheet snap points (from top of screen)
    private var collapsedY: CGFloat { screenHeight - safeAreaBottom - 90 }
    private var halfY: CGFloat { screenHeight * 0.45 }
    private var fullY: CGFloat { safeAreaTop + 10 }
    
    private var safeAreaTop: CGFloat { PFScreen.safeAreaTop }
    private var safeAreaBottom: CGFloat { PFScreen.safeAreaBottom }

    
    var body: some View {
        ZStack(alignment: .top) {
            // 1. 全屏地图
            mapLayer
            
            // 2. 地图中心准星
            centerMarker
            
            // 3. 右侧浮动按钮组
            floatingButtonGroup
            
            // 4. 底部浮窗 — 暂时关闭调试菜单栏位置
            // bottomSheetView
            
            // 5. 左上角天气模块 (iOS 27+)
            weatherModule
            
            // 6. 地图数据重新加载动画（搜索/筛选/首次定位时）
            if vm.isLoading && vm.filteredPlaces.isEmpty {
                PFPetLoadingOverlay(text: "map_loading")
            }
        }
        .ignoresSafeArea(edges: .all)
        .alert(isPresented: $showLoginAlert) {
            Alert(
                title: Text("map_login_required"),
                message: Text(loginAlertMessage),
                primaryButton: .default(Text("map_goto_login")) {
                    showLoginSheet = true
                },
                secondaryButton: .cancel(Text("map_got_it"))
            )
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .detail(let place):
                PlaceDetailView(place: place)
            case .filter:
                MapFilterAndSearchView()
                    .environmentObject(vm)
                    .presentationDetentsIfAvailable()
            case .login:
                LoginPage()
            case .report(let coordinate):
                AddPlaceView(initialCoordinate: coordinate)
            }
        }
        .navigationDestination(isPresented: $showNearbyFriends) { NearbyFriendsHomeView() }
        .navigationDestination(
            isPresented: Binding(
                get: { selectedNearbyFriend != nil },
                set: { isPresented in
                    if !isPresented { selectedNearbyFriend = nil }
                }
            )
        ) {
            if let friend = selectedNearbyFriend {
                NearbyFriendNamecardView(friend: friend)
            }
        }
        .onChange(of: vm.selectedPlace) { newPlace in
            if let place = newPlace {
                activeSheet = .detail(place)
            } else if case .detail = activeSheet {
                activeSheet = nil
            }
        }
        .onChange(of: showFilterPopup) { show in
            if show {
                activeSheet = .filter
            } else if case .filter = activeSheet {
                activeSheet = nil
            }
        }
        .onChange(of: showLoginSheet) { show in
            if show {
                activeSheet = .login
            } else if case .login = activeSheet {
                activeSheet = nil
            }
        }
        .onChange(of: isReporting) { show in
            if show {
                activeSheet = .report(reportCoordinate)
            } else if case .report = activeSheet {
                activeSheet = nil
            }
        }
        .onChange(of: activeSheet) { newValue in
            if newValue == nil {
                vm.selectedPlace = nil
                showFilterPopup = false
                showLoginSheet = false
                isReporting = false
            }
        }
        .onAppear {
            localSearchText = vm.searchText
            Task { await nearbyFriendsService.loadSettings() }
        }
        .onChange(of: nearbyFriendsService.sharingEnabled) { enabled in
            if enabled { nearbyFriendsService.start() }
            else { nearbyFriendsService.stop() }
        }
        .trackScene("MapAndList")
    }
    
    // MARK: - 1. 全屏地图层
    private var mapLayer: some View {
        MapViewRepresentable(vm: vm,
                             nearbyFriends: nearbyFriendsService.sharingEnabled ? nearbyFriendsService.friends : [],
                             messagePreviews: nearbyFriendsService.messagePreviews,
                             shouldZoomToFit: $shouldZoomToFit,
                             onMapReady: { map in
                                DispatchQueue.main.async { mapView = map }
                             },
                             onSelectNearbyFriend: { selectedNearbyFriend = $0 },
onLongPress: { coordinate in
                                 guard NetworkManager.shared.token != nil else {
                                     loginAlertMessage = NSLocalizedString("map_report_login_msg", comment: "")
                                     showLoginAlert = true
                                     return
                                 }
                                 self.reportCoordinate = coordinate
                                 self.isReporting = true
                              })
            .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 2. 地图中心准星
    private var centerMarker: some View {
        let markerColor = colorScheme == .dark ? Color.white.opacity(0.8) : Color(.systemGray)
        
        return ZStack {
            Group {
                Rectangle()
                    .fill(markerColor.opacity(0.4))
                    .frame(width: 24, height: 1)
                Rectangle()
                    .fill(markerColor.opacity(0.4))
                    .frame(width: 1, height: 24)
            }
            Circle()
                .stroke(markerColor.opacity(0.5), lineWidth: 1.2)
                .frame(width: 12, height: 12)
            Circle()
                .fill(markerColor.opacity(0.8))
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 3. 右侧浮动按钮组
    private var floatingButtonGroup: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(spacing: 0) {
                    mapToolButton(icon: "person.2", activeIcon: "person.2.fill", isActive: nearbyFriendsService.sharingEnabled, activeColor: .green) {
                        if NetworkManager.shared.token != nil { showNearbyFriends = true } else { loginAlertMessage = NSLocalizedString("person_login_message", comment: ""); showLoginAlert = true }
                    }
                    separator
                    mapToolButton(
                        icon: "slider.horizontal.3",
                        isActive: showFilterPopup,
                        activeColor: themeManager.dynamicColor, // 🎨 设置-主题色
                        action: {
                            showFilterPopup = true
                            Haptics.play(.medium)
                        }
                    )
                    
                    separator
                    
                    mapToolButton(
                        icon: "heart",
                        activeIcon: "heart.fill",
                        isActive: vm.onlyLookFavorite,
                        activeColor: Color.red, // 🎨 收藏-红心 icon
                        action: {
                            Haptics.play(.light)
                            if NetworkManager.shared.token != nil {
                                vm.onlyLookFavorite.toggle()
                            } else {
                                loginAlertMessage = NSLocalizedString("person_login_message", comment: "")
                                showLoginAlert = true
                            }
                        }
                    )
                    
                    separator
                    
                    mapToolButton(
                        icon: "location",
                        activeIcon: "location.fill",
                        isActive: true, // 🎨 定位-实心常亮
                        activeColor: Color.primary, // 🎨 定位-黑色 icon
                        action: {
                            mapView?.setUserTrackingMode(.follow, animated: true)
                            Haptics.play(.medium)
                        }
                    )
                }
                .liquidFrostedGlass(cornerRadius: 12)
                .padding(.trailing, 16)
            }
            Spacer()
        }
        .padding(.top, safeAreaTop + 60)
    }
    
    private var separator: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.12))
            .frame(width: 22, height: 1)
    }

    
    private func mapToolButton(
        icon: String,
        activeIcon: String? = nil,
        isActive: Bool,
        activeColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                // 常态图标：空心/默认状态
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .opacity(isActive ? 0 : 1)
                    .scaleEffect(isActive ? 0.6 : 1.0)
                
                // 激活态图标：实心/高亮状态 (只改变 icon 前景色为指定颜色，不展示背景色)
                if let activeIcon = activeIcon {
                    Image(systemName: activeIcon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(activeColor)
                        .opacity(isActive ? 1 : 0)
                        .scaleEffect(isActive ? 1.0 : 0.6)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(activeColor)
                        .opacity(isActive ? 1 : 0)
                        .scaleEffect(isActive ? 1.0 : 0.6)
                }
            }
            .frame(width: 40, height: 40)
            .background(
                Color.clear // 🎨 彻底移除圆形高亮背景背景色
            )
            .animation(.easeInOut(duration: 0.22), value: isActive)
        }
        .buttonStyle(PFSimplePressButtonStyle())
    }


    
    // MARK: - 5. 左上角天气模块 (iOS 27+)
    private var weatherModule: some View {
        HStack {
            Button(action: {
                if let coord = vm.centerCoordinate {
                    vm.refreshWeather(at: coord)
                    Haptics.play(.light)
                }
            }) {
                HStack(spacing: 8) {
                    if vm.isLoadingWeather {
                        PFPetLoadingInline(size: 14)
                            .frame(width: 18, height: 18)
                    } else {
                        Image(systemName: vm.weatherSymbol)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.orange)
                            .symbolRenderingMode(.multicolor)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(vm.weatherTemp)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(PFColors.textPrimary)
                        Text(vm.weatherCondition)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .liquidFrostedGlass(cornerRadius: 12)
            }
            .buttonStyle(PFSimplePressButtonStyle())
            .padding(.leading, 16)
            
            Spacer()
        }
        .padding(.top, safeAreaTop + 12)
    }
    
    // MARK: - 4. 底部浮窗（内嵌自定义）

    /// 浮窗各档位距顶部的距离
    private var sheetCollapsedY: CGFloat { screenHeight - safeAreaBottom - 110 }
    private var sheetHalfY: CGFloat { screenHeight * 0.45 }
    private var sheetFullY: CGFloat { safeAreaTop + 10 }

    /// 浮窗当前顶部 Y 偏移（距屏幕顶部）
    private var currentSheetTopY: CGFloat {
        switch uiState.mapSheetDetent {
        case .collapsed: return sheetCollapsedY
        case .half:      return sheetHalfY
        case .full:      return sheetFullY
        }
    }

    private var bottomSheetView: some View {
        GeometryReader { geo in
            let sheetH = geo.size.height - safeAreaTop - 10
            VStack(spacing: 0) {
                // 顶部留白 — 替代 .offset(y:) 以正确限制命中测试区域
                Color.clear.frame(height: uiState.mapSheetTopY)

                // 实际弹窗内容
                VStack(spacing: 0) {
                    sheetHandle
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .updating($isDragging) { _, state, _ in
                                    state = true
                                }
                                .onChanged { value in
                                    let newY = uiState.mapSheetTopY + value.translation.height
                                    uiState.mapSheetTopY = min(max(newY, sheetFullY), sheetCollapsedY)
                                }
                                .onEnded { value in
                                    let velocity = value.predictedEndLocation.y - value.location.y
                                    let currentY = uiState.mapSheetTopY
                                    let midCollapsedHalf = (sheetCollapsedY + sheetHalfY) / 2
                                    let midHalfFull = (sheetHalfY + sheetFullY) / 2

                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        if velocity < -300 {
                                            if currentY < midHalfFull {
                                                uiState.mapSheetDetent = .full
                                                uiState.mapSheetTopY = sheetFullY
                                            } else {
                                                uiState.mapSheetDetent = .half
                                                uiState.mapSheetTopY = sheetHalfY
                                            }
                                        } else if velocity > 300 {
                                            if currentY > midCollapsedHalf {
                                                uiState.mapSheetDetent = .collapsed
                                                uiState.mapSheetTopY = sheetCollapsedY
                                            } else {
                                                uiState.mapSheetDetent = .half
                                                uiState.mapSheetTopY = sheetHalfY
                                            }
                                        } else {
                                            if currentY < midHalfFull {
                                                uiState.mapSheetDetent = .full
                                                uiState.mapSheetTopY = sheetFullY
                                            } else if currentY < midCollapsedHalf {
                                                uiState.mapSheetDetent = .half
                                                uiState.mapSheetTopY = sheetHalfY
                                            } else {
                                                uiState.mapSheetDetent = .collapsed
                                                uiState.mapSheetTopY = sheetCollapsedY
                                            }
                                        }
                                    }
                                }
                        )

                    persistentSheetContent
                        .frame(height: sheetH)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped() // 裁剪溢出 + 限制命中测试到可见区域
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: uiState.mapSheetTopY)
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var persistentSheetContent: some View {
        VStack(spacing: 0) {
            // 搜索行 (始终可见)
            searchRow
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)

            sheetContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedCorner(radius: 20, corners: [.topLeft, .topRight])
                .fill(isDragging ? Color(.systemBackground).opacity(0.6) : Color.clear)
                .background(
                    Group {
                        if !isDragging {
                            RoundedCorner(radius: 20, corners: [.topLeft, .topRight])
                                .fill(.ultraThinMaterial)
                                .transition(.opacity)
                        }
                    }
                )
        )
        .animation(.easeInOut(duration: 0.25), value: isDragging)
    }
    
    // MARK: - 拖拽手柄
    private var sheetHandle: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 搜索行
    private var searchRow: some View {
        HStack(spacing: 12) {
            // 搜索框
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 15))
                
                TextField("search_placeholder", text: $localSearchText)
                    .font(.system(size: 15))
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        vm.searchText = localSearchText
                        vm.addRecentSearch(localSearchText)
                        isSearchFocused = false
                        Haptics.play(.medium)
                    }
                
                if !localSearchText.isEmpty {
                    Button(action: {
                        localSearchText = ""
                        vm.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                }
                
                // 语音输入按钮
                Button(action: {
                    // 触发系统键盘的语音输入
                    isSearchFocused = true
                    Haptics.play(.light)
                }) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color(.systemGray6))
            )
            
            // 用户头像 / App 图标
            avatarButton
        }
    }
    
    // MARK: - 头像按钮
    private var avatarButton: some View {
        let userAvatarUrl = accountStore.petOwner?.petAvatar ?? accountStore.user?.avatar
        
        return Button(action: {
            if accountStore.user != nil {
                uiState.selectedTab = 3 // 跳转到个人页
            } else {
                showLoginSheet = true
            }
            Haptics.play(.light)
        }) {
            Group {
                if let urlString = userAvatarUrl, let url = NetworkManager.fullUrl(urlString) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundColor(Color.secondary.opacity(0.5))
                    }
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundColor(Color.secondary.opacity(0.5))
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
        }
    }
    
    // MARK: - 浮窗主体内容
    private var sheetContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 20) {
                
                // 1. 指南建议
                if let suggestion = vm.guideSuggestion {
                    guideSuggestionCard(place: suggestion)
                }
                
                // 2. 地点列表
                placesSection
                
                // 3. 最近搜索
                if !vm.recentSearches.isEmpty {
                    recentSearchesSection
                }
                
                // 4. 最近收藏
                if let fav = vm.recentFavorite {
                    recentFavoriteSection(place: fav)
                }
                
                // 5. 操作按钮
                actionButtons
                
                // 6. 服务条款
                termsButton
                
                // 底部留白
                Spacer().frame(height: safeAreaBottom + 100)
            }
            .padding(.horizontal, 16)
        }
        .modifier(ScrollBounceModifier())
    }
    
    // MARK: - 指南建议卡片
    private func guideSuggestionCard(place: PetFriendlyPlace) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
                Text("map_guide_suggestion")
                    .font(PFFonts.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                vm.focusUpperHalf(on: place)
                Haptics.play(.medium)
            }) {
                HStack(spacing: 12) {
                    Image(systemName: place.iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(place.iconColor)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(place.name)
                            .font(PFFonts.headline)
                            .foregroundColor(PFColors.textPrimary)
                            .lineLimit(1)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Text(place.ratingText)
                                .font(PFFonts.caption)
                                .foregroundColor(.secondary)
                            Text("·")
                                .foregroundColor(.secondary)
                            Text(place.distanceText)
                                .font(PFFonts.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - 地点列表
    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("map_friendly_places")
                    .font(PFFonts.headline)
                    .foregroundColor(PFColors.textPrimary)
                Spacer()
                if vm.totalPlaces > 0 {
                    Text(String(format: NSLocalizedString("map_destinations_count %lld", comment: ""), vm.totalPlaces))
                        .font(PFFonts.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if vm.isLoading && vm.filteredPlaces.isEmpty {
                HStack {
                    Spacer()
                    PFPetLoadingView("map_loading", size: 36)
                        .padding(.vertical, 40)
                    Spacer()
                }
            } else if vm.filteredPlaces.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                        Text("map_no_results")
                            .font(PFFonts.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 30)
                    Spacer()
                }
            } else {
                ZStack {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(vm.filteredPlaces) { place in
                            PlaceCardView(place: place, onTapCard: {
                                vm.focusUpperHalf(on: place)
                            }, onDetailTap: {
                                vm.selectedPlace = place
                            })
                            .onAppear {
                                if place.id == vm.filteredPlaces.last?.id {
                                    vm.loadNextPage()
                                }
                            }
                        }
                        
                        if vm.isLoadingMore {
                            HStack(spacing: 10) {
                                PFPetLoadingInline(size: 14)
                                Text("map_loading")
                                    .font(PFFonts.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                    }
                    .opacity(vm.isLoading && !vm.filteredPlaces.isEmpty ? 0.4 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: vm.isLoading)
                    
                    if vm.isLoading && !vm.filteredPlaces.isEmpty {
                        VStack(spacing: 8) {
                            PFPetLoadingInline(size: 18)
                            Text("map_loading")
                                .font(PFFonts.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }
            }
        }
    }
    
    // MARK: - 最近搜索
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("map_recent_searches")
                .font(PFFonts.caption)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.recentSearches, id: \.self) { term in
                        Button(action: {
                            localSearchText = term
                            vm.searchText = term
                            Haptics.play(.light)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text(term)
                                    .font(PFFonts.caption)
                            }
                            .foregroundColor(PFColors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color(.systemGray6))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
    
    // MARK: - 最近收藏
    private func recentFavoriteSection(place: PetFriendlyPlace) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("map_recent_favorite")
                .font(PFFonts.caption)
                .foregroundColor(.secondary)
            
            Button(action: {
                vm.focusUpperHalf(on: place)
                Haptics.play(.medium)
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundColor(PFColors.danger)
                    Text(place.name)
                        .font(PFFonts.body)
                        .foregroundColor(PFColors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(place.distanceText)
                        .font(PFFonts.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color(.systemBackground))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - 操作按钮
    private var actionButtons: some View {
        VStack(spacing: 0) {
            // 分享 / 标记我的位置
            Button(action: {
                let visualCenterPoint = CGPoint(
                    x: mapView?.bounds.midX ?? 0,
                    y: mapView?.bounds.midY ?? 0
                )
                let currentCoord = mapView?.convert(visualCenterPoint, toCoordinateFrom: mapView)
                    ?? vm.centerCoordinate
                
                guard NetworkManager.shared.token != nil else {
                    loginAlertMessage = NSLocalizedString("map_report_login_msg", comment: "")
                    showLoginAlert = true
                    return
                }
                self.reportCoordinate = currentCoord
                isReporting = true
                
                Haptics.play(.light)
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .frame(width: 28)
                    Text("map_share_report")
                        .font(PFFonts.body)
                        .foregroundColor(PFColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }
            .buttonStyle(PlainButtonStyle())
            
            Divider().padding(.leading, 56)
            
            // 报告问题
            Button(action: {
                showFeedback = true
                Haptics.play(.light)
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.bubble")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .frame(width: 28)
                    Text("map_report_problem")
                        .font(PFFonts.body)
                        .foregroundColor(PFColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color(.systemBackground))
        )
    }
    
    // MARK: - 服务条款
    private var termsButton: some View {
        HStack {
            Spacer()
            Button(action: {
                showTermsOfService = true
                Haptics.play(.light)
            }) {
                Text("map_terms_of_service")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - SafariWebView (内部浏览器)
