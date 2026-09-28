//
//  SceneDelegate.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/8/15.
//

import UIKit
import SwiftUI

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var islandWindow: UIWindow?   // 持有，防止被释放

    func sceneDidEnterBackground(_ scene: UIScene) {
        NearbyPetFriendsService.shared.stop()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        NearbyPetFriendsService.shared.stop()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        NearbyPetFriendsService.shared.start()
    }

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // 1. 包装根 SwiftUI 视图并注入 AccountStore
        let main = RootView()
            .environmentObject(AccountStore.shared)   // ✅ 正确注入
            .environmentObject(ThemeManager.shared)    // ✅ 主题色管理器
            .environmentObject(UIState.shared)        // ✅ 注入滚动状态管理
            .environmentObject(PetViewModel.shared)    // ✅ 萌宠数据管理
            .environmentObject(MapViewModel.shared)    // ✅ 地图数据管理
        
        let controller = UIHostingController(rootView: main)
        
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = controller
        window?.makeKeyAndVisible()

        // 2. 灵动岛/刘海浮层
        setupIslandBadge(for: windowScene)
    }

    // MARK: - 精准盖在刘海/岛体区域
    private func setupIslandBadge(for windowScene: UIWindowScene) {
        let islandVC = UIHostingController(rootView: IslandBadgeView())
        islandVC.view.backgroundColor = .clear   // 必须透明

        let islandWindow = PassThroughWindow(windowScene: windowScene)
        islandWindow.rootViewController = islandVC
        islandWindow.windowLevel = .statusBar + 1
        islandWindow.isHidden = false
        self.islandWindow = islandWindow
    }
}

// MARK: - 绿色圆形 + 白色加粗文字
private struct IslandBadgeView: View {
    @State private var isVisible = true

    var body: some View {
        Color.clear          // 撑满整个窗口，透明
            .overlay(        // 把绿色徽章精准放在刘海区
                    Text(NSLocalizedString("island_badge_title", comment: ""))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(hex: "22c55e"))
                    )
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                    .padding(.all, 6)   // ✅ 外边距：上下左右各 6 pt
                    .alignmentGuide(VerticalAlignment.top) { _ in 45 }
                , alignment: .top
            )
            // ⬇️ 任务栏渐隐：进入 inactive/background 时隐藏，回到前台时显示
            .opacity(isVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: isVisible)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    isVisible = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - 不拦截事件的透明窗口
private final class PassThroughWindow: UIWindow {
    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        print("页面点击")
        let hitView = super.hitTest(point, with: event)
        
        print("hitView = \(hitView == rootViewController?.view)")
        // 如果 hit 的是根 VC 的 view（即透明背景），就放弃，让事件继续向下传递
        if hitView == rootViewController?.view {
            return nil
        }
        print("正常响应 \(hitView)")
        // 否则（按钮、Label、Capsule...）正常响应
        return hitView
    }
}
