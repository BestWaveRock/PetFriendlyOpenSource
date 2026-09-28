//
//  MainTabView.swift
//  PetFriendly
//
//  使用原生 SwiftUI TabView 构建底部标签栏，保持系统默认样式与交互。
//

import SwiftUI
import UIKit

// MARK: - 选项卡定义

enum TabItem: Int, CaseIterable {
    case map = 0
    case services
    case pets
    case profile

    var title: String {
        switch self {
        case .map:      return NSLocalizedString("tab_map", comment: "")
        case .services: return NSLocalizedString("tab_services", comment: "")
        case .pets:     return NSLocalizedString("tab_pets", comment: "")
        case .profile:  return NSLocalizedString("tab_me", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .map:      return "map.fill"
        case .services: return "heart.text.square.fill"
        case .pets:     return "pawprint.fill"
        case .profile:  return "person.fill"
        }
    }
}

// MARK: - MainTabView

struct MainTabView: View {
    @EnvironmentObject private var uiState: UIState
    @EnvironmentObject private var mapVM: MapViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var petVM: PetViewModel
    @StateObject private var appUpdater = AppUpdater.shared

    init() {
        // iOS 18 在地图等全屏内容下会默认使用透明的 scroll-edge TabBar，
        // 且首次渲染不会切换到 standardAppearance。两种状态统一后，启动即有稳定背景。
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.88)
        appearance.shadowColor = UIColor.separator.withAlphaComponent(0.22)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $uiState.selectedTab) {

            NavigationStack { MapAndListView() }
                .pfTabBarHidden(uiState.isTabBarHidden)
                .tabItem {
                    Label(TabItem.map.title, systemImage: TabItem.map.icon)
                }
                .tag(TabItem.map.rawValue)

            PetService()
                .pfTabBarHidden(uiState.isTabBarHidden)
                .tabItem {
                    Label(TabItem.services.title, systemImage: TabItem.services.icon)
                }
                .tag(TabItem.services.rawValue)

            Pets()
                .pfTabBarHidden(uiState.isTabBarHidden)
                .tabItem {
                    Label(TabItem.pets.title, systemImage: TabItem.pets.icon)
                }
                .tag(TabItem.pets.rawValue)

            PersonView()
                .pfTabBarHidden(uiState.isTabBarHidden)
                .tabItem {
                    Label(TabItem.profile.title, systemImage: TabItem.profile.icon)
                }
                .tag(TabItem.profile.rawValue)
        }
        .tint(themeManager.dynamicColor)
        .toolbarBackground(.visible, for: .tabBar)


        .overlay(
            ZStack {
                // 上传进度遮罩
                if uiState.isUploading || uiState.isUploadFinished {
                    ZStack {
                        Color.black.opacity(0.15)
                            .ignoresSafeArea()

                        CircularUploadProgressView(
                            progress: uiState.uploadProgress,
                            isFinished: uiState.isUploadFinished
                        )
                    }
                    .transition(.opacity)
                    .zIndex(998)
                }

                // 帧率监控悬浮窗
                if uiState.showPerformanceFPS {
                    VStack {
                        HStack {
                            Spacer()
                            PerformanceOverlayView()
                                .padding(.top, 50)
                                .padding(.trailing, 16)
                        }
                        Spacer()
                    }
                    .zIndex(1000)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(), value: uiState.showPerformanceFPS)
        )
        .onAppear {
            DispatchQueue.main.async {
                themeManager.refreshFromSettings()
                accountStore.checkDailyLogin()
                accountStore.syncWithServer()
                // 进入 App 时检测新版本（可设置关闭；稍后/忽略/立即更新；忽略的版本一直忽略）
                if accountStore.settings.checkUpdateOnLaunch {
                    AppUpdater.shared.checkOnLaunch()
                }
            }
        }
        // 新版本弹窗：fullScreenCover 承载，同时包含「版本更新」与「彩蛋领取」，
        // 领取彩蛋时显示加载动画、等接口响应完毕后关闭弹窗
        .fullScreenCover(isPresented: Binding(
            get: { appUpdater.activeAlert != nil },
            set: { if !$0 { appUpdater.activeAlert = nil; appUpdater.isClaiming = false } }
        )) {
            AppUpdateDialogView(appUpdater: appUpdater)
        }
        .fullScreenCover(isPresented: $uiState.showGlobalLogin) {
            LoginPage()
                .environmentObject(accountStore)
        }
        .onChange(of: uiState.pendingMapFilter) { newValue in
            guard let filterName = newValue else { return }

            DispatchQueue.main.async {
                withAnimation(.spring()) {
                    uiState.selectedTab = TabItem.map.rawValue
                }
                mapVM.selectedCategory = filterName
                if let radius = uiState.pendingMapRadius {
                    mapVM.searchRadius = radius
                }
                uiState.pendingMapFilter = nil
                uiState.pendingMapRadius = nil
            }
        }
    }
}

// MARK: - TabBar 显隐

extension View {
    func pfTabBarHidden(_ hidden: Bool) -> some View {
        toolbar(hidden ? .hidden : .visible, for: .tabBar)
    }
}

// MARK: - Preview


struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AccountStore.shared)
            .environmentObject(ThemeManager.shared)
            .environmentObject(UIState.shared)
            .environmentObject(PetViewModel.shared)
    }
}
