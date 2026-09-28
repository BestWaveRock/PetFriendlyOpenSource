import SwiftUI

// MARK: - 积分兑换记录模型
struct MallOrder: Codable, Identifiable {
    /// 稳定唯一标识：优先 ownerAssetsRecordId，否则用 createTime+commodityTitle 的 hash
    var id: String {
        if let rid = ownerAssetsRecordId, rid != 0 { return String(rid) }
        var hasher = Hasher()
        hasher.combine(createTime)
        hasher.combine(commodityTitle)
        hasher.combine(changeValue)
        return "mo_\(hasher.finalize())"
    }
    @Int64String var ownerAssetsRecordId: Int64?
    let changeType: Int?
    let changeValue: String?
    let commodityTitle: String?
    let commodityValue: String?
    let commodityImg: String?
    let phoneInformation: String?
    let status: Int?
    let createTime: String?
    let remark: String?

    var isRedemption: Bool {
        guard let ct = changeType, ct == 2 else { return false }
        return commodityTitle != nil && !(commodityTitle?.isEmpty ?? true)
    }

    var pointsText: String {
        let val = Double(changeValue ?? "0") ?? 0
        if val.truncatingRemainder(dividingBy: 1) == 0 {
            return "-\(Int(val))"
        }
        return String(format: "-%.1f", val)
    }

    var displayTitle: String {
        commodityTitle ?? remark ?? NSLocalizedString("person_no_nickname", comment: "")
    }
}

struct MallOrderResponse: Codable {
    let code: Int
    let msg: String?
    let rows: [MallOrder]?
    let total: Int?
}

// MARK: - ViewModel
@MainActor
final class ExchangeRecordViewModel: ObservableObject {
    @Published var orders: [MallOrder] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var errorMessage: String?

    private var pageNum = 1
    private let pageSize = 20
    private var isFetching = false

    func fetchOrders(isRefresh: Bool = false) {
        guard !isFetching else { return }
        
        if isRefresh {
            pageNum = 1
            hasMore = true
            orders.removeAll()
        }
        
        guard hasMore else { return }
        
        isFetching = true
        isLoading = true
        
        let params: [String: Any] = [
            "pageNum": pageNum,
            "pageSize": pageSize
        ]

        Task {
            do {
                let resp: MallOrderResponse = try await NetworkManager.shared.request(
                    "/petFriendly/client/mallOrderList",
                    parameters: params
                )

                if let rows = resp.rows {
                    let filtered = rows.filter { $0.isRedemption }
                    self.orders.append(contentsOf: filtered)
                    self.hasMore = rows.count == self.pageSize
                    self.pageNum += 1
                }
                self.isLoading = false
                self.isFetching = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                self.isFetching = false
            }
        }
    }
}

// MARK: - 积分兑换记录列表
struct ExchangeRecordListView: View {
    @StateObject private var vm = ExchangeRecordViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()

            if vm.orders.isEmpty && !vm.isLoading {
                emptyState
            } else {
                List {
                    ForEach(vm.orders) { order in
                        orderRow(order)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }

                    if vm.hasMore || vm.isLoading {
                        HStack {
                            Spacer()
                            PFPetLoadingInline(size: 18)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                        .onAppear {
                            if vm.hasMore {
                                vm.fetchOrders()
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    vm.fetchOrders(isRefresh: true)
                }
            }
        }
        .navigationTitle("mall_history")
        .navigationBarTitleDisplayMode(.inline)
        .pfToyBackground()
        .onAppear {
            if vm.orders.isEmpty {
                vm.fetchOrders()
            }
        }
    }

    private func orderRow(_ order: MallOrder) -> some View {
        HStack(spacing: PFSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: PFRadius.sm)
                    .fill(PFColors.warning.opacity(0.1))
                    .frame(width: 52, height: 52)

                if let imgStr = order.commodityImg,
                   let url = URL(string: NetworkManager.fullUrl(imgStr)?.absoluteString ?? "") {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 20))
                            .foregroundColor(PFColors.warning)
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: PFRadius.sm))
                } else {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 20))
                        .foregroundColor(PFColors.warning)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(order.displayTitle)
                    .font(PFFonts.subheadline)
                    .foregroundColor(PFColors.textPrimary)
                    .lineLimit(1)

                if let time = order.createTime {
                    Text(time)
                        .font(PFFonts.caption2)
                        .foregroundColor(PFColors.textTertiary)
                }
            }

            Spacer()

            Text(order.pointsText)
                .font(PFFonts.headline)
                .foregroundColor(PFColors.danger)
        }
        .padding(PFSpacing.lg)
        .background(PFColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PFRadius.lg))
        .pfCardShadow()
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "gift")
                .font(.system(size: 60))
                .foregroundColor(PFColors.textTertiary)

            Text(NSLocalizedString("mall_no_records", comment: ""))
                .font(PFFonts.body)
                .foregroundColor(PFColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
