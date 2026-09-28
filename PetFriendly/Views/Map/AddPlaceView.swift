import SwiftUI
import MapKit

struct AddPlaceView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var uiState: UIState
    var initialCoordinate: CLLocationCoordinate2D?

    // 表单状态
    @State private var step = 0
    @State private var name = ""
    @State private var address = ""
    @State private var typeIndex: Int? = nil
    @State private var placeLevel: Int = 3 // 默认“一般”
    @State private var description = ""
    @State private var personalRating: Int = 3 // 1-5 星个人评分
    @State private var selectedImage: UIImage?
    @State private var uploadedImageUrl: String?

    // AI 识别状态
    @State private var isAnalyzing = false
    @State private var aiDescription: String?
    @State private var aiAnalysisDone = false

    // UI 控制
    @State private var isPickerPresented = false
    @State private var isLoading = false
    @State private var hasRestoredDraft = false

    let types = ["place_type_park", "place_type_hospital", "place_type_restaurant", "place_type_water", "place_type_lawn", "place_type_square", "place_type_police", "place_type_photo", "place_type_grooming", "place_type_boarding"]
    let levels = ["place_level_vfriendly", "place_level_friendly", "place_level_average", "place_level_unfriendly", "place_level_unknown"]
    let totalSteps = 6

    // 初始化时若有经纬度则记录
    @State private var finalCoordinate: CLLocationCoordinate2D?

    var body: some View { navBody }

    // MARK: - 草稿缓存

    private func restoreDraft() {
        guard let draft = PlaceFormDraftManager.load() else { return }
        hasRestoredDraft = true
        step = draft.step
        name = draft.name
        address = draft.address
        typeIndex = draft.typeIndex
        placeLevel = draft.placeLevel
        description = draft.description
        personalRating = draft.personalRating
        uploadedImageUrl = draft.imageUrl
        if let lat = draft.latitude, let lon = draft.longitude {
            finalCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        // 如果有已上传的图片 URL 但无本地图片，标记 AI 分析已完成
        if uploadedImageUrl != nil {
            aiAnalysisDone = true
        }
        print("[Draft] 草稿已恢复: step=\(draft.step)")
    }

    private func autoSaveDraft() {
        let draft = PlaceFormDraft(
            step: step,
            name: name,
            address: address,
            typeIndex: typeIndex,
            placeLevel: placeLevel,
            description: description,
            personalRating: personalRating,
            imageUrl: uploadedImageUrl,
            latitude: finalCoordinate?.latitude,
            longitude: finalCoordinate?.longitude
        )
        PlaceFormDraftManager.save(draft)
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Reverse geocode error: \(error.localizedDescription)")
                return
            }

            if let placemark = placemarks?.first {
                let addr = [
                    placemark.administrativeArea,
                    placemark.locality,
                    placemark.subLocality,
                    placemark.thoroughfare,
                    placemark.subThoroughfare
                ].compactMap { $0 }.joined()

                DispatchQueue.main.async {
                    if !addr.isEmpty {
                        self.address = addr
                    } else if let name = placemark.name {
                        self.address = name
                    }
                }
            }
        }
    }

    // MARK: - 步骤 0：拍照 → 自动上传 → AI 识别

    private func photoStepView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            instructionText("add_place_step_photo")

            // 图片选择区域
            Button(action: { isPickerPresented = true }) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            // 重新拍照按钮
                            VStack {
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        selectedImage = nil
                                        uploadedImageUrl = nil
                                        aiDescription = nil
                                        aiAnalysisDone = false
                                        isPickerPresented = true
                                    }) {
                                        Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                            .padding(10)
                                            .background(Color.black.opacity(0.5))
                                            .clipShape(Circle())
                                    }
                                    .padding(12)
                                }
                                Spacer()
                            }
                        )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 48))
                        Text("add_place_photo_tap")
                            .font(PFFonts.headline)
                        Text("add_place_photo_ai_hint")
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                    .foregroundColor(PFColors.primary)
                    .background(PFColors.primary.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .foregroundColor(PFColors.primary.opacity(0.5))
                    )
                }
            }

            // AI 分析状态
            if isAnalyzing {
                HStack(spacing: 12) {
                    PFPetLoadingView(size: 24)
                    Text("add_place_photo_analyzing")
                        .font(PFFonts.subheadline)
                        .foregroundColor(PFColors.textSecondary)
                }
                .padding(.top, 8)
            } else if aiAnalysisDone, let desc = aiDescription {
                // AI 分析完成，显示预览
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkle.magnifyingglass")
                            .foregroundColor(PFColors.success)
                        Text("add_place_ai_done")
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.success)
                    }
                    Text(desc)
                        .font(PFFonts.body)
                        .foregroundColor(PFColors.textPrimary)
                        .lineLimit(3)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PFColors.success.opacity(0.08))
                        .cornerRadius(12)
                }
            }

            Spacer()
        }
        .padding(24)
        // 监听图片选择 → 自动上传 → AI 识别
        .onChange(of: selectedImage) { newImage in
            guard let image = newImage else { return }
            Task { await uploadAndAnalyze(image: image) }
        }
    }

    @MainActor
    private func uploadAndAnalyze(image: UIImage) async {
        isAnalyzing = true
        aiAnalysisDone = false
        aiDescription = nil

        do {
            // 1. 上传图片
            let url = try await NetworkManager.shared.uploadImage(image) { progress in
                Task { @MainActor in
                    uiState.uploadProgress = progress
                }
            }

            await MainActor.run {
                uploadedImageUrl = url
            }

            // 2. AI 识别图片内容
            let description = try await NetworkManager.shared.aiDescribeImage(imageUrl: url)

            await MainActor.run {
                self.aiDescription = description
                self.description = description
                self.aiAnalysisDone = true
                self.isAnalyzing = false
                Haptics.notify(.success)
            }
        } catch {
            await MainActor.run {
                self.isAnalyzing = false
                self.aiAnalysisDone = true
                print("AI 识别失败: \(error.localizedDescription)")
                // 即使 AI 识别失败也不阻塞流程，用户可以手动填写
                showErrorAlert(error)
            }
        }
    }

    // MARK: - 步骤 1：AI 描述确认 / 修改

    private func aiDescriptionStepView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            instructionText("add_place_step_ai_desc")

            // 显示之前选择的图片小图
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // 描述编辑区域 — 使用统一风格的 PFTextEditor
            PFTextEditor(
                placeholder: "add_place_desc_placeholder",
                text: $description,
                height: 160,
                maxLength: 500
            )

            // 字数和 AI 标记
            HStack {
                if aiAnalysisDone {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(PFColors.success)
                        Text("add_place_ai_generated")
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.success)
                    }
                }
                Spacer()
                Text("\(description.count)/500")
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textTertiary)
            }

            Spacer()
        }
        .padding(24)
    }

    // MARK: - 步骤 2：填写其他信息（名称 + 地址）

    private func infoStepView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            instructionText("add_place_step_info")

            VStack(spacing: 16) {
                // 名称 — 使用统一风格
                VStack(alignment: .leading, spacing: 6) {
                    Text("add_place_name_label")
                        .font(PFFonts.subheadline)
                        .foregroundColor(PFColors.textSecondary)
                    PFTextField(
                        placeholder: NSLocalizedString("add_place_name_placeholder", comment: ""),
                        text: $name,
                        maxLength: 50
                    )
                }

                // 地址 — 使用统一风格
                VStack(alignment: .leading, spacing: 6) {
                    Text("add_place_addr_label")
                        .font(PFFonts.subheadline)
                        .foregroundColor(PFColors.textSecondary)
                    PFTextField(
                        placeholder: NSLocalizedString("add_place_addr_placeholder", comment: ""),
                        text: $address,
                        maxLength: 200
                    )
                }

                // 位置预览
                if let coord = finalCoordinate {
                    Map(coordinateRegion: .constant(MKCoordinateRegion(center: coord, latitudinalMeters: 500, longitudinalMeters: 500)), interactionModes: [])
                        .frame(height: 120)
                        .cornerRadius(16)
                        .overlay(
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(PFColors.danger)
                                .font(.system(size: 24))
                        )
                }
            }

            Spacer()
        }
        .padding(24)
    }

    // MARK: - 步骤 3：类型选择（原步骤）

    private func typeStepView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            instructionText("add_place_step_type")

            ScrollView {
                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(0..<types.count, id: \.self) { index in
                        Button(action: {
                            typeIndex = index
                            Haptics.play()
                        }) {
                            Text(LocalizedStringKey(types[index]))
                                .font(PFFonts.subheadline)
                                .fontWeight(.medium)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity)
                                .background((typeIndex ?? -1) == index ? PFColors.primary.opacity(0.15) : PFColors.surfaceSecondary)
                                .foregroundColor((typeIndex ?? -1) == index ? PFColors.primary : PFColors.textPrimary)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke((typeIndex ?? -1) == index ? PFColors.primary : Color.clear, lineWidth: 2)
                                )
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(24)
    }

    // MARK: - 步骤 4：友好度 + 个人评分

    private func ratingStepView() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 标题
                instructionText("add_place_step_rating")
                    .padding(.horizontal, 24)

                // 友好度选择
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "pawprint.fill")
                            .foregroundColor(PFColors.primary)
                        Text("add_place_step_level")
                            .font(PFFonts.headline)
                            .foregroundColor(PFColors.textPrimary)
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 10) {
                        ForEach(1...5, id: \.self) { lv in
                            Button(action: {
                                placeLevel = lv
                                Haptics.play(.light)
                            }) {
                                HStack {
                                    Image(systemName: levelIcon(lv))
                                        .foregroundColor(placeLevel == lv ? PFColors.primary : PFColors.textTertiary)
                                    Text(LocalizedStringKey(levels[lv-1]))
                                        .font(PFFonts.headline)
                                    Spacer()
                                    if placeLevel == lv {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(PFColors.primary)
                                    }
                                }
                                .padding(16)
                                .background(placeLevel == lv ? PFColors.primary.opacity(0.1) : PFColors.surfaceSecondary)
                                .foregroundColor(placeLevel == lv ? PFColors.primary : PFColors.textPrimary)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(placeLevel == lv ? PFColors.primary : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // 分隔
                Divider()
                    .padding(.horizontal, 24)

                // 个人评分（1-5 星）
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(PFColors.warning)
                        Text("add_place_personal_rating")
                            .font(PFFonts.headline)
                            .foregroundColor(PFColors.textPrimary)
                    }
                    .padding(.horizontal, 24)

                    Text("add_place_personal_rating_hint")
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textSecondary)
                        .padding(.horizontal, 24)

                    // 星星评分组件
                    HStack(spacing: 12) {
                        Spacer()
                        ForEach(1...5, id: \.self) { star in
                            Button(action: {
                                personalRating = star
                                Haptics.play(.light)
                            }) {
                                Image(systemName: star <= personalRating ? "star.fill" : "star")
                                    .font(.system(size: 40))
                                    .foregroundColor(star <= personalRating ? PFColors.warning : PFColors.surfaceSecondary)
                                    .shadow(color: star <= personalRating ? PFColors.warning.opacity(0.3) : .clear, radius: 4)
                                    .scaleEffect(star <= personalRating ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: personalRating)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)

                    // 评分文字标签
                    HStack {
                        Spacer()
                        Text(personalRatingLabel(personalRating))
                            .font(PFFonts.subheadline)
                            .foregroundColor(PFColors.textSecondary)
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 16)
        }
    }

    private func levelIcon(_ lv: Int) -> String {
        switch lv {
        case 1: return "face.smiling.fill"
        case 2: return "face.smiling"
        case 3: return "face.neutral"
        case 4: return "face.dashed"
        case 5: return "face.dashed.fill"
        default: return "face.neutral"
        }
    }

    private func personalRatingLabel(_ rating: Int) -> String {
        switch rating {
        case 1: return NSLocalizedString("rating_terrible", comment: "")
        case 2: return NSLocalizedString("rating_bad", comment: "")
        case 3: return NSLocalizedString("rating_ok", comment: "")
        case 4: return NSLocalizedString("rating_good", comment: "")
        case 5: return NSLocalizedString("rating_great", comment: "")
        default: return ""
        }
    }

    // MARK: - 步骤 5：预览 + 提交

    private func previewStepView() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                instructionText("add_place_step_preview")
                    .padding(.horizontal, 24)

                // 所有信息汇总卡片
                VStack(spacing: 16) {
                    // 图片
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // 信息行
                    previewRow(icon: "mappin", label: "add_place_name_label", value: name)
                    previewRow(icon: "location", label: "add_place_addr_label", value: address)

                    if let tIdx = typeIndex, tIdx < types.count {
                        previewRow(icon: "building.2", label: "add_place_type_label", value: NSLocalizedString(types[tIdx], comment: ""))
                    }

                    previewRow(icon: "pawprint", label: "add_place_level_label", value: NSLocalizedString(levels[placeLevel-1], comment: ""))

                    // 个人评分
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundColor(PFColors.warning)
                            .font(.system(size: 14))
                        Text("add_place_personal_rating")
                            .font(PFFonts.callout)
                            .foregroundColor(PFColors.textSecondary)
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= personalRating ? "star.fill" : "star")
                                    .font(.system(size: 14))
                                    .foregroundColor(star <= personalRating ? PFColors.warning : PFColors.surfaceSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(PFColors.surfaceSecondary)
                    .cornerRadius(14)

                    // 描述
                    if !description.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(PFColors.primary)
                                    .font(.system(size: 14))
                                Text("add_place_desc_label")
                                    .font(PFFonts.callout)
                                    .foregroundColor(PFColors.textSecondary)
                            }
                            Text(description)
                                .font(PFFonts.body)
                                .foregroundColor(PFColors.textPrimary)
                                .lineLimit(5)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PFColors.surfaceSecondary)
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 16)
        }
    }

    private func previewRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(PFColors.primary)
                .font(.system(size: 14))
                .frame(width: 20)
            Text(LocalizedStringKey(label))
                .font(PFFonts.callout)
                .foregroundColor(PFColors.textSecondary)
            Spacer()
            Text(value)
                .font(PFFonts.callout)
                .foregroundColor(PFColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(PFColors.surfaceSecondary)
        .cornerRadius(14)
    }

    // MARK: - Components

    private func instructionText(_ text: String) -> some View {
        Text(LocalizedStringKey(text))
            .font(PFFonts.title2)
            .fontWeight(.bold)
            .foregroundColor(PFColors.textPrimary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var navBody: some View {
        let content = VStack(spacing: 0) {
            PFProgressBar(value: Double(step + 1), total: Double(totalSteps))
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
            GeometryReader { geometry in
                stepBody(step)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            bottomBar()
        }
        let nav = NavigationStack { content }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                        PlaceFormDraftManager.clear()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(PFColors.textSecondary)
                            .font(.system(size: 20, weight: .bold))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .trackScene("AddPlace")
            .navigationTitle("add_place_title")
        return nav
            .sheet(isPresented: $isPickerPresented) {
                ImagePicker(image: $selectedImage)
            }
            .onAppear {
                if !hasRestoredDraft { restoreDraft() }
                if let coord = initialCoordinate {
                    self.finalCoordinate = coord
                    reverseGeocode(coord)
                } else if let vmCoord = MapViewModel.shared.centerCoordinate {
                    self.finalCoordinate = vmCoord
                    reverseGeocode(vmCoord)
                }
            }
            .onChange(of: step) { _ in autoSaveDraft() }
            .onChange(of: name) { _ in autoSaveDraft() }
            .onChange(of: address) { _ in autoSaveDraft() }
            .onChange(of: typeIndex) { _ in autoSaveDraft() }
            .onChange(of: placeLevel) { _ in autoSaveDraft() }
            .onChange(of: description) { _ in autoSaveDraft() }
            .onChange(of: personalRating) { _ in autoSaveDraft() }
            .onChange(of: uploadedImageUrl) { _ in autoSaveDraft() }
    }

    @ViewBuilder
    private func stepBody(_ s: Int) -> some View {
        switch s {
        case 0: AnyView(photoStepView().transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))))
        case 1: AnyView(aiDescriptionStepView().transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))))
        case 2: AnyView(infoStepView().transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))))
        case 3: AnyView(typeStepView().transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))))
        case 4: AnyView(ratingStepView().transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))))
        case 5: AnyView(previewStepView().transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))))
        default: AnyView(EmptyView())
        }
    }

    private func bottomBar() -> some View {
        VStack {
            Divider()
            HStack {
                if step > 0 {
                    Button(action: {
                        withAnimation { step -= 1 }
                    }) {
                        Text("add_pet_back")
                            .font(PFFonts.headline)
                            .foregroundColor(PFColors.textSecondary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(PFColors.surfaceSecondary)
                            .cornerRadius(16)
                    }
                }

                Spacer()

                Button(action: handleNext) {
                    if isLoading {
                        PFPetLoadingInline(size: 14)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(step == totalSteps - 1 ? "form_submit" : "add_pet_next")
                            .font(PFFonts.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!canGoNext() || isLoading)
                .padding(.vertical, 16)
                .padding(.horizontal, step > 0 ? 0 : 24)
                .background(canGoNext() ? PFColors.primary : PFColors.textTertiary.opacity(0.4))
                .foregroundColor(.white)
                .cornerRadius(16)
                .animation(.easeInOut, value: canGoNext())
            }
            .padding(24)
        }
        .background(Color(.systemBackground).edgesIgnoringSafeArea(.bottom))
    }

    // MARK: - Logic

    private func canGoNext() -> Bool {
        switch step {
        case 0: return selectedImage != nil || aiAnalysisDone // 允许 AI 失败后继续
        case 1: return !description.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return !name.trimmingCharacters(in: .whitespaces).isEmpty && !address.trimmingCharacters(in: .whitespaces).isEmpty
        case 3: return typeIndex != nil
        case 4: return true
        case 5: return true // 预览页可直接提交
        default: return false
        }
    }

    private func handleNext() {
        Haptics.play(.light)
        if step < totalSteps - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                step += 1
            }
        } else {
            submitPlace()
        }
    }

    private func submitPlace() {
        guard !isLoading else { return }
        isLoading = true

        Task {
            do {
                var params: [String: Any] = [
                    "name": name,
                    "address": address,
                    "placeLevel": placeLevel,
                    "type": typeIndex ?? 0,
                    "remark": description,
                    "personalRating": personalRating // 新增个人评分
                ]

                if let coord = finalCoordinate {
                    params["longitude"] = coord.longitude
                    params["latitude"] = coord.latitude
                }

                // 上传图片（如有已上传 URL 则直接用，否则上传）
                if let url = uploadedImageUrl {
                    params["ext"] = url
                } else if let image = selectedImage {
                    await MainActor.run {
                        uiState.isUploading = true
                        uiState.uploadProgress = 0
                        uiState.isUploadFinished = false
                    }

                    let url = try await NetworkManager.shared.uploadImage(image) { progress in
                        Task { @MainActor in
                            uiState.uploadProgress = progress
                        }
                    }

                    await MainActor.run {
                        uiState.uploadProgress = 1.0
                        uiState.isUploadFinished = true
                    }

                    try? await Task.sleep(nanoseconds: 500_000_000)

                    await MainActor.run {
                        uiState.isUploading = false
                        uiState.isUploadFinished = false
                    }

                    params["ext"] = url
                }

                // 提交上报
                let resp: BoolResp = try await NetworkManager.shared.request(
                    "/petFriendly/client/reportPlace",
                    method: .post,
                    parameters: params,
                    needToken: true
                )

                await MainActor.run {
                    self.isLoading = false
                    if resp.code == 200 {
                        Haptics.notify(.success)
                        // 提交成功后清除草稿
                        PlaceFormDraftManager.clear()
                        presentationMode.wrappedValue.dismiss()
                        showSuccessHUD(message: NSLocalizedString("add_place_success", comment: ""))
                    } else {
                        print(resp.msg ?? NSLocalizedString("msg_submit_fail", comment: ""))
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print(error.localizedDescription)
                    showErrorAlert(error)
                }
            }
        }
    }
}
