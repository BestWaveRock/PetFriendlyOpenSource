import SwiftUI
import Alamofire

struct ContentReportTarget: Identifiable {
    let id = UUID()
    let type: String
    let targetId: Int64?
    let targetUserId: Int64?
}

struct ContentReportView: View {
    let target: ContentReportTarget
    @Environment(\.dismiss) private var dismiss
    @State private var reasonKey = "report_reason_false"
    @State private var detail = ""
    @State private var submitting = false

    private let reasonKeys = ["report_reason_false", "report_reason_harassment", "report_reason_illegal", "report_reason_privacy", "report_reason_animal_abuse", "report_reason_copyright", "report_reason_other"]

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("report_reason_section")) {
                    Picker(LocalizedStringKey("report_reason_picker"), selection: $reasonKey) {
                        ForEach(reasonKeys, id: \.self) { Text(LocalizedStringKey($0)).tag($0) }
                    }
                }
                Section(LocalizedStringKey("report_detail_optional")) {
                    TextEditor(text: $detail).frame(minHeight: 120)
                    Text("\(detail.count)/500").font(.caption).foregroundColor(.secondary)
                }
                Section {
                    Text("report_review_notice")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            .navigationTitle("report_content_title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common_cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitting ? NSLocalizedString("report_submitting", comment: "") : NSLocalizedString("report_submit", comment: "")) { submit() }
                        .disabled(submitting || detail.count > 500)
                }
            }
        }
    }

    private func submit() {
        guard NetworkManager.shared.token != nil else {
            showErrorHUD(message: NSLocalizedString("report_login_required", comment: ""))
            return
        }
        submitting = true
        Task {
            var params: [String: Any] = ["targetType": target.type, "reason": NSLocalizedString(reasonKey, comment: ""), "detail": detail]
            if let id = target.targetId { params["targetId"] = id }
            if let userId = target.targetUserId { params["targetUserId"] = userId }
            do {
                let response: RespWrapper<Int64> = try await NetworkManager.shared.request(
                    "/petFriendly/client/content/report", method: .post,
                    parameters: params, encoding: JSONEncoding.default)
                await MainActor.run {
                    submitting = false
                    if response.code == 200 {
                        showSuccessHUD(message: NSLocalizedString("report_submit_success", comment: ""))
                        dismiss()
                    } else {
                        showErrorHUD(message: response.msg ?? NSLocalizedString("report_submit_failed", comment: ""))
                    }
                }
            } catch {
                await MainActor.run { submitting = false; showErrorHUD(message: error.localizedDescription) }
            }
        }
    }
}

struct LegalDocumentView: View {
    let document: LegalDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(document.title).font(.title2.bold())
                Text(document.body).font(.body).lineSpacing(6).textSelection(.enabled)
                Text(String(format: NSLocalizedString("legal_contact_format", comment: ""), Secrets.privacyEmail, Secrets.supportEmail))
                    .font(.footnote).foregroundColor(.secondary)
            }
            .padding(20)
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
