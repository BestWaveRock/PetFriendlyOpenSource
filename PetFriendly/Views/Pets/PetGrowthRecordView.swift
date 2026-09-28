import SwiftUI
import Alamofire

// MARK: - 模型

struct PetGrowthRecord: Identifiable, Decodable {
    @Int64String var healthId: Int64?
    var id: String { healthId.map(String.init) ?? UUID().uuidString }
    @SafeDateString var downTime: String?
    let ext1: String?   // 体重 kg
    let ext2: String?   // 肩高 cm
    let comments: String?
    let createTime: String?

    var weightText: String? {
        guard let v = ext1, !v.isEmpty else { return nil }
        return v
    }
    var heightText: String? {
        guard let v = ext2, !v.isEmpty else { return nil }
        return v
    }
}

struct PetGrowthRecordResponse: Decodable {
    let code: Int
    let total: Int?
    let rows: [PetGrowthRecord]?
}

// MARK: - 生长记录页（体重/肩高时间线）

struct PetGrowthRecordView: View {
    let petId: String
    let petName: String
    var isReadOnly: Bool = false

    @State private var records: [PetGrowthRecord] = []
    @State private var isLoading = false
    @State private var showAdd = false

    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    if isLoading && records.isEmpty {
                        PFPetLoadingView("loading", size: 36)
                            .padding(.top, 80)
                    } else if records.isEmpty {
                        emptyState
                    } else {
                        // 标题头
                        HStack {
                            Text(String(format: NSLocalizedString("pet_growth_title", comment: ""), petName))
                                .font(PFFonts.headline)
                                .foregroundColor(PFColors.textPrimary)
                            Spacer()
                            Text("\(records.count)")
                                .font(PFFonts.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(PFGradients.brand)
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, PFSpacing.xl)
                        .padding(.vertical, PFSpacing.lg)

                        ForEach(Array(records.enumerated()), id: \.element.id) { index, rec in
                            growthRow(rec, isLast: index == records.count - 1)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .refreshable { fetchRecords() }
        }
        .navigationTitle("pet_growth_nav_title")
        .navigationBarTitleDisplayMode(.inline)
        .pfToyBackground()
        .toolbar {
            if !isReadOnly {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAdd = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(PFColors.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddGrowthRecordView(petId: petId) {
                fetchRecords()
            }
        }
        .onAppear { fetchRecords() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(PFColors.textTertiary)
            Text("pet_growth_empty")
                .font(PFFonts.headline)
                .foregroundColor(PFColors.textSecondary)
            Text("pet_growth_empty_sub")
                .font(PFFonts.caption)
                .foregroundColor(PFColors.textTertiary)
        }
        .padding()
    }

    private func growthRow(_ rec: PetGrowthRecord, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 18) {
            // 时间线节点
            VStack(spacing: 0) {
                Circle()
                    .fill(PFGradients.brand)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(PFColors.background, lineWidth: 2))
                if !isLast {
                    Rectangle()
                        .fill(PFColors.divider)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 6) {
                Text(rec.downTime ?? rec.createTime ?? "")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(PFColors.textPrimary)
                HStack(spacing: 12) {
                    if let w = rec.weightText {
                        Label("\(w) kg", systemImage: "scalemass.fill")
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.warning)
                    }
                    if let h = rec.heightText {
                        Label("\(h) cm", systemImage: "ruler.fill")
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.accent)
                    }
                }
                if let c = rec.comments, !c.isEmpty, c != "体重/肩高记录" {
                    Text(c)
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PFColors.surface)
            .cornerRadius(PFRadius.lg)
            .pfCardShadow()

            Spacer(minLength: 0)
        }
        .padding(.horizontal, PFSpacing.xl)
        .padding(.bottom, 10)
    }

    private func fetchRecords() {
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let resp: PetGrowthRecordResponse = try await NetworkManager.shared.request(
                    "/petFriendly/client/growthRecords",
                    method: .get,
                    parameters: ["petId": petId],
                    needToken: true,
                    showLoading: false
                )
                await MainActor.run { records = resp.rows ?? [] }
            } catch {
                await MainActor.run { UIState.shared.showToast(NSLocalizedString("pet_growth_fetch_failed", comment: ""), style: .error) }
            }
        }
    }
}

// MARK: - 新增生长记录表单

struct AddGrowthRecordView: View {
    let petId: String
    var onAdded: () -> Void = {}
    @Environment(\.dismiss) var dismiss

    @State private var measureDate = Date()
    @State private var weight = ""
    @State private var height = ""
    @State private var comment = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("pet_growth_measure_date")) {
                    DatePicker("pet_growth_measure_date", selection: $measureDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                }
                Section(header: Text("pet_growth_body")) {
                    HStack {
                        Text("pet_growth_weight")
                        Spacer()
                        TextField("0.0", text: $weight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("kg").font(PFFonts.caption).foregroundColor(PFColors.textSecondary)
                    }
                    HStack {
                        Text("pet_growth_height")
                        Spacer()
                        TextField("0.0", text: $height)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("cm").font(PFFonts.caption).foregroundColor(PFColors.textSecondary)
                    }
                }
                Section(header: Text("pet_growth_comment")) {
                    TextField("pet_growth_comment_placeholder", text: $comment)
                }
            }
            .navigationTitle("pet_growth_add_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common_cancel") { dismiss() }
                        .foregroundColor(PFColors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: submit) {
                        if isSubmitting {
                            PFPetLoadingInline(size: 18)
                        } else {
                            Text("form_submit").bold().foregroundColor(PFColors.primary)
                        }
                    }
                    .disabled(isSubmitting || !canSubmit)
                }
            }
        }
    }

    private var canSubmit: Bool {
        !isSubmitting && (!weight.isEmpty || !height.isEmpty)
    }

    @MainActor private func submit() {
        guard canSubmit else { return }
        isSubmitting = true
        let params: [String: Any] = [
            "petId": petId,
            "downTime": formatDate(measureDate),
            "ext1": weight.isEmpty ? "" : weight,
            "ext2": height.isEmpty ? "" : height,
            "comments": comment.isEmpty ? "体重/肩高记录" : comment
        ]
        Task {
            do {
                let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                    "/petFriendly/client/addGrowthRecord",
                    method: .post,
                    parameters: params,
                    encoding: JSONEncoding.default,
                    needToken: true,
                    showLoading: false
                )
                await MainActor.run {
                    isSubmitting = false
                    if resp.code == 200 {
                        UIState.shared.showToast(NSLocalizedString("pet_growth_add_success", comment: ""))
                        onAdded()
                        dismiss()
                    } else {
                        UIState.shared.showToast((resp.msg as? String) ?? NSLocalizedString("pet_growth_add_failed", comment: ""), style: .error)
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    UIState.shared.showToast((error as? BizError)?.errorDescription ?? NSLocalizedString("pet_growth_add_failed", comment: ""), style: .error)
                }
            }
        }
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: d)
    }
}
