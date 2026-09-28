import SwiftUI

struct AIAIAvatarView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTab = 0 // 0: 新建生成, 1: 历史记录
    
    // 生成相关状态
    @State private var showImagePicker = false
    @State private var inputImage: UIImage? = nil
    @State private var generatedImageUrl: String? = nil
    @State private var isProcessing = false   // 生成中（展示生成动画）
    @State private var isUploading = false    // 上传中（交由系统统一上传弹窗处理）
    @State private var isGenerating = false   // 任务生成中（历史页异步展示"生成中"）
    @State private var progressText = NSLocalizedString("prog_parse_face", comment: "")
    
    // 历史相关状态
    @State private var historyItems: [AIPortraitHistoryItem] = []
    @State private var isLoadingHistory = false
    
    // 查看大图详情相关
    @State private var selectedHistoryItem: AIPortraitHistoryItem? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                PFColors.background.ignoresSafeArea()
                
                // 未来感光晕背景
                RadialGradient(colors: [PFColors.primary.opacity(0.16), .clear], center: .topLeading, startRadius: 0, endRadius: 420)
                    .ignoresSafeArea()
                RadialGradient(colors: [PFColors.accent.opacity(0.12), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 420)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 自定义顶部栏
                    headerBar
                    
                    // Tab 切换按钮
                    tabSelector
                        .padding(.horizontal, PFSpacing.xl)
                        .padding(.bottom, PFSpacing.lg)
                    
                    if selectedTab == 0 {
                        // 新建生成 Tab
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: PFSpacing.xl) {
                    if isProcessing {
                        processingView()
                    } else if isUploading {
                        // 上传阶段交由系统统一的上传弹窗处理，此处不再展示自定义上传进度界面
                        Color.clear.frame(height: 320)
                    } else if let resultUrl = generatedImageUrl {
                                    resultView(url: resultUrl)
                                } else {
                                    uploadArea()
                                }
                            }
                            .padding(.horizontal, PFSpacing.xl)
                            .padding(.bottom, 40)
                        }
                    } else {
                        // 历史记录 Tab
                        historyView
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationBarHidden(true)
            .sheet(item: $selectedHistoryItem) { item in
                historyDetailView(item: item)
            }
        }
        .onAppear {
            fetchHistory()
        }
    }
    
    // MARK: - UI Components
    
    private var headerBar: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(PFColors.textPrimary)
                        .padding(8)
                        .background(PFColors.surfaceSecondary)
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text(NSLocalizedString("ai_cert_title", comment: ""))
                    .font(PFFonts.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(PFGradients.brand)
                    .shadow(color: PFColors.primary.opacity(0.3), radius: 8, x: 0, y: 2)
                
                Spacer()
                
                Circle()
                    .fill(Color.clear)
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal, PFSpacing.xl)
            .padding(.top, 50)
            .padding(.bottom, PFSpacing.sm)
            
            // 未来感装饰线
            HStack(spacing: 0) {
                Rectangle()
                    .fill(PFGradients.brandHorizontal)
                    .frame(width: 64, height: 3)
                    .cornerRadius(1.5)
                Spacer()
            }
            .padding(.horizontal, PFSpacing.xl)
            .padding(.bottom, PFSpacing.md)
        }
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            Button(action: { selectedTab = 0 }) {
                Text(NSLocalizedString("new_gen", comment: ""))
                    .font(PFFonts.subheadline)
                    .fontWeight(selectedTab == 0 ? .bold : .regular)
                    .foregroundColor(selectedTab == 0 ? .white : PFColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedTab == 0 ? PFGradients.brand : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom))
                    .cornerRadius(10)
            }
            
            Button(action: { 
                selectedTab = 1
                fetchHistory()
            }) {
                Text(NSLocalizedString("gen_history", comment: ""))
                    .font(PFFonts.subheadline)
                    .fontWeight(selectedTab == 1 ? .bold : .regular)
                    .foregroundColor(selectedTab == 1 ? .white : PFColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedTab == 1 ? PFGradients.brand : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom))
                    .cornerRadius(10)
            }
        }
        .padding(4)
        .background(PFColors.surfaceSecondary)
        .cornerRadius(12)
    }
    
    // MARK: - Generation Tab Views
    
    private func uploadArea() -> some View {
        VStack(spacing: PFSpacing.xl) {
            VStack(spacing: 8) {
                Text(NSLocalizedString("ai_engine", comment: ""))
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(PFColors.primary.opacity(0.1))
                    .clipShape(Capsule())
                
                Text(NSLocalizedString("gen_cert_desc", comment: ""))
                    .font(PFFonts.title2)
                    .fontWeight(.bold)
                    .foregroundColor(PFColors.textPrimary)
                
                Text(NSLocalizedString("ai_avatar_cost", comment: ""))
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textSecondary)
            }
            .padding(.top, PFSpacing.md)
            
            Button { showImagePicker = true } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: PFRadius.lg)
                        .fill(PFColors.surface.opacity(0.45))
                        .frame(height: 280)
                    RoundedRectangle(cornerRadius: PFRadius.lg)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                        .foregroundColor(PFColors.primary.opacity(0.65))
                        .frame(height: 280)
                        .shadow(color: PFColors.primary.opacity(0.35), radius: 10)
                        
                    if let img = inputImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: PFRadius.lg))
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 44))
                                .foregroundColor(PFColors.primary)
                            Text(NSLocalizedString("pick_clear_photo", comment: ""))
                                .font(PFFonts.callout)
                                .foregroundColor(PFColors.textSecondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showImagePicker) { ImagePicker(image: $inputImage) }
            
            PFButton("start_gen_cert", icon: "wand.and.stars") {
                startGeneration()
            }
            .disabled(inputImage == nil)
        }
    }
    
    private func processingView() -> some View {
        VStack(spacing: PFSpacing.xl) {
            Spacer().frame(height: 24)
            
            // 未来感加载器：多层旋转光环 + 脉冲核心
            ZStack {
                Circle()
                    .trim(from: 0.05, to: 0.45)
                    .stroke(
                        AngularGradient(colors: [PFColors.primary, .clear, PFColors.accent, .clear], center: .center),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 132, height: 132)
                    .rotationEffect(Angle(degrees: isProcessing ? 360 : 0))
                    .animation(Animation.linear(duration: 2.4).repeatForever(autoreverses: false), value: isProcessing)
                
                Circle()
                    .trim(from: 0.1, to: 0.6)
                    .stroke(
                        AngularGradient(colors: [PFColors.accent, .clear, PFColors.primary, .clear], center: .center),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 98, height: 98)
                    .rotationEffect(Angle(degrees: isProcessing ? -360 : 0))
                    .animation(Animation.linear(duration: 1.6).repeatForever(autoreverses: false), value: isProcessing)
                
                ZStack {
                    Circle()
                        .fill(PFGradients.brand)
                        .frame(width: 56, height: 56)
                        .shadow(color: PFColors.primary.opacity(0.5), radius: 12)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(isProcessing ? 1.08 : 1.0)
                .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isProcessing)
            }
            
            VStack(spacing: 6) {
                Text(progressText)
                    .font(PFFonts.headline)
                    .foregroundColor(PFColors.textPrimary)
                    .multilineTextAlignment(.center)
                Text(NSLocalizedString("ai_making", comment: ""))
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    /// 上传阶段视图已移除：上传进度交由系统统一弹窗处理
    
    private func resultView(url: String) -> some View {
        VStack(spacing: PFSpacing.xl) {
            Text(NSLocalizedString("cert_success", comment: ""))
                .font(PFFonts.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.green)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
            
            // 对比展示原始图 & 生成图
            HStack(spacing: PFSpacing.md) {
                VStack(spacing: 8) {
                    Text(NSLocalizedString("orig_upload_img", comment: ""))
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textSecondary)
                    
                    if let img = inputImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 190)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 5)
                    }
                    
                    PFButton("dl_original", icon: "square.and.arrow.down", isOutline: true) {
                        if let img = inputImage {
                            UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                            showSuccessHUD(message: NSLocalizedString("orig_saved", comment: ""))
                        }
                    }
                    .frame(height: 36)
                }
                
                VStack(spacing: 8) {
                    Text(NSLocalizedString("ai_gen_cert", comment: ""))
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textSecondary)
                    
                    CachedAsyncImage(url: URL(string: url)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 190)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: PFColors.primary.opacity(0.3), radius: 8)
                            .overlay(alignment: .bottomTrailing) {
                                Text("ai_generated_label")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Capsule())
                                    .padding(6)
                            }
                    } placeholder: {
                        ProgressView()
                            .frame(width: 140, height: 190)
                            .background(PFColors.surfaceSecondary)
                            .cornerRadius(12)
                    }
                    
                    PFButton("dl_cert", icon: "square.and.arrow.down") {
                        saveImageToAlbum(urlStr: url)
                    }
                    .frame(height: 36)
                }
            }
            .padding(.vertical, 8)
            
            PFButton("regen", icon: "arrow.counterclockwise", isOutline: true) {
                generatedImageUrl = nil
                inputImage = nil
            }
            .padding(.top, 16)
        }
    }
    
    // MARK: - History Tab View
    
    private var historyView: some View {
        Group {
            if isLoadingHistory {
                VStack {
                    Spacer()
                    ProgressView("loading_history")
                    Spacer()
                }
            } else if historyItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(PFColors.textTertiary)
                    Text(NSLocalizedString("no_history", comment: ""))
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textSecondary)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    if isGenerating {
                        pendingHistoryCard
                            .padding(.horizontal, PFSpacing.lg)
                            .padding(.vertical, 6)
                    }
                    List(historyItems) { item in
                        Button(action: { selectedHistoryItem = item }) {
                            HStack(spacing: PFSpacing.md) {
                                // 两个小缩略图对比
                                HStack(spacing: 4) {
                                    CachedAsyncImage(url: URL(string: item.originalUrl)) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        Rectangle().fill(PFColors.surfaceSecondary)
                                    }
                                    .frame(width: 50, height: 65)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                        .foregroundColor(PFColors.textTertiary)
                                    
                                    CachedAsyncImage(url: URL(string: item.generatedUrl)) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        Rectangle().fill(PFColors.surfaceSecondary)
                                    }
                                    .frame(width: 50, height: 65)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(NSLocalizedString("ai_cert_title", comment: ""))
                                        .font(PFFonts.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(PFColors.textPrimary)
                                    
                                    Text(item.createTime)
                                        .font(PFFonts.caption2)
                                        .foregroundColor(PFColors.textTertiary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(PFColors.textTertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(PFColors.surface)
                    }
                    .listStyle(PlainListStyle())
                }
            }
        }
    }
    
    /// 生成中的占位卡片（支持提交任务后异步查看生成历史）
    private var pendingHistoryCard: some View {
        HStack(spacing: PFSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(PFColors.surfaceSecondary)
                    .frame(width: 50, height: 65)
                ProgressView()
                    .tint(PFColors.primary)
                    .scaleEffect(0.8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("ai_cert_title", comment: ""))
                    .font(PFFonts.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(PFColors.textPrimary)
                
                HStack(spacing: 4) {
                    ProgressView()
                        .tint(PFColors.primary)
                        .scaleEffect(0.6)
                    Text(NSLocalizedString("generating", comment: ""))
                        .font(PFFonts.caption2)
                        .foregroundColor(PFColors.primary)
                }
            }
            
            Spacer()
        }
        .padding(PFSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PFRadius.md)
                .fill(PFColors.surface.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: PFRadius.md).stroke(PFColors.primary.opacity(0.3), lineWidth: 1))
        )
    }
    
    // MARK: - History Detail Sheet
    
    private func historyDetailView(item: AIPortraitHistoryItem) -> some View {
        NavigationStack {
            ZStack {
                PFColors.background.ignoresSafeArea()
                
                VStack(spacing: PFSpacing.xxl) {
                    Text(NSLocalizedString("cert_detail", comment: ""))
                        .font(PFFonts.title2)
                        .fontWeight(.bold)
                        .foregroundColor(PFColors.textPrimary)
                        .padding(.top, PFSpacing.xl)
                    
                    HStack(spacing: PFSpacing.lg) {
                        VStack(spacing: 8) {
                            Text(NSLocalizedString("orig_img", comment: ""))
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.textSecondary)
                            
                            CachedAsyncImage(url: URL(string: item.originalUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 140, height: 190)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(radius: 4)
                            } placeholder: {
                                ProgressView()
                                    .frame(width: 140, height: 190)
                            }
                            
                            PFButton("dl_original", icon: "square.and.arrow.down", isOutline: true) {
                                saveImageToAlbum(urlStr: item.originalUrl)
                            }
                            .frame(height: 36)
                        }
                        
                        VStack(spacing: 8) {
                            Text(NSLocalizedString("gen_cert_img", comment: ""))
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.textSecondary)
                            
                            CachedAsyncImage(url: URL(string: item.generatedUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 140, height: 190)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(radius: 6)
                            } placeholder: {
                                ProgressView()
                                    .frame(width: 140, height: 190)
                            }
                            
                            PFButton("dl_cert", icon: "square.and.arrow.down") {
                                saveImageToAlbum(urlStr: item.generatedUrl)
                            }
                            .frame(height: 36)
                        }
                    }
                    
                    Text(String(format: NSLocalizedString("gen_time", comment: ""), item.createTime))
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textTertiary)
                    
                    Spacer()
                }
                .padding(.horizontal, PFSpacing.xl)
            }
            .navigationBarItems(leading: Button("common_close") { selectedHistoryItem = nil })
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Logic
    
    /// 将图片缩放到最长边不超过 maxDimension，避免原图分辨率过大导致上传 base64 超出服务端请求体上限（413）
    private func resizedImage(_ image: UIImage, maxDimension: CGFloat = 1024) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    private func startGeneration() {
        guard let img = inputImage else { return }
        // 先缩放（证件照无需原图分辨率），再上传到对象存储，由后端取流生成
        let scaled = resizedImage(img, maxDimension: 1024)
        
        isUploading = true
        isProcessing = false
        isGenerating = true
        progressText = NSLocalizedString("prog_prepare_img", comment: "")
        
        Task {
            do {
                await MainActor.run { progressText = NSLocalizedString("prog_upload_img", comment: "") }
                // 1) 先上传到对象存储，拿到可访问 URL（上传进度交由系统统一弹窗处理）
                let photoUrl = try await NetworkManager.shared.uploadImage(scaled)
                
                // 上传完成，进入生成阶段（展示生成动画，等待后端 AI 生成）
                await MainActor.run {
                    self.isUploading = false
                    self.isProcessing = true
                    self.progressText = NSLocalizedString("prog_ai_parse", comment: "")
                }
                
                // 2) 把 OSS URL 传给后端，由后端 AI 取流生成证件照（同步返回，最长约 3 分钟）
                let resp: RespWrapper<String> = try await NetworkManager.shared.request(
                    "/petFriendly/client/ai/portrait/generate",
                    method: .post,
                    parameters: ["imageUrl": photoUrl],
                    needToken: true,
                    longTimeout: true
                )
                
                await MainActor.run {
                    self.isUploading = false
                    self.isProcessing = false
                    self.isGenerating = false
                    if let url = resp.data {
                        self.generatedImageUrl = url
                        self.fetchHistory()
                        showSuccessHUD(message: NSLocalizedString("cert_ok_deduct", comment: ""))
                    } else {
                        showErrorAlert(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: resp.msg ?? NSLocalizedString("gen_fail", comment: "")]))
                    }
                }
            } catch {
                await MainActor.run {
                    self.isUploading = false
                    self.isProcessing = false
                    self.isGenerating = false
                    showErrorAlert(error)
                }
            }
        }
    }
    
    private func fetchHistory() {
        isLoadingHistory = true
        Task {
            do {
                let resp: RespWrapper<[AIPortraitHistoryItem]> = try await NetworkManager.shared.request(
                    "/petFriendly/client/ai/portrait/history",
                    method: .get,
                    needToken: true
                )
                await MainActor.run {
                    self.isLoadingHistory = false
                    if let items = resp.data {
                        self.historyItems = items
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoadingHistory = false
                    print("加载生图历史失败: \(error)")
                }
            }
        }
    }
    
    private func saveImageToAlbum(urlStr: String) {
        guard let url = URL(string: urlStr) else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                        showSuccessHUD(message: NSLocalizedString("img_saved_album", comment: ""))
                    }
                }
            } catch {
                await MainActor.run {
                    showErrorAlert(error)
                }
            }
        }
    }
}
