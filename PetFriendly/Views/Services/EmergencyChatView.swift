//
//  EmergencyChatView.swift
//  PetFriendly
//
//  宠物急救聊天 — 基于 PFChatUI 设计模式包重构
//  - Telegram iOS 27 风格聊天气泡
//  - Grok 风格输入栏 + 图片上传
//  - 真实急救引导流程（非 demo "救护车在路上"）
//

import SwiftUI
import Combine
import AVFoundation

// MARK: - 急救聊天 ViewModel

/// 宠物急救聊天专用的 ViewModel，继承 PFChatViewModelBase
/// 通过 SSE 流式接收 AI 急救指导，支持图片上传、宠物关联
@MainActor
class EmergencyChatViewModel: PFChatViewModelBase {
    /// 是否已连接
    private var isConnected = false
    /// 当前关联的宠物 ID
    private var linkedPetId: String?
    /// 持久化会话 ID（设备唯一，支持多轮对话上下文）；新建对话时会被替换
    private var sessionId: String

    init() {
        // 生成/恢复持久化会话 ID
        if let saved = UserDefaults.standard.string(forKey: "emergency_chat_session_id") {
            sessionId = saved
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "emergency_chat_session_id")
            sessionId = newId
        }
        super.init(scene: .emergency)
    }

    // MARK: - 连接 / 断开

    /// 初始化急救对话（无需保持长连接，AI 回复通过每次 /send 请求获取）
    func connect() {
        guard !isConnected else { return }
        isConnected = true
    }

    func disconnect() {
        isConnected = false
    }

    // MARK: - 系统问候语

    /// 首次连接时发送系统引导消息
    private func appendSystemGreeting() {
        appendMessage(.system(NSLocalizedString("emergency_connecting", comment: "")))

        appendMessage(ChatMessage(
            content: .text(NSLocalizedString("emergency_greeting", comment: "")),
            senderId: "ai",
            senderName: "急救助手",
            status: .read,
            isOutgoing: false
        ))

        appendMessage(ChatMessage(
            content: .text(NSLocalizedString("emergency_find_hospital_hint", comment: "")),
            senderId: "ai",
            senderName: "急救助手",
            status: .read,
            isOutgoing: false
        ))

        appendMessage(.system(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)))
    }

    // MARK: - 设置关联宠物

    func linkPet(id: String) {
        linkedPetId = id
    }

    func unlinkPet() {
        linkedPetId = nil
    }

    func onPetSelected(_ pet: Pet) {
        linkedPetId = pet.petId
        // Show greeting only on first pet selection
        if messages.isEmpty {
            appendSystemGreeting()
        }
    }

    /// 新建对话：生成新的会话 ID（后端将以此开启全新上下文），清空本地消息并重新展示问候语。
    /// 已选择的宠物保留，新的对话首条消息会再次注入该宠物的信息/档案上下文。
    func startNewConversation() {
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "emergency_chat_session_id")
        sessionId = newId
        messages.removeAll()
        appendSystemGreeting()
    }

    // MARK: - PFChatViewModelBase 重写

    override func send(text: String, quoting reply: ChatMessage?) async {
        isSending = true

        // 添加用户消息（本地即时显示，注入当前登录用户的头像）
        let avatarUrl = AccountStore.shared.petOwner?.petAvatar ?? AccountStore.shared.user?.avatar
        let quotedId = reply?.id
        let quotedPreview = reply?.previewText
        let userMsg = ChatMessage(
            content: .text(text),
            senderAvatar: avatarUrl,
            status: .sending,
            isOutgoing: true,
            quotedMessageId: quotedId,
            quotedPreview: quotedPreview
        )
        appendMessage(userMsg)

        do {
            var params: [String: String] = ["content": text, "sessionId": sessionId]
            if let petId = linkedPetId {
                params["petId"] = petId
            }
            if let quotedId = quotedId {
                params["replyTo"] = quotedId
            }
            if let quotedPreview = quotedPreview {
                params["replyPreview"] = quotedPreview
            }

            // 更新为已发送
            updateMessage(id: userMsg.id) { $0 = ChatMessage(
                id: userMsg.id,
                content: .text(text),
                senderAvatar: avatarUrl,
                status: .delivered,
                isOutgoing: true,
                quotedMessageId: quotedId,
                quotedPreview: quotedPreview
            )}

            // 服务器流式回复
            try await executeStreamRequest(params: params)
        } catch {
            updateMessage(id: userMsg.id) { $0 = ChatMessage(
                id: userMsg.id,
                content: .text(text),
                senderAvatar: avatarUrl,
                status: .failed(error.localizedDescription),
                isOutgoing: true,
                quotedMessageId: quotedId,
                quotedPreview: quotedPreview
            )}
        }

        isSending = false
    }

    override func send(imageURL: URL, messageId: String?, thumbURL: URL? = nil) async {
        let avatarUrl = AccountStore.shared.petOwner?.petAvatar ?? AccountStore.shared.user?.avatar

        let targetId: String
        if let messageId = messageId,
           messages.contains(where: { $0.id == messageId }) {
            // 更新已有的占位消息（避免重复记录）
            targetId = messageId
            updateMessage(id: targetId) { $0 = ChatMessage(
                id: targetId,
                content: .image(url: imageURL, thumbURL: thumbURL),
                senderAvatar: avatarUrl,
                status: .delivered,
                isOutgoing: true,
                uploadProgress: $0.uploadProgress
            )}
        } else {
            // 复用已上传 URL 的再次发送：新建一条消息
            let userMsg = ChatMessage(
                content: .image(url: imageURL, thumbURL: thumbURL),
                senderAvatar: avatarUrl,
                status: .sending,
                isOutgoing: true
            )
            appendMessage(userMsg)
            targetId = userMsg.id
            updateMessage(id: targetId) { $0 = ChatMessage(
                id: targetId,
                content: .image(url: imageURL, thumbURL: thumbURL),
                senderAvatar: avatarUrl,
                status: .delivered,
                isOutgoing: true
            )}
        }

        do {
            var params: [String: String] = [
                "content": NSLocalizedString("emergency_image_prefix", comment: ""),
                "imageUrl": imageURL.absoluteString,
                "sessionId": sessionId
            ]
            if let petId = linkedPetId {
                params["petId"] = petId
            }

            // 服务器流式回复（使用原图，保证 AI 视觉识别清晰度）
            try await executeStreamRequest(params: params)
        } catch {
            updateMessage(id: targetId) { $0 = ChatMessage(
                id: targetId,
                content: .image(url: imageURL, thumbURL: thumbURL),
                senderAvatar: avatarUrl,
                status: .failed(error.localizedDescription),
                isOutgoing: true
            )}
        }
    }

    private func executeStreamRequest(params: [String: String]) async throws {
        guard let url = URL(string: NetworkManager.shared.baseURL + "/petFriendly/client/emergencyChat/send") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Secrets.appKey, forHTTPHeaderField: "X-APP-KEY")
        request.setValue(Secrets.clientId, forHTTPHeaderField: "CliendId")
        if let tk = NetworkManager.shared.token {
            request.setValue("Bearer \(tk)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: params)

        let (bytes, _) = try await URLSession.shared.bytes(for: request)

        // 流式回复期间挂起本地持久化，避免每个 token 都写入 UserDefaults 阻塞主线程
        suspendPersistence()
        defer { resumePersistence() }

        let msgId = UUID().uuidString
        appendMessage(ChatMessage(
            id: msgId,
            content: .text(""),
            senderId: "ai",
            senderName: "急救助手",
            status: .read,
            isOutgoing: false,
            isStreaming: true
        ))

        var fullReply = ""
        var isJSON = false
        var rawResponse = ""

        for try await line in bytes.lines {
            rawResponse.append(line + "\n")
            if line.trimmingCharacters(in: .whitespaces).starts(with: "{") {
                isJSON = true
            }

            if line.starts(with: "data:") {
                // 仅去掉 SSE 行前缀 "data:" 后的首个分隔空格。
                // 后端已对 token 中的换行/回车做了转义（\n -> \\n），这里先还原，
                // 保证 AI 回复里的段落换行与缩进格式完整保留。
                var text = String(line.dropFirst(5))
                if text.hasPrefix(" ") { text.removeFirst() }
                text = text
                    .replacingOccurrences(of: "\\r", with: "\r")
                    .replacingOccurrences(of: "\\n", with: "\n")
                text = text.replacingOccurrences(of: "\r", with: "")
                if !text.isEmpty {
                    fullReply.append(text)
                    await MainActor.run {
                        updateMessage(id: msgId) { $0 = ChatMessage(
                            id: msgId,
                            content: .text(fullReply),
                            senderId: "ai",
                            senderName: "急救助手",
                            status: .read,
                            isOutgoing: false,
                            isStreaming: true
                        )}
                    }
                }
            }
        }

        // 流式结束：标记为非流式，仅做一次 Markdown 格式化渲染（不再逐字解析，消除越吐越卡的问题）
        let finalReply = fullReply
        await MainActor.run {
            updateMessage(id: msgId) { $0 = ChatMessage(
                id: msgId,
                content: .text(finalReply),
                senderId: "ai",
                senderName: "急救助手",
                status: .read,
                isOutgoing: false,
                isStreaming: false
            )}
        }

        // 兼容性 Fallback：如果是旧的同步 JSON 格式响应，则解析出整段文本并更新
        if isJSON, let data = rawResponse.data(using: .utf8) {
            struct TemporaryResp: Decodable {
                let code: Int
                let msg: String?
                let data: String?
            }
            if let resp = try? JSONDecoder().decode(TemporaryResp.self, from: data),
                let reply = resp.data, !reply.isEmpty {
                await MainActor.run {
                    updateMessage(id: msgId) { $0 = ChatMessage(
                        id: msgId,
                        content: .text(reply),
                        senderId: "ai",
                        senderName: "急救助手",
                        status: .read,
                        isOutgoing: false,
                        isStreaming: false
                    )}
                }
            }
        }
    }

    override func loadHistory() async {
        isLoadingHistory = true
        // 目前先不做历史加载，保留未来扩展
        try? await Task.sleep(nanoseconds: 500_000_000)
        isLoadingHistory = false
    }

    /// 发送图片（从 UIImage）
    override func send(image: UIImage) async {
        // 这里重写为使用 PFChatViewModelBase 的上传逻辑
        await super.send(image: image)
    }
}

// MARK: - 急救聊天视图

struct EmergencyChatView: View {
    @StateObject private var viewModel = EmergencyChatViewModel()
    @State private var inputText = ""
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var uiState: UIState
    @FocusState private var isFieldFocused: Bool

    private var keyboardActiveBinding: Binding<Bool> {
        Binding(
            get: { isFieldFocused },
            set: { isFieldFocused = $0 }
        )
    }

    // 宠物关联
    @StateObject private var petViewModel = PetViewModel.shared
    @State private var selectedPet: Pet? = nil
    @State private var showPetSelector = false
    @StateObject private var recorder = AudioRecorderManager()
    // 长按回复所引用的消息
    @State private var quotedMessage: ChatMessage? = nil
    // 语音录制 HUD 状态（微信式：长按说话、松开发送、上滑取消）
    @State private var voiceRecording = false
    @State private var voiceCancelling = false
    /// 提示气泡：单击麦克风切换展示，3 秒后自动消失
    @State private var voiceHintMode = false
    /// 语音转写中：输入框展示加载态
    @State private var voiceTranscribing = false
    /// 切换宠物引导提示（仅自动关联成功后展示一次）
    @State private var showSwitchHint = false
    /// 免责声明条（可关闭，关闭后不再展示）
    @State private var showDisclaimer = true

    private static let lastLinkedPetIdKey = "last_linked_pet_id"
    private static let petSwitchHintShownKey = "pet_switch_hint_shown"
    private static let disclaimerDismissedKey = "pet_disclaimer_dismissed"

    var body: some View {
        Group {
            if selectedPet == nil {
                petRequiredView
            } else {
                chatContentView
            }
        }
        .navigationTitle("emergency_title")
        .navigationBarTitleDisplayMode(.inline)
        .trackScene("EmergencyChat")
        .toolbar { toolbarContent }
        .onAppear { onAppear() }
        .onChange(of: petViewModel.pets.count) { _ in
            // 宠物列表异步加载完成后，再次尝试自动关联上次宠物
            restoreLastPetIfNeeded()
        }
        .onDisappear { viewModel.disconnect() }
        .onChange(of: voiceHintMode) { on in
            // 提示气泡展示 3 秒后自动消失，避免「取消不掉」
            if on {
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if voiceHintMode { voiceHintMode = false }
                }
            }
        }
        .sheet(isPresented: $showPetSelector) { petSelectorSheet }
        .overlay(alignment: .center) {
            if voiceRecording {
                voiceRecordHUD
            }
        }
    }

    private var chatContentView: some View {
        VStack(spacing: 0) {
            chatHeader
            if showSwitchHint {
                switchHintBar
            }
            if showDisclaimer {
                disclaimerBar
            }
            messageList
            inputBarSection
        }
    }

    // 切换宠物引导提示：自动关联成功后仅展示一次
    private var switchHintBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 13))
                .foregroundColor(PFColors.primary)
            Text(NSLocalizedString("pet_switch_hint", comment: ""))
                .font(.system(size: 12))
                .foregroundColor(PFColors.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: { dismissSwitchHint() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(PFColors.textTertiary)
            }
        }
        .padding(.horizontal, PFSpacing.md)
        .padding(.vertical, 6)
        .background(PFColors.primary.opacity(0.1))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // 常驻轻提示：明确 AI 建议仅供参考，引导紧急时就医，弱化“急救”依赖
    private var disclaimerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13))
                .foregroundColor(PFColors.textTertiary)
            Text(NSLocalizedString("pet_helper_disclaimer", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(PFColors.textTertiary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: { dismissDisclaimer() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(PFColors.textTertiary)
            }
        }
        .padding(.horizontal, PFSpacing.md)
        .padding(.vertical, 6)
        .background(PFColors.surfaceSecondary.opacity(0.5))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - 聊天头部（展示当前用户头像与咨询中的宠物）

    private var chatHeader: some View {
        HStack(spacing: 10) {
            // 当前用户头像（左侧）
            if let avatarUrlStr = AccountStore.shared.petOwner?.petAvatar ?? AccountStore.shared.user?.avatar,
               let url = NetworkManager.fullUrl(avatarUrlStr) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(PFColors.surfaceSecondary)
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable().scaledToFill()
                    .frame(width: 36, height: 36)
                    .foregroundColor(PFColors.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                let userName = AccountStore.shared.petOwner?.name
                    ?? AccountStore.shared.user?.nickName
                    ?? NSLocalizedString("me_title", comment: "")
                Text(userName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(PFColors.textPrimary)
                if let pet = selectedPet {
                    Text(String(format: NSLocalizedString("emergency_chat_with_pet", comment: ""), pet.name))
                        .font(.system(size: 12))
                        .foregroundColor(PFColors.textSecondary)
                } else {
                    Text(NSLocalizedString("emergency_no_pet_header", comment: ""))
                        .font(.system(size: 12))
                        .foregroundColor(PFColors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, PFSpacing.md)
        .padding(.vertical, 8)
        .background(PFColors.surface)
    }

    private var petRequiredView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "pawprint.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.linearGradient(colors: [Color.orange, Color.pink], startPoint: .topLeading, endPoint: .bottomTrailing))

            Text(NSLocalizedString("select_pet_first", comment: ""))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(PFColors.textPrimary)

            Text("emergency_link_pet_hint")
                .font(.system(size: 15))
                .foregroundColor(PFColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Button(action: { showPetSelector = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text(NSLocalizedString("select_pet", comment: ""))
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: 220)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(colors: [Color.orange, Color.pink], startPoint: .leading, endPoint: .trailing))
                )
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(PFColors.background)
    }

    // MARK: - 消息列表

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(viewModel.messages) { msg in
                        PFChatBubble(
                            message: msg,
                            cornerStyle: .all,
                            allowContextMenu: !msg.content.isSystem,
                            onReact: { emoji in
                                // 反应功能预留
                            },
                            onReply: {
                                quotedMessage = msg
                                isFieldFocused = true
                            },
                            onRetry: { viewModel.retry(message: msg.id) },
                            onDelete: { viewModel.delete(message: msg.id) }
                        )
                        .id(msg.id)
                    }

                    // 底部留白
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, PFSpacing.md)
                .padding(.vertical, PFSpacing.sm)
            }
            .background(PFColors.background)
            .pf_dismissKeyboardOnScroll()
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation(PFAnimation.easeOut) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            // 刚进入时滚动到底部
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            // 点击空白收起键盘
            .onTapGesture { isFieldFocused = false }
        }
    }

    // MARK: - 输入栏

    private var inputBarSection: some View {
        VStack(spacing: 0) {
            // 快速引导选项（Chips）
            quickActionsSection

            // 关联宠物指示器
            if let pet = selectedPet {
                linkedPetBar(pet: pet)
            }

            PFChatInputBar(
                text: $inputText,
                isFocused: keyboardActiveBinding,
                onSend: { text in
                    await viewModel.send(text: text, quoting: quotedMessage)
                    quotedMessage = nil
                },
                onAttachImage: { image in
                    Task {
                        await viewModel.send(image: image)
                    }
                },
                onAttachFile: { url in
                    Task {
                        await viewModel.send(fileAt: url)
                    }
                },
                replyMessage: $quotedMessage,
                onVoiceTapHint: {
                    // 点击麦克风：轻震动 + 提示气泡（已在按钮内展示）
                    Haptics.play(.light)
                },
                onVoiceStart: {
                    // 进入长按录音，隐藏提示气泡
                    voiceHintMode = false
                    recorder.requestPermission()
                    recorder.start()
                    voiceRecording = recorder.isRecording
                },
                onVoiceCancel: {
                    recorder.cancel()
                    voiceRecording = false
                    voiceCancelling = false
                    voiceHintMode = false
                },
                onVoiceSend: {
                    finishVoiceRecording()
                },
                voiceRecording: $voiceRecording,
                voiceCancelling: $voiceCancelling,
                voiceHintMode: $voiceHintMode,
                voiceTranscribing: $voiceTranscribing,
                isEnabled: true
            )
            .padding(.horizontal, PFSpacing.lg)
            .padding(.vertical, PFSpacing.sm)
            .background(
                PFColors.surface
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -2)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    // MARK: - 语音录制 HUD（WeChat 风格）

    private var voiceRecordHUD: some View {
        VStack(spacing: 14) {
            Image(systemName: voiceCancelling ? "arrow.up.circle.fill" : "mic.fill")
                .font(.system(size: 40))
                .foregroundColor(voiceCancelling ? .red : .white)

            Text(String(format: "%d:%02d / 5:00", Int(recorder.elapsed) / 60, Int(recorder.elapsed) % 60))
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .foregroundColor(recorder.elapsed >= AudioRecorderManager.maxDuration - 10 ? .orange : .white)

            Text(voiceCancelling
                 ? "松开手指，取消发送"
                 : "手指上滑，取消发送")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.72))
        )
        .frame(width: 180, height: 180)
    }

    // MARK: - 关联宠物栏

    private func linkedPetBar(pet: Pet) -> some View {
        HStack {
            Image(systemName: "pawprint.fill")
                .font(.caption)
                .foregroundColor(PFColors.primary)
            Text(String(format: NSLocalizedString("emergency_linked_pet", comment: ""), pet.name))
                .font(PFFonts.caption)
                .foregroundColor(PFColors.primary)
            Spacer()
            Button(action: {
                selectedPet = nil
                viewModel.unlinkPet()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(PFColors.textTertiary)
            }
        }
        .padding(.horizontal, PFSpacing.lg)
        .padding(.vertical, 8)
        .background(PFColors.primary.opacity(0.1))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                // 新建对话
                Button(action: { viewModel.startNewConversation() }) {
                    Image(systemName: "plus.bubble")
                        .font(.system(size: 18))
                        .foregroundColor(PFColors.primary)
                }

                // 关联宠物
                Button(action: { showPetSelector = true }) {
                    Image(systemName: selectedPet != nil ? "pawprint.circle.fill" : "pawprint.circle")
                        .font(.system(size: 18))
                        .foregroundColor(selectedPet != nil ? PFColors.primary : PFColors.textTertiary)
                }

                // 查找附近医院
                Button(action: {
                    uiState.pendingMapRadius = 20000
                    uiState.pendingMapFilter = NSLocalizedString("place_type_hospital", comment: "")
                    dismiss()
                }) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(PFColors.primary)
                }
            }
        }
    }

    // MARK: - Lifecycle

    private func onAppear() {
        viewModel.connect()
        // 录音到达 5 分钟上限时，自动停止并发送
        recorder.onAutoStop = { _ in
            Task { @MainActor in
                self.finishVoiceRecording()
            }
        }
        if petViewModel.pets.isEmpty {
            petViewModel.fetchPets()
        }
        // 若用户曾关闭过免责声明，则不再展示
        showDisclaimer = !UserDefaults.standard.bool(forKey: EmergencyChatView.disclaimerDismissedKey)
        // 重新进入时自动关联上次关联的宠物（宠物列表可能尚未加载完）
        restoreLastPetIfNeeded()
    }

    // 重新进入时自动关联上次关联的宠物
    private func restoreLastPetIfNeeded() {
        guard selectedPet == nil else { return }
        guard let savedId = UserDefaults.standard.string(forKey: EmergencyChatView.lastLinkedPetIdKey) else {
            // 新用户（从未关联过）：有宠物则引导选择
            if !petViewModel.pets.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if selectedPet == nil { showPetSelector = true }
                }
            }
            return
        }
        if let pet = petViewModel.pets.first(where: { $0.petId == savedId }) {
            selectedPet = pet
            viewModel.onPetSelected(pet)
            maybeShowSwitchHint()
        } else if !petViewModel.pets.isEmpty {
            // 上次关联的宠物已不存在，引导重新选择
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if selectedPet == nil { showPetSelector = true }
            }
        }
    }

    // 仅提示一次：自动关联成功后引导用户如何切换宠物
    private func maybeShowSwitchHint() {
        guard !UserDefaults.standard.bool(forKey: EmergencyChatView.petSwitchHintShownKey) else { return }
        UserDefaults.standard.set(true, forKey: EmergencyChatView.petSwitchHintShownKey)
        showSwitchHint = true
    }

    private func dismissSwitchHint() {
        showSwitchHint = false
        // 关闭即视为已读，后续进入不再提示
        UserDefaults.standard.set(true, forKey: EmergencyChatView.petSwitchHintShownKey)
    }

    private func dismissDisclaimer() {
        showDisclaimer = false
        // 关闭即视为已读，后续进入不再展示
        UserDefaults.standard.set(true, forKey: EmergencyChatView.disclaimerDismissedKey)
    }

    // MARK: - 宠物选择

    private var petSelectorSheet: some View {
        NavigationStack {
            List {
                if petViewModel.pets.isEmpty {
                    Text("emergency_no_pets")
                        .font(PFFonts.body)
                        .foregroundColor(PFColors.textTertiary)
                } else {
                    ForEach(petViewModel.pets) { pet in
                        Button(action: {
                            selectedPet = pet
                            viewModel.onPetSelected(pet)
                            UserDefaults.standard.set(pet.petId, forKey: EmergencyChatView.lastLinkedPetIdKey)
                            showPetSelector = false
                        }) {
                            HStack {
                                if let url = pet.avatarUrl {
                                    CachedAsyncImage(url: url) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Circle().fill(PFColors.surfaceSecondary)
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(PFGradients.brand.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: "pawprint.fill")
                                                .foregroundColor(PFColors.primary)
                                        )
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pet.name)
                                        .font(PFFonts.headline)
                                        .foregroundColor(PFColors.textPrimary)
                                    if let breed = pet.breed {
                                        Text(breed)
                                            .font(PFFonts.caption)
                                            .foregroundColor(PFColors.textSecondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("emergency_link_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_close") { showPetSelector = false }
                }
            }
        }
    }

    // MARK: - 语音输入（WeChat 风格：按住说话，松开发送，上滑取消）

    // MARK: - 结束录音并发送（松手或到达 5 分钟上限时复用）

    private func finishVoiceRecording() {
        guard let url = recorder.stop() else {
            // 录音不足 1 秒，直接取消并退出提示模式
            voiceRecording = false
            voiceCancelling = false
            voiceHintMode = false
            return
        }
        voiceRecording = false
        voiceCancelling = false
        voiceHintMode = false
        // 展示输入框「转写中」加载态
        voiceTranscribing = true
        Task {
            await transcribeAndSend(url: url)
        }
    }

    private func transcribeAndSend(url: URL) async {
        defer {
            Task { @MainActor in
                voiceTranscribing = false
                voiceHintMode = false
            }
        }
        do {
            let data = try Data(contentsOf: url)
            let base64 = data.base64EncodedString()
            let result = try await NetworkManager.shared.speechToText(audioBase64: base64, format: "wav")
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                // 语音转写完成后自动直接发送
                await viewModel.send(text: trimmed, quoting: quotedMessage)
                quotedMessage = nil
            }
        } catch {
            print("语音识别/发送失败: \(error.localizedDescription)")
        }
    }

    private var quickActionsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                let quickActions = [
                    NSLocalizedString("emergency_guide_bleeding", comment: ""),
                    NSLocalizedString("emergency_guide_fracture", comment: ""),
                    NSLocalizedString("emergency_guide_poison", comment: ""),
                    NSLocalizedString("emergency_guide_choking", comment: ""),
                ]
                ForEach(quickActions, id: \.self) { action in
                    Button(action: {
                        Task {
                            await viewModel.send(text: action)
                        }
                    }) {
                        Text(action)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.08))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.orange.opacity(0.15), lineWidth: 0.5)
                                    )
                            )
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - 滚动收起键盘
private extension View {
    func pf_dismissKeyboardOnScroll() -> AnyView {
        AnyView(self.scrollDismissesKeyboard(.interactively))
    }
}

// MARK: - 语音录制管理（16kHz 单声道 PCM/WAV，供 ASR 使用）

@MainActor
final class AudioRecorderManager: ObservableObject {
    @Published var isRecording = false
    @Published var elapsed: TimeInterval = 0
    @Published var error: String?

    /// 单次录音最大时长（秒），到达后自动停止并发送
    static let maxDuration: TimeInterval = 300

    /// 到达最大时长时回调（参数为已停止并生成的录音文件 URL）
    var onAutoStop: ((URL?) -> Void)?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var startDate: Date?

    private let fileURL: URL = {
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("voice_\(UUID().uuidString).wav")
    }()

    /// 请求麦克风权限（首次会弹出系统授权框）
    func requestPermission() {
        let session = AVAudioSession.sharedInstance()
        if #available(iOS 17.0, *) {
            session.requestRecordPermission { [weak self] granted in
                if !granted { Task { @MainActor in self?.error = NSLocalizedString("voice_permission_denied", comment: "") } }
            }
        } else {
            session.requestRecordPermission { [weak self] granted in
                if !granted { Task { @MainActor in self?.error = NSLocalizedString("voice_permission_denied", comment: "") } }
            }
        }
    }

    func start() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.error = String(format: NSLocalizedString("voice_session_error", comment: ""), error.localizedDescription)
            return
        }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]

        do {
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.record()
            self.recorder = recorder
            self.isRecording = true
            self.startDate = Date()
            self.elapsed = 0
            startTimer()
        } catch {
            self.error = String(format: NSLocalizedString("voice_start_error", comment: ""), error.localizedDescription)
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                guard let start = self.startDate else { return }
                self.elapsed = Date().timeIntervalSince(start)
                if self.elapsed >= Self.maxDuration {
                    // 到达 5 分钟上限：停止计时并交由外部统一停止、发送
                    self.timer?.invalidate()
                    self.timer = nil
                    self.onAutoStop?(nil)
                }
            }
        }
    }

    /// 停止录音并返回录制文件 URL；录音不足 1 秒视为过短，返回 nil
    func stop() -> URL? {
        guard let recorder = recorder, isRecording else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        isRecording = false
        timer?.invalidate()
        timer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if duration < 1.0 {
            return nil
        }
        return fileURL
    }

    func cancel() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        timer?.invalidate()
        timer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
