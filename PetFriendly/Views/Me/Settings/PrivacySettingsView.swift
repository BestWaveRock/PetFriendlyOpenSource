//
//  PrivacySettingsView.swift
//  PetFriendly
//
//  Created by PetFriendly Team.
//

import SwiftUI
import Alamofire

struct PrivacySettingsView: View {
    @EnvironmentObject var store: AccountStore
    
    // 假设这些设置会同步到服务端的 PetOwner 附加字段
    @State private var isSyncing = false
    @State private var isExporting = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: PFSpacing.xl) {
                    
                    // 1. 文档类链接
                    settingsSection(title: NSLocalizedString("privacy_legal", comment: "")) {
                        NavigationLink(destination: LegalDocumentView(document: .privacy)) {
                            settingsRow(icon: "hand.raised.fill", color: PFColors.info, title: NSLocalizedString("privacy_policy", comment: ""))
                        }
                        
                        Divider().padding(.leading, 48)
                        
                        NavigationLink(destination: LegalDocumentView(document: .terms)) {
                            settingsRow(icon: "doc.text.fill", color: PFColors.primary, title: NSLocalizedString("privacy_agreement", comment: ""))
                        }

                        Divider().padding(.leading, 48)

                        NavigationLink(destination: LegalDocumentView(document: .community)) {
                            settingsRow(icon: "person.3.fill", color: PFColors.warning, title: NSLocalizedString("legal_community_short", comment: ""))
                        }

                        Divider().padding(.leading, 48)

                        NavigationLink(destination: LegalDocumentView(document: .ai)) {
                            settingsRow(icon: "sparkles", color: PFColors.accent, title: NSLocalizedString("legal_ai_short", comment: ""))
                        }
                    }
                    
                    // 2. 权限开关
                    settingsSection(title: NSLocalizedString("privacy_data_permissions", comment: "")) {
                        toggleRow(
                            icon: "location.fill",
                            color: PFColors.success,
                            title: NSLocalizedString("privacy_location_title", comment: ""),
                            subtitle: NSLocalizedString("privacy_location_subtitle", comment: ""),
                            isOn: Binding(
                                get: { store.settings.allowLocationTracking },
                                set: { store.settings.allowLocationTracking = $0; store.saveSettings() }
                            )
                        )
                        
                        Divider().padding(.leading, 48)
                        
                        toggleRow(
                            icon: "chart.bar.fill",
                            color: PFColors.warning,
                            title: NSLocalizedString("privacy_analysis_title", comment: ""),
                            subtitle: NSLocalizedString("privacy_analysis_subtitle", comment: ""),
                            isOn: Binding(
                                get: { store.settings.allowDataAnalysis },
                                set: { store.settings.allowDataAnalysis = $0; store.saveSettings() }
                            )
                        )
                        
                        Divider().padding(.leading, 48)
                        
                        toggleRow(
                            icon: "megaphone.fill",
                            color: PFColors.accent,
                            title: NSLocalizedString("privacy_personalized_title", comment: ""),
                            subtitle: NSLocalizedString("privacy_personalized_subtitle", comment: ""),
                            isOn: Binding(
                                get: { store.settings.allowPersonalizedAds },
                                set: { store.settings.allowPersonalizedAds = $0; store.saveSettings() }
                            )
                        )
                    }
                    
                    // 3. 账户操作
                    settingsSection(title: NSLocalizedString("privacy_info_mgmt", comment: "")) {
                        Button(action: {
                            exportUserData()
                        }) {
                            settingsActionRow(icon: "square.and.arrow.down.fill", color: PFColors.textPrimary, title: NSLocalizedString("privacy_export_data", comment: ""))
                        }
                        
                        Divider().padding(.leading, 48)
                        
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            settingsActionRow(icon: "person.crop.circle.badge.xmark.fill", color: PFColors.danger, title: NSLocalizedString("privacy_delete_account", comment: ""), isDestructive: true)
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.vertical, PFSpacing.lg)
            }
        }
        .navigationTitle("settings_privacy_settings")
        .navigationBarTitleDisplayMode(.inline)
        .pfToyBackground()
        .onDisappear {
            Task { await syncSettingsToServer() }
        }
        .alert(NSLocalizedString("account_delete_title", comment: ""), isPresented: $showDeleteConfirmation) {
            Button("common_cancel", role: .cancel) { }
            Button("account_delete_confirm", role: .destructive) { requestAccountDeletion() }
        } message: {
            Text("account_delete_notice")
        }
    }
    
    // MARK: - UI 组件
    
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringKey(title))
                .font(PFFonts.callout)
                .foregroundColor(PFColors.textSecondary)
                .padding(.horizontal, PFSpacing.xl)
                .padding(.bottom, PFSpacing.sm)
            
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: PFRadius.md)
                    .fill(PFColors.surface)
            )
            .padding(.horizontal, PFSpacing.lg)
            .pfCardShadow()
        }
    }
    
    private func settingsRow(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: PFSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(width: 28, height: 28)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            
            Text(LocalizedStringKey(title))
                .font(PFFonts.body)
                .foregroundColor(PFColors.textPrimary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(PFColors.textTertiary)
        }
        .padding(PFSpacing.lg)
    }
    
    private func toggleRow(icon: String, color: Color, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: PFSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(width: 28, height: 28)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(PFFonts.body)
                    .foregroundColor(PFColors.textPrimary)
                
                Text(LocalizedStringKey(subtitle))
                    .font(PFFonts.caption2)
                    .foregroundColor(PFColors.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(PFColors.primary)
        }
        .padding(PFSpacing.lg)
    }
    
    private func settingsActionRow(icon: String, color: Color, title: String, isDestructive: Bool = false) -> some View {
        HStack(spacing: PFSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(width: 28, height: 28)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            
            Text(LocalizedStringKey(title))
                .font(PFFonts.body)
                .foregroundColor(isDestructive ? PFColors.danger : PFColors.textPrimary)
            
            Spacer()
        }
        .padding(PFSpacing.lg)
    }
    
    // MARK: - 网络同步
    
    private func syncSettingsToServer() async {
        store.saveSettings()
    }

    private func exportUserData() {
        guard !isExporting else { return }
        isExporting = true
        NetworkManager.shared.requestRaw("/petFriendly/client/exportData", method: .get) { result in
            isExporting = false
            switch result {
            case .success(let data):
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("PetFriendly_Data_\(Int(Date().timeIntervalSince1970)).csv")
                do {
                    try data.write(to: url, options: .atomic)
                    guard let controller = UIApplication.shared.topMostViewController() else { return }
                    let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    controller.present(share, animated: true)
                } catch {
                    showErrorHUD(message: NSLocalizedString("privacy_export_failed", comment: ""))
                }
            case .failure(let error):
                showErrorHUD(message: error.localizedDescription)
            }
        }
    }

    private func requestAccountDeletion() {
        guard !isDeleting else { return }
        isDeleting = true
        Task {
            do {
                let response: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                    "/petFriendly/client/account/cancel", method: .post,
                    parameters: ["reason": NSLocalizedString("account_delete_reason", comment: "")], encoding: JSONEncoding.default)
                await MainActor.run {
                    isDeleting = false
                    if response.code == 200 {
                        showSuccessHUD(message: NSLocalizedString("account_delete_submitted", comment: ""))
                        store.logout()
                    } else {
                        showErrorHUD(message: response.msg ?? NSLocalizedString("common_request_failed", comment: ""))
                    }
                }
            } catch {
                await MainActor.run { isDeleting = false; showErrorHUD(message: error.localizedDescription) }
            }
        }
    }
}
