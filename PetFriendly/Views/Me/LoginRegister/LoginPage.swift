//
//  LoginPage.swift
//  PetFriendly
//
//  登录页（极致美化版 - 类似 X 风格极简设计）
//

import SwiftUI
import AudioToolbox

struct LoginPage: View {
    @Environment(\.dismiss) var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var captchaCode = ""
    @State private var captchaUuid = ""
    
    @State private var showFindPwd = false
    @State private var showRegister = false
    @State private var loadingDotScale: [CGFloat] = [1.0, 1.0, 1.0]
    @State private var loading = false
    @FocusState private var activeField: Field?
    @State private var usePasswordLogin = false
    @State private var useTelegramLogin = false
    @State private var tgCode = ""
    @State private var isSendingTgCode = false
    @State private var tgCountdown = 0
    /// 验证码输入框的验证反馈（绿=通过，红=错误）；仅验证码登录/TG 登录模式使用
    @State private var codeFeedback: VerifyFeedback = .idle
    
    enum Field {
        case username, password, captcha
    }
    
    enum AccountType {
        case regular, mobile, email
    }
    
    @State private var accountType: AccountType = .regular
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                PFColors.background.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 30) {
                        
                        // X 风格特色：居中的 Logo
                        HStack {
                            Spacer()
                            Image("PetLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .cornerRadius(16)
                                .pfElevatedShadow()
                                .padding(.top, 40)
                            Spacer()
                        }
                        
                        // 大字标题
                        Text("login_title")
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .foregroundColor(PFColors.textPrimary)
                            .padding(.top, 20)
                        
                        // 错误提示统一走全局 ToastView，不在 UI 内联红字

                        // 输入表单区
                        VStack(spacing: 20) {
                            PFTextField(placeholder: NSLocalizedString("login_username_placeholder", comment: ""), text: $username, isSecure: false, icon: "person")
                                .focused($activeField, equals: .username)
                                .textContentType(.username)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .onChange(of: username) { newValue in
                                    updateAccountType(newValue)
                                }
                            
                            if useTelegramLogin {
                                // Telegram 验证码输入与获取按钮
                                HStack(spacing: 12) {
                                    PFTextField(placeholder: NSLocalizedString("login_tg_code_placeholder", comment: ""), text: $tgCode, isSecure: false, verifyFeedback: codeFeedback)
                                        .focused($activeField, equals: .captcha)
                                        .keyboardType(.asciiCapable)
                                        .autocapitalization(.none)
                                    
                                    Button(action: {
                                        Task { await sendTgCode() }
                                    }) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(isSendingTgCode ? PFColors.surfaceSecondary : PFColors.primary)
                                                .frame(width: 110, height: 48)
                                            
                                            if isSendingTgCode {
                                                PFPetLoadingInline(size: 14)
                                            } else {
                                                Text(tgCountdown > 0 ? "\(tgCountdown)s" : NSLocalizedString("login_get_tg_code", comment: ""))
                                                    .font(PFFonts.callout)
                                                    .foregroundColor(isSendingTgCode ? .clear : (tgCountdown > 0 ? PFColors.textTertiary : PFColors.background))
                                            }
                                        }
                                    }
                                    .disabled(isSendingTgCode || tgCountdown > 0 || username.isEmpty)
                                }
                            } else if accountType == .regular || usePasswordLogin {
                                PFTextField(placeholder: NSLocalizedString("login_password_placeholder", comment: ""), text: $password, isSecure: true, icon: "lock")
                                    .focused($activeField, equals: .password)
                                    .textContentType(.password)
                            } else {
                                // 验证码输入与获取按钮
                                HStack(spacing: 12) {
                                    PFTextField(placeholder: NSLocalizedString("login_captcha_placeholder", comment: ""), text: $captchaCode, isSecure: false, verifyFeedback: codeFeedback)
                                        .focused($activeField, equals: .captcha)
                                        .keyboardType(.asciiCapable)
                                        .autocapitalization(.none)
                                    
                                    Button(action: {
                                        Task { await sendSmsCode() }
                                    }) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(isSendingCode ? PFColors.surfaceSecondary : PFColors.textPrimary)
                                                .frame(width: 110, height: 48)
                                            
                                            if isSendingCode {
                                                PFPetLoadingInline(size: 14)
                                            } else {
                                                Text(countdown > 0 ? "\(countdown)s" : NSLocalizedString("login_get_code", comment: ""))
                                                    .font(PFFonts.callout)
                                                    .foregroundColor(isSendingCode ? .clear : (countdown > 0 ? PFColors.textTertiary : PFColors.background))
                                            }
                                        }
                                    }
                                    .disabled(isSendingCode || countdown > 0 || username.isEmpty)
                                }
                            }
                            
                            // TG 切换按钮
                            Button(action: {
                                withAnimation {
                                    useTelegramLogin.toggle()
                                    if useTelegramLogin {
                                        usePasswordLogin = false
                                    }
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "paperplane.fill")
                                        .font(.caption2)
                                    Text(NSLocalizedString(useTelegramLogin ? "login_use_password" : "login_use_tg", comment: ""))
                                        .font(PFFonts.callout)
                                }
                                .foregroundColor(PFColors.primary)
                            }
                            .padding(.top, 5)
                            
                            // 切换按钮（手机/邮箱验证码 ↔ 密码）
                            if !useTelegramLogin && accountType != .regular {
                                Button(action: { 
                                    withAnimation {
                                        usePasswordLogin.toggle()
                                    }
                                }) {
                                    Text(usePasswordLogin ? NSLocalizedString("login_use_captcha", comment: "") : NSLocalizedString("login_use_password", comment: ""))
                                        .font(PFFonts.callout)
                                        .foregroundColor(PFColors.primary)
                                }
                                .padding(.top, 5)
                            }
                        }
                        .padding(.top, 10)
                        
                        // 登录按钮
                        Button(action: { Task { await login() } }) {
                            Group {
                                if loading {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                        .tint(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                } else {
                                    Text("login_button")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                }
                            }
                            // 使用品牌主色做背景，深浅色模式都保证白字清晰可见，
                            // 避免 textPrimary/background 语义色混用导致深色模式下字体与按钮颜色混淆。
                            .background(
                                (canLogin ? AnyShapeStyle(PFColors.primary) : AnyShapeStyle(PFColors.primary.opacity(0.35)))
                            )
                            .clipShape(Capsule())
                        }
                        .disabled(!canLogin || loading)
                        .padding(.top, 20)
                        
                        // 底部留白（注册/找回密码已移到右上角展开菜单）
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 32)
                }
                
                // 底部动物表情陪伴动画
                VStack {
                    Spacer()
                    AnimalEmojiCompanionView()
                        .frame(height: 570)
                        .clipped()
                }
                .ignoresSafeArea(edges: .bottom)

            }
            .navigationBarTitleDisplayMode(.inline)
            .pfToyBackground()
            .sheet(isPresented: $showFindPwd) {
                FindPwdPage()
            }
            .sheet(isPresented: $showRegister) {
                RegisterView()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(PFColors.textPrimary)
                    }
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                }
                // 右上角：注册 / 找回密码 入口，点击展开选项选择进入
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showRegister = true
                        } label: {
                            Label("login_register", systemImage: "person.badge.plus")
                        }
                        Button {
                            showFindPwd = true
                        } label: {
                            Label("login_forgot_password", systemImage: "key")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(PFColors.primary)
                    }
                }
            }
            .onDisappear {
                smsTimer?.invalidate()
                smsTimer = nil
                tgTimer?.invalidate()
                tgTimer = nil
            }
            // 短信/邮箱验证码满 6 位自动触发登录（类 Tg 验证码自动验证）
            .onChange(of: captchaCode) { newValue in
                // 用户重新输入时清除验证反馈
                if codeFeedback != .idle, newValue.count < 6 { codeFeedback = .idle }
                if newValue.count == 6, !loading, !useTelegramLogin, !usePasswordLogin {
                    Task { await login() }
                }
            }
            // Telegram 验证码满 6 位自动触发登录
            .onChange(of: tgCode) { newValue in
                // 用户重新输入时清除验证反馈
                if codeFeedback != .idle, newValue.count < 6 { codeFeedback = .idle }
                if newValue.count == 6, !loading, useTelegramLogin {
                    Task { await login() }
                }
            }
        }
    }
    
    // MARK: - Logic
    
    private var canLogin: Bool {
        if useTelegramLogin {
            return !username.isEmpty && !tgCode.isEmpty
        } else if accountType == .regular || usePasswordLogin {
            return !username.isEmpty && !password.isEmpty
        } else {
            return !username.isEmpty && !captchaCode.isEmpty
        }
    }
    
    private func updateAccountType(_ val: String) {
        if val.contains("@") {
            accountType = .email
        } else if val.count == 11 && val.allSatisfy({ $0.isNumber }) {
            accountType = .mobile
        } else {
            accountType = .regular
        }
    }
    
    // 隐藏图形验证码后端交互，通过背景悄悄拿到 uuid 即可，表面是在请求短信验证码
    @State private var isSendingCode = false
    @State private var countdown = 0
    @State private var smsTimer: Timer?
    @State private var tgTimer: Timer?
    
    private func sendSmsCode() async {
        isSendingCode = true
        do {
            let (uuid, _) = try await AuthService.shared.fetchCaptcha()
            await MainActor.run {
                self.captchaUuid = uuid
                self.isSendingCode = false
                self.startCountdown()
                // 根据需求模拟验证码
                showSuccessHUD(message: NSLocalizedString("login_captcha_sent", comment: ""))
            }
        } catch {
            await MainActor.run {
                self.isSendingCode = false
                UIState.shared.showToast(NSLocalizedString("login_captcha_fail", comment: ""), style: .error)
            }
        }
    }
    
    private func startCountdown() {
        countdown = 60
        smsTimer?.invalidate()
        smsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            if self.countdown > 0 {
                self.countdown -= 1
            } else {
                t.invalidate()
                self.smsTimer = nil
            }
        }
    }
    
    private func startTgCountdown() {
        tgCountdown = 60
        tgTimer?.invalidate()
        tgTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            if self.tgCountdown > 0 {
                self.tgCountdown -= 1
            } else {
                t.invalidate()
                self.tgTimer = nil
            }
        }
    }
    
    private func sendTgCode() async {
        isSendingTgCode = true
        do {
            try await AuthService.shared.sendTelegramCode(username: username)
            await MainActor.run {
                self.isSendingTgCode = false
                startTgCountdown()
                showSuccessHUD(message: NSLocalizedString("login_tg_code_sent", comment: ""))
            }
        } catch {
            await MainActor.run {
                self.isSendingTgCode = false
                UIState.shared.showToast(error.localizedDescription, style: .error)
            }
        }
    }
    
    private func login() async {
        loading = true

        defer { loading = false }
        do {
            if useTelegramLogin {
                try await AuthService.shared.login(
                    username: username,
                    password: password,
                    code: tgCode,
                    uuid: captchaUuid,
                    grantType: "telegram",
                    telegramCode: tgCode)
            } else {
                try await AuthService.shared.login(username: username, password: password, code: captchaCode, uuid: captchaUuid)
            }
            // 验证码模式：绿描边反馈 → 0.5s 后关闭
            if useTelegramLogin || !usePasswordLogin {
                codeFeedback = .success
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            dismiss()
        } catch {
            // 登录失败统一走全局 ToastView 错误通知，不在 UI 内联红字
            UIState.shared.showToast(error.localizedDescription, style: .error)
            // 失败时清空 uuid 要求重新发验证码
            captchaUuid = ""
            // 验证码模式：红描边反馈 → 0.5s 后清空验证码（要求重新输入）
            if useTelegramLogin || !usePasswordLogin {
                codeFeedback = .error
                try? await Task.sleep(nanoseconds: 500_000_000)
                if useTelegramLogin {
                    tgCode = ""
                } else {
                    captchaCode = ""
                }
                codeFeedback = .idle
            }
        }
    }
}

// MARK: - Animal Emoji Companion View

struct AnimalEmojiCompanionView: View {
    let animals = ["🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🐧", "🐦", "🐤", "🦆", "🦅", "🦉", "🦇", "🐺", "🐗", "🐴", "🦄", "🐝", "🐛", "🦋", "🐌", "🐞", "🐜", "🐢", "🐍", "🦎", "🦖", "🦕", "🐙", "🦑", "🦐", "🦞", "🦀", "🐡", "🐠", "🐟", "🐬", "🐳", "🐋", "🦈", "🐊", "🐅", "🐆", "🦓", "🦍", "🦧", "🐘", "🦛", "🦏", "🐪", "🐫", "🦒", "🦘", "🐃", "🐂", "🐄", "🐎", "🐖", "🐏", "🐑", "🦙", "🐐", "🦌", "🐕", "🐩", "🦮", "🐕‍🦺", "🐈", "🐈‍⬛", "🐓", "🦃", "🦚", "🦜", "🦢", "🦩", "🕊️", "🐇", "🦝", "🦨", "🦡", "🦫", "🦦", "🦥", "🐁", "🐀", "🐿", "🦔"]
    
    @State private var emojis: [EmojiModel] = []
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(emojis) { emoji in
                    SingleEmojiView(model: emoji, screenWidth: geo.size.width)
                        .position(x: 0, y: geo.size.height - emoji.size / 2 - emoji.yOffset)
                }
            }
        }
        .onAppear {
            setupEmojis()
        }
    }
    
    private func setupEmojis() {
        var newEmojis: [EmojiModel] = []
        let count = Int.random(in: 20...40) // 超多动物
        for _ in 0..<count {
            let size = CGFloat.random(in: 30...65) // 整体放大，原来是15...45
            let hasDelay = Bool.random()
            let delay = hasDelay ? Double.random(in: 1...3) : 0 // 停在原地超过三秒后移动
            
            // 速度只有 1-3 个等级，大幅放慢
            let speedLevel = Int.random(in: 1...3)
            let speed = CGFloat(speedLevel * 8) // 等级1: 8, 等级2: 16, 等级3: 24 (进一步降速)
            
            let model = EmojiModel(
                emoji: animals.randomElement() ?? "🐶",
                size: size,
                initialX: CGFloat.random(in: 0...PFScreen.width),
                yOffset: CGFloat.random(in: 0...150), // 高低分布
                isMovingRight: Bool.random(),
                delay: delay,
                speed: speed,
                hasJumpAnimation: Bool.random()
            )
            newEmojis.append(model)
        }
        // 按照 yOffset 降序排列，yOffset 越小（越靠底部）的元素越晚渲染，从而层级最高
        emojis = newEmojis.sorted(by: { $0.yOffset > $1.yOffset })
    }
}

struct EmojiModel: Identifiable {
    let id = UUID()
    let emoji: String
    let size: CGFloat
    let initialX: CGFloat
    let yOffset: CGFloat
    let isMovingRight: Bool
    let delay: Double
    let speed: CGFloat
    let hasJumpAnimation: Bool
}

struct JumpWrapper: View {
    let emoji: String
    let size: CGFloat
    let hasJumpAnimation: Bool
    
    @State private var jumpOffset: CGFloat = 0
    
    // Tap animation states
    @State private var tapScale: CGFloat = 1.0
    @State private var burstScale: CGFloat = 0.1
    @State private var burstOpacity: Double = 0.0
    
    // Random burst states
    @State private var starCount: Int = 0
    @State private var starAngles: [Double] = []
    @State private var starSpins: [Double] = []
    
    var body: some View {
        ZStack {
            // Star burst effect
            ForEach(0..<starCount, id: \.self) { i in
                Text("⭐️")
                    .font(.system(size: max(10, size * 0.4)))
                    .rotationEffect(.degrees(starSpins.indices.contains(i) ? starSpins[i] : 0)) // Star's own spin
                    .offset(y: -size * 0.8 * burstScale) // Expand outward
                    .rotationEffect(.degrees(starAngles.indices.contains(i) ? starAngles[i] : 0)) // Direction
            }
            .opacity(burstOpacity)
            
            // Emoji
            Text(emoji)
                .font(.system(size: size))
                .scaleEffect(tapScale)
        }
        .offset(y: jumpOffset)
        .contentShape(Rectangle()) // Make the whole area tappable
        .onTapGesture {
            handleTap()
        }
        .onAppear {
            if hasJumpAnimation {
                let jumpDuration = Double.random(in: 0.3...0.5)
                withAnimation(.easeInOut(duration: jumpDuration).repeatForever(autoreverses: true)) {
                    jumpOffset = -size * 0.15
                }
            }
        }
    }
    
    private func handleTap() {
        // Play sound and haptics
        let soundIDs: [SystemSoundID] = [1104, 1105, 1306, 1123] // Pop, Tink, Click, etc.
        if let soundID = soundIDs.randomElement() {
            AudioServicesPlaySystemSound(soundID)
        }
        // Haptics.play(.soft, intensity: 0.5)
        
        // Reset animations instantly
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            tapScale = 1.4
            burstScale = 0.1
            burstOpacity = 1.0
            
            starCount = Int.random(in: 3...5)
            starAngles = (0..<starCount).map { _ in Double.random(in: 0..<360) }
            starSpins = Array(repeating: 0.0, count: starCount)
        }
        
        // Trigger elastic bounce and burst fade
        withAnimation(.spring(response: 0.4, dampingFraction: 0.4)) {
            tapScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.5)) {
            burstScale = 1.5
            burstOpacity = 0.0
            // Random spin 180 to 360 degrees for each star
            starSpins = (0..<starCount).map { _ in Double.random(in: 180...360) * (Bool.random() ? 1 : -1) }
        }
    }
}

struct SingleEmojiView: View {
    let model: EmojiModel
    let screenWidth: CGFloat
    
    @State private var currentX: CGFloat
    @State private var isMoving = false
    @State private var isFlipped: Bool
    
    init(model: EmojiModel, screenWidth: CGFloat) {
        self.model = model
        self.screenWidth = screenWidth
        self._currentX = State(initialValue: model.initialX)
        self._isFlipped = State(initialValue: model.isMovingRight)
    }
    
    var body: some View {
        JumpWrapper(emoji: model.emoji, size: model.size, hasJumpAnimation: model.hasJumpAnimation)
            .scaleEffect(x: isFlipped ? -1 : 1, y: 1) // Face direction
            .offset(x: currentX)
            .onAppear {
                let actualDelay = max(0.1, model.delay)
                DispatchQueue.main.asyncAfter(deadline: .now() + actualDelay) {
                    startMoving()
                }
            }
    }
    
    private func startMoving() {
        guard !isMoving else { return }
        isMoving = true
        moveOnce()
    }
    
    private func moveOnce() {
        let endX = model.isMovingRight ? screenWidth + model.size * 2 : -model.size * 2
        let distance = abs(endX - currentX)
        let moveDuration = Double(distance / model.speed)
        
        withAnimation(.linear(duration: moveDuration)) {
            currentX = endX
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + moveDuration) {
            // Once reached edge, teleport to opposite edge with NO animation
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                currentX = model.isMovingRight ? -model.size * 2 : screenWidth + model.size * 2
            }
            
            // Wait slightly for the layout change to apply, then start moving again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                moveOnce()
            }
        }
    }
}
