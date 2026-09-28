//
//  NotificationsView.swift
//  PetFriendly
//
//  Created by PetFriendly Team.
//

import SwiftUI

// MARK: - API 模型
struct NotificationResp: Decodable {
    let code: Int
    let msg: String?
    let rows: [NotificationRow]
}

struct NotificationRow: Identifiable, Decodable {
    @Int64String var id: Int64?
    let title: String?
    let content: String?
    let createTime: String?
    var isRead: Bool?
    let type: String? // e.g. "system", "activity", "alert"
}

// MARK: - 视图模型
@MainActor
class NotificationsViewModel: ObservableObject {
    @Published var dataList: [NotificationRow] = []
    @Published var isLoading = false
    @Published var isLoadMore = false
    @Published var hasMore = true
    
    private var pageNum = 1
    private let pageSize = 15
    
    func refreshData() async {
        pageNum = 1
        hasMore = true
        isLoading = true
        let result = await fetchPage()
        
        dataList = result
        if result.count < pageSize { hasMore = false }
        isLoading = false
    }
    
    func loadMore() async {
        guard !isLoadMore, hasMore else { return }
        isLoadMore = true
        pageNum += 1
        
        let result = await fetchPage()
        if result.isEmpty {
            hasMore = false
        } else {
            dataList.append(contentsOf: result)
            if result.count < pageSize { hasMore = false }
        }
        isLoadMore = false
    }
    
    private func fetchPage() async -> [NotificationRow] {
        let path = "/petFriendly/client/notifications"
        let params: [String: Any] = [
            "pageNum": pageNum,
            "pageSize": pageSize
        ]
        
        do {
            let resp: NotificationResp = try await NetworkManager.shared.request(
                path,
                method: .get,
                parameters: params,
                needToken: true
            )
            if resp.code == 200 {
                return resp.rows
            }
        } catch {
            UIState.shared.showToast(error.localizedDescription, style: .error)
        }
        
        return []
    }
    
    func markAsRead(id: Int64) async {
        // 公告为全局内容，已读状态保存在本机，不修改服务端公告。
        if let idx = dataList.firstIndex(where: { $0.id == id }) {
            dataList[idx].isRead = true
        }
    }
}

// MARK: - 视图展示
struct NotificationsView: View {
    @StateObject private var viewModel = NotificationsViewModel()
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.dataList.isEmpty {
                PFPetLoadingView("notifications_loading", size: 36)
            } else if !viewModel.isLoading && viewModel.dataList.isEmpty {
                emptyView
            } else {
                List {
                    ForEach(viewModel.dataList) { item in
                        notificationCell(item)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(PFColors.surface)
                            .listRowSeparator(.hidden)
                            .onAppear {
                                if item.id == viewModel.dataList.last?.id {
                                    Task { await viewModel.loadMore() }
                                }
                            }
                            .onTapGesture {
                                if item.isRead != true {
                                    Task { await viewModel.markAsRead(id: item.id ?? 0) }
                                }
                            }
                    }
                    
                    if viewModel.isLoadMore {
                        HStack {
                            Spacer()
                            PFPetLoadingInline(size: 18)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else if !viewModel.hasMore && !viewModel.dataList.isEmpty {
                        Text("notifications_no_more")
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await viewModel.refreshData()
                }
            }
        }
        .navigationTitle("notifications_title")
        .navigationBarTitleDisplayMode(.inline)
        .pfToyBackground()
        .onAppear {
            if viewModel.dataList.isEmpty {
                Task { await viewModel.refreshData() }
            }
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: PFSpacing.lg) {
            Image(systemName: "bell.slash")
                .font(.system(size: 64))
                .foregroundColor(PFColors.textTertiary.opacity(0.5))
            
            Text("notifications_empty")
                .font(PFFonts.body)
                .foregroundColor(PFColors.textSecondary)
        }
        .padding(.top, 100)
    }
    
    private func notificationCell(_ item: NotificationRow) -> some View {
        HStack(alignment: .top, spacing: PFSpacing.md) {
            // 左侧状态指示器与图标
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(PFColors.accent.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: iconForType(item.type))
                            .foregroundColor(PFColors.accent)
                            .font(.system(size: 20))
                    )
                
                if item.isRead != true {
                    Circle()
                        .fill(PFColors.danger)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: 2, y: -2)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(item.title ?? NSLocalizedString("notifications_system_default", comment: ""))
                        .font(PFFonts.headline)
                        .foregroundColor(item.isRead == true ? PFColors.textSecondary : PFColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                    
                    Text(item.createTime ?? "")
                        .font(PFFonts.caption2)
                        .foregroundColor(PFColors.textTertiary)
                        .layoutPriority(1)
                }
                
                Text(item.content ?? "")
                    .font(PFFonts.body)
                    .foregroundColor(item.isRead == true ? PFColors.textTertiary : PFColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(PFSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PFRadius.md)
                .fill(PFColors.surface)
        )
        .padding(.horizontal, PFSpacing.lg)
        .padding(.vertical, PFSpacing.xs)
    }
    
    private func iconForType(_ type: String?) -> String {
        switch type {
        case "system": return "gearshape.fill"
        case "activity": return "star.fill"
        case "alert": return "exclamationmark.triangle.fill"
        default: return "bell.fill"
        }
    }
}
