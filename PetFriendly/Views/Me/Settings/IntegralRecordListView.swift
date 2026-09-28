import SwiftUI

struct IntegralRecord: Codable, Identifiable {
    /// 稳定唯一标识。优先 ownerAssetsRecordId，fallback 用 createTime+remark 防重复 0
    var id: String {
        if let rid = ownerAssetsRecordId, rid != 0 { return String(rid) }
        var hasher = Hasher()
        hasher.combine(createTime)
        hasher.combine(remark)
        hasher.combine(changeValue)
        return "ir_\(hasher.finalize())"
    }
    @Int64String var ownerAssetsRecordId: Int64?
    let assetsType: Int?    // 1=爱心值, 2=积分
    let changeType: Int?    // 1=获得, 2=消耗
    let changeValue: String? // BigDecimal as String
    let remark: String?
    let createTime: String?
    
    var amountText: String {
        let val = Double(changeValue ?? "0") ?? 0
        let sign = changeType == 1 ? "+" : "-"
        // 格式化输出：如果是整数则去掉小数点，否则保留一位小数
        if val.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(sign)\(Int(val))"
        } else {
            return String(format: "\(sign)%.1f", val)
        }
    }
    

}


struct IntegralRecordResponse: Codable {
    let code: Int
    let msg: String?
    let rows: [IntegralRecord]?
    let total: Int?
}

class IntegralRecordViewModel: ObservableObject {
    @Published var records: [IntegralRecord] = []
    @Published var isLoading = false
    @Published var hasMore = true
    
    private var pageNum = 1
    private let pageSize = 20
    
    func fetchRecords(isRefresh: Bool = false) {
        if isRefresh {
            pageNum = 1
            hasMore = true
            records.removeAll()
        }
        
        guard hasMore && !isLoading else { return }
        
        isLoading = true
        let params: [String: Any] = [
            "pageNum": pageNum,
            "pageSize": pageSize,
            "assetsType": 2 // 只查积分（后端 ASSETS_TYPE_INTEGRAL=2，1=爱心值）
        ]
        
        Task {
            do {
                let resp: IntegralRecordResponse = try await NetworkManager.shared.request(
                    "/petFriendly/client/assetsRecordList",
                    parameters: params
                )
                
                await MainActor.run {
                    if let rows = resp.rows {
                        self.records.append(contentsOf: rows)
                        self.hasMore = rows.count == self.pageSize
                        self.pageNum += 1
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct IntegralRecordListView: View {
    @StateObject private var viewModel = IntegralRecordViewModel()
    @Environment(\.dismiss) var dismiss
    /// 已展开的记录 id（名称过长时可点击展开/收起）
    @State private var expandedIDs: Set<String> = []
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            if viewModel.records.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: PFSpacing.md) {
                        ForEach(viewModel.records) { record in
                            recordRow(record)
                        }
                        
                        if viewModel.hasMore || viewModel.isLoading {
                            PFPetLoadingInline(size: 18)
                                .padding()
                                .onAppear {
                                    if viewModel.hasMore {
                                        viewModel.fetchRecords()
                                    }
                                }
                        } else if !viewModel.records.isEmpty {
                            Text("common_no_more")
                                .font(PFFonts.caption2)
                                .foregroundColor(PFColors.textTertiary)
                                .padding()
                        }
                    }
                    .padding(PFSpacing.lg)
                }
                .refreshable {
                    viewModel.fetchRecords(isRefresh: true)
                }
            }
        }
        .navigationTitle("integral_records_title")
        .navigationBarTitleDisplayMode(.inline)
        .pfToyBackground()
        .onAppear {
            viewModel.fetchRecords()
        }
    }
    
    private func recordRow(_ record: IntegralRecord) -> some View {
        let color = record.changeType == 1 ? PFColors.success : PFColors.danger
        // 名称过长时可点击展开/收起（"展示更多"）
        let isExpanded = expandedIDs.contains(record.id)
        let remark = record.remark ?? ""
        let isLong = remark.count > 16
        return HStack(spacing: PFSpacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: record.changeType == 1 ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(remark)
                    .font(PFFonts.subheadline)
                    .foregroundColor(PFColors.textPrimary)
                    .lineLimit(isExpanded ? nil : 1)
                    // 长名称可点击切换展开/收起
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard isLong else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isExpanded { expandedIDs.remove(record.id) }
                            else { expandedIDs.insert(record.id) }
                        }
                    }
                
                if isLong {
                    HStack(spacing: 3) {
                        Text(isExpanded ? "common_fold" : "common_show_more")
                            .font(PFFonts.caption2)
                            .foregroundColor(PFColors.primary)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                            .foregroundColor(PFColors.primary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isExpanded { expandedIDs.remove(record.id) }
                            else { expandedIDs.insert(record.id) }
                        }
                    }
                }
                
                Text(record.createTime ?? "")
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(record.amountText)
                    .font(PFFonts.headline)
                    .foregroundColor(color)
                
                Text(NSLocalizedString("integral_unit", comment: ""))
                    .font(PFFonts.caption2)
                    .foregroundColor(PFColors.textSecondary)
            }
        }
        .padding(PFSpacing.lg)
        .background(PFColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PFRadius.lg))
        .pfCardShadow()
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 60))
                .foregroundColor(PFColors.textTertiary)
            
            Text(NSLocalizedString("integral_no_records", comment: ""))
                .font(PFFonts.body)
                .foregroundColor(PFColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
