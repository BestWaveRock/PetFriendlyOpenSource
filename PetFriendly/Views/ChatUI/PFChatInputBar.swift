//
//  PFChatInputBar.swift
//  PetFriendly
//
//  Grok 风格聊天输入栏 — 毛玻璃背景、弹簧发送动画、多媒体附件
//

import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

// MARK: - 主输入栏组件

struct PFChatInputBar: View {
    @Binding var text: String
    var isFocused: Binding<Bool>? = nil
    let onSend: (String) async -> Void
    let onAttachImage: (UIImage) -> Void
    let onAttachFile: (URL) -> Void
    /// 被引用（回复）的消息，用于在输入栏顶部展示引用条
    var replyMessage: Binding<ChatMessage?>? = nil
    // MARK: - 微信风格语音：单击提示 → 长按说话、松开发送、上滑取消
    var onVoiceTapHint: (() -> Void)? = nil
    var onVoiceStart: (() -> Void)? = nil
    var onVoiceCancel: (() -> Void)? = nil
    var onVoiceSend: (() -> Void)? = nil
    var voiceRecording: Binding<Bool> = .constant(false)
    var voiceCancelling: Binding<Bool> = .constant(false)
    /// 提示模式：点击麦克风后进入，此时按住才录音
    var voiceHintMode: Binding<Bool> = .constant(false)
    /// 语音转写中：输入框展示加载态
    var voiceTranscribing: Binding<Bool> = .constant(false)
    var isEnabled: Bool = true

    @FocusState private var isFieldFocused: Bool

    // 发送状态
    @State private var isSending = false

    @State private var showUnifiedPicker = false

    // 附件结果
    @State private var attachmentImage: UIImage? = nil
    @State private var fileURL: URL? = nil



    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - 发送处理

    private func handleSend() {
        guard hasText else { isFieldFocused = false; return }
        guard isEnabled else { return }
        guard !isSending else { return }

        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = ""
        isSending = true
        voiceHintMode.wrappedValue = false
        Haptics.play(.medium)

        Task {
            await onSend(content)
            await MainActor.run { isSending = false }
        }
        // 发送后立即收起键盘，方便查看回复
        isFieldFocused = false
    }

    /// 回车键处理：有内容则发送，无内容则收起键盘
    private func submitOrDismiss() {
        if hasText {
            handleSend()
        } else {
            isFieldFocused = false
        }
    }

    // MARK: - 图片压缩

    /// 将图片缩放到最大 1024px 以减少上传体积
    private func resizeIfNeeded(_ image: UIImage) -> UIImage {
        let maxDim: CGFloat = 1024
        let w = image.size.width
        let h = image.size.height
        guard w > maxDim || h > maxDim else { return image }
        let ratio = min(maxDim / w, maxDim / h)
        let newSize = CGSize(width: w * ratio, height: h * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - UI

    var body: some View {
        VStack(spacing: 0) {
            // 引用（回复）预览条
            if let reply = replyMessage?.wrappedValue {
                replyPreviewBar(reply)
            }

            HStack(spacing: PFSpacing.sm) {
                // 直接打开项目统一附件选择器，不再经过聊天输入栏自有二级菜单。
                Button(action: {
                    isFieldFocused = false
                    showUnifiedPicker = true
                    Haptics.play(.light)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(PFColors.textSecondary)
                }
                .disabled(!isEnabled)
                .buttonStyle(PFSimplePressButtonStyle())

                // 语音（两步式：点击提示 → 长按说话）按钮
                if onVoiceStart != nil {
                    VoiceRecordButton(
                        onTapHint: { onVoiceTapHint?() },
                        onStart: { onVoiceStart?() },
                        onCancel: { onVoiceCancel?() },
                        onSend: { onVoiceSend?() },
                        isRecording: voiceRecording,
                        isCancelling: voiceCancelling,
                        hintMode: voiceHintMode
                    )
                }

                // 多行文本输入（最多 4 行自动扩展）；语音转写中展示加载态
                if voiceTranscribing.wrappedValue {
                    HStack(spacing: 8) {
                        PFPetLoadingInline(size: 16)
                            .tint(PFColors.textTertiary)
                        Text(NSLocalizedString("voice_transcribing", comment: ""))
                            .font(PFFonts.body)
                            .foregroundColor(PFColors.textTertiary)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 24, alignment: .leading)
                    .transition(.opacity)
                } else {
                    TextField("chat_input_placeholder",
                        text: $text,
                        axis: .vertical
                    )
                    .focused($isFieldFocused)
                    .font(PFFonts.body)
                    .lineLimit(1...4)
                    .disabled(!isEnabled)
                    .textFieldStyle(.plain)
                    .submitLabel(.send)
                    .onSubmit(of: .text) { submitOrDismiss() }
                }

                // 发送按钮（弹簧动画）
                Button(action: handleSend) {
                    ZStack {
                        if isSending {
                            PFPetLoadingInline(size: 16)
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .background(
                        Group {
                            if hasText && !isSending {
                                Circle().fill(PFGradients.brand)
                            } else {
                                Circle().fill(Color.gray.opacity(0.3))
                            }
                        }
                    )
                }
                .disabled(!isEnabled || (!hasText && !isSending))
                 .buttonStyle(PFSimplePressButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        }
        .onChange(of: isFieldFocused) { newVal in
            if let isFocused = isFocused, isFocused.wrappedValue != newVal {
                isFocused.wrappedValue = newVal
            }
            // 用户点击输入框聚焦时，退出语音提示模式
            if newVal { voiceHintMode.wrappedValue = false }
        }
        .onChange(of: isFocused?.wrappedValue) { newVal in
            if let newVal = newVal, isFieldFocused != newVal {
                isFieldFocused = newVal
            }
        }

        // MARK: - 附件处理

        // 统一附件选择（相机、相册、文件）
        .onChange(of: attachmentImage) { img in
            if let img = img {
                let resized = resizeIfNeeded(img)
                onAttachImage(resized)
                attachmentImage = nil
            }
        }

        // 文件选择
        .onChange(of: fileURL) { url in
            if let url = url {
                onAttachFile(url)
                fileURL = nil
            }
        }

        // MARK: - Sheet & Dialog

        .sheet(isPresented: $showUnifiedPicker) {
            ImagePicker(image: $attachmentImage, fileURL: $fileURL)
        }
    }

    // MARK: - 引用预览条

    private func replyPreviewBar(_ reply: ChatMessage) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(PFColors.primary)
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("reply_label", comment: ""))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(PFColors.primary)
                Text(reply.previewText)
                    .font(.system(size: 13))
                    .foregroundColor(PFColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: { replyMessage?.wrappedValue = nil }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(PFColors.textTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

}

// MARK: - 语音录制按钮（微信式：长按说话、松开发送、上滑取消）

/// 单击麦克风：切换提示气泡「长按对话，松开发送」（轻震动）。
/// 长按麦克风：直接开始录音，抬起即识别发送，上滑超过阈值则取消。
struct VoiceRecordButton: View {
    /// 单击麦克风（切换提示气泡）
    let onTapHint: () -> Void
    /// 长按开始录音
    let onStart: () -> Void
    let onCancel: () -> Void
    let onSend: () -> Void
    @Binding var isRecording: Bool
    @Binding var isCancelling: Bool
    /// 提示气泡是否展示（单击切换）
    @Binding var hintMode: Bool

    @State private var pressing = false
    @State private var longPressTask: Task<Void, Never>?
    /// 长按达成阈值：按住超过该时长才真正开始录音（短按视为单击提示）
    private let longPressDuration: UInt64 = 200_000_000
    /// 上滑超过该距离进入取消区
    private let cancelThreshold: CGFloat = -60

    var body: some View {
        ZStack(alignment: .top) {
            Image(systemName: "mic.fill")
                .font(.system(size: 18))
                .foregroundColor(
                    isRecording
                    ? (isCancelling ? .red : PFColors.primary)
                    : (hintMode ? PFColors.primary : PFColors.textSecondary)
                )
                .frame(width: 36, height: 36)
                .scaleEffect(hintMode && !isRecording ? 1.15 : (isRecording ? 1.1 : 1.0))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hintMode)
                .contentShape(Rectangle())
                // 单击：切换提示气泡（轻震动由外部处理）
                .onTapGesture {
                    withAnimation { hintMode.toggle() }
                    onTapHint()
                }
                // 长按录音：按住超过阈值开始录音，松手即发送，上滑取消
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !pressing {
                                pressing = true
                                // 短按不录音，仅超过阈值后才开始
                                longPressTask = Task {
                                    try? await Task.sleep(nanoseconds: longPressDuration)
                                    if pressing && !isRecording {
                                        onStart()
                                    }
                                }
                            }
                            // 录音中：根据上滑距离更新取消状态
                            if isRecording {
                                let cancelling = value.translation.height < cancelThreshold
                                if isCancelling != cancelling { isCancelling = cancelling }
                            }
                        }
                        .onEnded { _ in
                            defer {
                                pressing = false
                                longPressTask?.cancel()
                                longPressTask = nil
                            }
                            // 松手即结束：正在录音则发送或取消；否则视为单击提示，不录音
                            if isRecording {
                                if isCancelling { onCancel() } else { onSend() }
                            }
                        }
                )

            // 提示气泡：单击麦克风后浮在上方，可再次单击或点输入框关闭
            if hintMode && !isRecording {
                Text(NSLocalizedString("voice_tap_hint", comment: ""))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.8))
                    )
                    .offset(y: -44)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .buttonStyle(PFSimplePressButtonStyle())
    }
}

// MARK: - Preview

struct PFChatInputBar_Previews: View {
    @State private var text = ""

    var body: some View {
        VStack(spacing: PFSpacing.lg) {
            Text("chat_input_placeholder")
                .font(PFFonts.caption)
                .foregroundColor(PFColors.textTertiary)

            PFChatInputBar(
                text: $text,
                onSend: { _ in },
                onAttachImage: { _ in },
                onAttachFile: { _ in }
            )

            Spacer()
        }
        .padding(PFSpacing.xl)
        .background(PFColors.background)
    }
}

#Preview {
    PFChatInputBar_Previews()
}
