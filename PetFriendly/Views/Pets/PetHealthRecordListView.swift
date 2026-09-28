import SwiftUI

struct PetHealthRecordListView: View {
    let petId: String
    let petName: String
    var isReadOnly: Bool = false
    @StateObject private var viewModel = PetDetailViewModel()
    @State private var showAddRecord = false
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 内容
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        if viewModel.records.isEmpty {
                            VStack(spacing: 20) {
                                Spacer().frame(height: 60)
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 60))
                                    .foregroundColor(PFColors.textTertiary)
                                Text("pet_health_empty")
                                    .font(PFFonts.headline)
                                    .foregroundColor(PFColors.textSecondary)
                                Text("pet_health_empty_sub")
                                    .font(PFFonts.caption)
                                    .foregroundColor(PFColors.textTertiary)
                            }
                            .padding()
                        } else {
                            // 标题头
                            HStack {
                                Text(String(format: NSLocalizedString("pet_health_timeline", comment: ""), petName))
                                    .font(PFFonts.headline)
                                    .foregroundColor(PFColors.textPrimary)
                                Spacer()
                                Text(String(format: NSLocalizedString("pet_health_count", comment: ""), viewModel.records.count))
                                    .font(PFFonts.caption)
                                    .foregroundColor(PFColors.textTertiary)
                            }
                            .padding(.horizontal, PFSpacing.xl)
                            .padding(.vertical, PFSpacing.lg)
                            
                            ForEach(Array(viewModel.records.enumerated()), id: \.element.id) { index, record in
                                HealthRecordRow(
                                    record: record,
                                    isLast: index == viewModel.records.count - 1
                                )
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
                .refreshable {
                    viewModel.fetchRecords(petId: petId)
                }
            }
        }
        .navigationTitle("pet_health_title")
        .navigationBarTitleDisplayMode(.inline)
        .trackScene("PetHealthRecords")
        .toolbar {
            if !isReadOnly {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddRecord = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(PFColors.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddRecord) {
            AddHealthRecordView(petId: petId) {
                viewModel.fetchRecords(petId: petId)
            }
        }
        .onAppear {
            viewModel.fetchRecords(petId: petId)
        }
    }
}
