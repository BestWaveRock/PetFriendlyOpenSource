//
//  RootView.swift
//  PetFriendly
//
//  Runtime locale switching wrapper for MainTabView.
//

import SwiftUI

/// 根视图：负责将用户选择的语言注入 SwiftUI 环境，
/// 使所有后代视图自动响应语言切换。
struct RootView: View {
    @ObservedObject private var accountStore = AccountStore.shared

    var body: some View {
        MainTabView()
            .environment(\.locale, accountStore.settings.locale)
            .id(accountStore.settings.language) // 强制刷新整棵视图树
    }
}
