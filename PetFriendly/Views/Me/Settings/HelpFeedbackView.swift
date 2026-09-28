//
//  HelpFeedbackView.swift
//  PetFriendly
//
//  Created by PetFriendly Team.
//

import SwiftUI

struct HelpFeedbackView: View {
    @State private var feedbackText: String = ""
    @State private var contactInfo: String = ""
    @State private var isSubmitting = false
    @State private var expandedFaqId: Int? = 0
    
    // 客服邮箱
    private let supportEmail = Secrets.supportEmail
    
    // FAQ 问答集
    private var faqs: [(id: Int, q: String, a: String)] {
        [
            (0, NSLocalizedString("faq_q0", comment: ""), NSLocalizedString("faq_a0", comment: "")),
            (1, NSLocalizedString("faq_q1", comment: ""), NSLocalizedString("faq_a1", comment: "")),
            (2, NSLocalizedString("faq_q2", comment: ""), NSLocalizedString("faq_a2", comment: "")),
            (3, NSLocalizedString("faq_q3", comment: ""), NSLocalizedString("faq_a3", comment: ""))
        ]
    }
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: PFSpacing.xl) {
                    
                    // 1. FAQ 常见问题
                    VStack(alignment: .leading, spacing: 0) {
                        Text("help_faq")
                            .font(PFFonts.headline)
                            .foregroundColor(PFColors.textPrimary)
                            .padding(.horizontal, PFSpacing.lg)
                            .padding(.bottom, PFSpacing.md)
                        
                        VStack(spacing: 0) {
                            ForEach(faqs.indices, id: \.self) { idx in
                                let item = faqs[idx]
                                faqRow(
                                    question: item.q,
                                    answer: item.a,
                                    isExpanded: expandedFaqId == item.id,
                                    isLast: idx == faqs.count - 1
                                ) {
                                    withAnimation(PFAnimation.springBouncy) {
                                        expandedFaqId = (expandedFaqId == item.id) ? nil : item.id
                                    }
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: PFRadius.md)
                                .fill(PFColors.surface)
                        )
                        .padding(.horizontal, PFSpacing.lg)
                        .pfCardShadow()
                    }
                    
                    // 2. 意见反馈表单
                    VStack(alignment: .leading, spacing: 0) {
                        Text("help_feedback")
                            .font(PFFonts.headline)
                            .foregroundColor(PFColors.textPrimary)
                            .padding(.horizontal, PFSpacing.lg)
                            .padding(.bottom, PFSpacing.md)
                        
                        VStack(spacing: PFSpacing.md) {
                            
                            // 反馈内容 input
                            PFTextEditor(
                                placeholder: "help_feedback_placeholder",
                                text: $feedbackText,
                                height: 120,
                                maxLength: 500
                            )
                            
                            // 联系方式 input
                            TextField("help_contact_placeholder", text: $contactInfo)
                                .font(PFFonts.body)
                                .padding()
                                .background(PFColors.surfaceSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
                                .overlay(
                                    RoundedRectangle(cornerRadius: PFRadius.md)
                                        .stroke(PFColors.divider, lineWidth: 1)
                                )
                            
                            // 提交按钮
                            Button(action: {
                                Task { await submitFeedback() }
                            }) {
                                HStack {
                                    if isSubmitting {
                                        PFPetLoadingInline(size: 14)
                                            .padding(.trailing, 4)
                                    }
                                    Text(isSubmitting ? "help_submitting" : "help_submit")
                                        .font(PFFonts.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(feedbackText.count >= 10 ? PFGradients.brand : LinearGradient(colors: [PFColors.divider], startPoint: .leading, endPoint: .trailing))
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
                                .pfElevatedShadow(feedbackText.count >= 10 ? PFColors.primary : .clear)
                            }
                            .disabled(feedbackText.count < 10 || isSubmitting)
                            
                        }
                        .padding(PFSpacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: PFRadius.md)
                                .fill(PFColors.surface)
                        )
                        .padding(.horizontal, PFSpacing.lg)
                        .pfCardShadow()
                    }
                    
                    // 3. 底部售后信息
                    VStack(spacing: PFSpacing.xs) {
                        Text("help_more_help")
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.textSecondary)
                        
                        Button(action: {
                            if let url = URL(string: "mailto:\(supportEmail)") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text(supportEmail)
                                .font(PFFonts.callout)
                                .foregroundColor(PFColors.primary)
                                .underline()
                        }
                    }
                    .padding(.top, PFSpacing.lg)
                    
                    Spacer(minLength: 50)
                }
                .padding(.vertical, PFSpacing.lg)
            }
        }
        .navigationTitle("help_title")
        .navigationBarTitleDisplayMode(.inline)
        .pfToyBackground()
    }
    
    // FAQ 行展开组件
    private func faqRow(question: String, answer: String, isExpanded: Bool, isLast: Bool, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: action) {
                HStack {
                    Text(question)
                        .font(isExpanded ? PFFonts.headline : PFFonts.body)
                        .foregroundColor(isExpanded ? PFColors.primary : PFColors.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isExpanded ? PFColors.primary : PFColors.textTertiary)
                }
                .padding(PFSpacing.lg)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(answer)
                    .font(PFFonts.callout)
                    .foregroundColor(PFColors.textSecondary)
                    .lineSpacing(6)
                    .padding(.horizontal, PFSpacing.lg)
                    .padding(.bottom, PFSpacing.lg)
            }
            
            if !isLast {
                Divider().padding(.horizontal, PFSpacing.lg)
            }
        }
    }
    
    // 网络提交逻辑
    private func submitFeedback() async {
        isSubmitting = true
        
        let path = "/petFriendly/client/feedback/submit"
        let params: [String: Any] = [
            "content": feedbackText,
            "contact": contactInfo
        ]
        
        do {
            let resp: RespWrapper<Bool> = try await NetworkManager.shared.request(path, method: .post, parameters: params, needToken: true)
            if resp.code == 200 {
                showSuccessHUD(message: NSLocalizedString("help_submit_success", comment: ""))
            } else {
                print(resp.msg ?? NSLocalizedString("msg_submit_fail", comment: ""))
            }
        } catch {
            print(error.localizedDescription)
        }
        
        isSubmitting = false
        feedbackText = ""
        contactInfo = ""
    }
}
