import SwiftUI

struct StrayPetDetailView: View {
    let pet: Pet
    @Environment(\.dismiss) var dismiss
    @State private var currentStatus: Int
    @State private var statusActionInProgress: String?
    @State private var showUpdateForm = false
    @State private var updates: [StrayUpdate] = []

    init(pet: Pet) {
        self.pet = pet
        _currentStatus = State(initialValue: pet.status ?? 0)
    }
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 宠物大图
                    ZStack(alignment: .topLeading) {
                        if let url = pet.avatarUrl {
                            CachedAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 350)
                                    .clipped()
                            } placeholder: {
                                ProgressView()
                                    .frame(height: 350)
                            }
                            .pfImageInteractable(url: url.absoluteString)
                        } else {
                            Rectangle()
                                .fill(PFGradients.brand.opacity(0.15))
                                .frame(height: 350)
                                .overlay {
                                    Image(systemName: "pawprint.fill")
                                        .font(.system(size: 80))
                                        .foregroundColor(PFColors.primary)
                                }
                        }
                    }
                    
                    // 宠物详情面板
                    VStack(alignment: .leading, spacing: PFSpacing.xl) {
                        
                        // 名字 & 状态标签
                        HStack(alignment: .firstTextBaseline) {
                            Text(pet.displayName)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(PFColors.textPrimary)
                            
                            Spacer()
                            
                            Text(Pet.strayStatusKey(currentStatus))
                                .font(PFFonts.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                        
                        // 基础属性网格
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: PFSpacing.md) {
                            attributeCard(title: NSLocalizedString("form_breed", comment: ""), value: pet.breed ?? NSLocalizedString("pets_unknown_breed", comment: ""), icon: "pawprint")
                            attributeCard(title: NSLocalizedString("attr_sex", comment: ""), value: pet.sex == 1 ? "♂" : (pet.sex == 2 ? "♀" : NSLocalizedString("place_level_unknown", comment: "")), icon: "genderless")
                            attributeCard(title: NSLocalizedString("attr_age", comment: ""), value: pet.ageString, icon: "hourglass")
                            attributeCard(title: NSLocalizedString("attr_reporter", comment: ""), value: pet.nickName ?? NSLocalizedString("kind_person", comment: ""), icon: "person")
                        }
                        
                        // 说明 & 背景
                        VStack(alignment: .leading, spacing: PFSpacing.md) {
                            Text("stray_detail_intro")
                                .font(PFFonts.headline)
                                .foregroundColor(PFColors.textPrimary)
                            
                            Text(NSLocalizedString("adopt_desc", comment: ""))
                                .font(PFFonts.body)
                                .foregroundColor(PFColors.textSecondary)
                                .lineSpacing(6)
                        }
                        .padding(.top, 8)

                        HStack {
                            Label(pet.reportAgeText, systemImage: "clock")
                            Spacer()
                            Button("stray_add_update") { showUpdateForm = true }
                        }.font(PFFonts.caption).foregroundColor(PFColors.primary)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("stray_updates_title").font(PFFonts.headline)
                            ForEach(updates) { item in
                                updateTimelineEntry(item)
                            }
                            reportTimelineEntry
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(PFSpacing.xl)
                }
            }
            .ignoresSafeArea(edges: .top)
            
            // 顶部关闭与领养入口；详情作为可下拉 Sheet 展示，仍保留明确关闭操作。
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .padding(.leading, PFSpacing.lg)
                    .padding(.top, 50)
                    Spacer()
                    HStack(spacing: 8) {
                        if currentStatus == 0 {
                            statusButton(action: "rescue", title: "stray_btn_apply_rescue", icon: "cross.case.fill")
                        }
                        if currentStatus < 3 {
                            statusButton(action: "adopt", title: "stray_btn_apply_adopt_short", icon: "heart.fill")
                        }
                    }
                    .padding(.trailing, PFSpacing.lg)
                    .padding(.top, 50)
                }
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showUpdateForm) { StrayUpdateForm(pet: pet) { loadUpdates() } }
        .task { loadUpdates() }
    }

    private func statusButton(action: String, title: LocalizedStringKey, icon: String) -> some View {
        Button { updateStatus(action) } label: {
            Group {
                if statusActionInProgress == action { ProgressView().tint(.white) }
                else { Label(title, systemImage: icon) }
            }
            .font(PFFonts.caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.black.opacity(0.42), in: Capsule())
        }
        .disabled(statusActionInProgress != nil)
    }

    private func updateStatus(_ action: String) {
        statusActionInProgress = action
        Task {
            do {
                let _: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                    "/petFriendly/client/strayAnimals/\(pet.petId)/status",
                    method: .post,
                    parameters: ["action": action],
                    needToken: true
                )
                await MainActor.run {
                    currentStatus = action == "rescue" ? 2 : 3
                    statusActionInProgress = nil
                    PetViewModel.shared.fetchPets(contactType: 1)
                    showSuccessHUD(message: NSLocalizedString(action == "rescue" ? "stray_rescue_success" : "stray_adopt_success", comment: ""))
                }
            } catch {
                await MainActor.run {
                    statusActionInProgress = nil
                    showErrorAlert(error)
                }
            }
        }
    }

    private func loadUpdates() {
        Task {
            do {
                let response: RespWrapper<[StrayUpdate]> = try await NetworkManager.shared.request("/petFriendly/client/strayAnimals/\(pet.petId)/updates", method: .get, needToken: true)
                await MainActor.run { updates = response.data ?? [] }
            } catch {
                await MainActor.run { showErrorAlert(error) }
            }
        }
    }

    private var reportTimelineEntry: some View {
        timelineCard(
            title: NSLocalizedString("stray_timeline_reported", comment: ""),
            content: pet.name,
            time: pet.birthday ?? NSLocalizedString("common_unknown", comment: ""),
            imageURLs: pet.avatarUrl.map { [$0] } ?? []
        )
    }

    private func updateTimelineEntry(_ item: StrayUpdate) -> some View {
        timelineCard(
            title: NSLocalizedString("stray_timeline_update", comment: ""),
            content: item.content ?? "",
            time: item.createTime ?? NSLocalizedString("common_unknown", comment: ""),
            imageURLs: item.imageURLList
        )
    }

    private func timelineCard(title: String, content: String, time: String, imageURLs: [URL]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(PFColors.primary).frame(width: 10, height: 10).padding(.top, 7)
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(PFFonts.subheadline.weight(.semibold))
                if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(content).font(PFFonts.body).foregroundColor(PFColors.textSecondary)
                }
                if !imageURLs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(imageURLs, id: \.absoluteString) { url in
                                CachedAsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: { PFPetLoadingInline(size: 14) }
                                .frame(width: 92, height: 92)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .pfImageInteractable(url: url.absoluteString)
                            }
                        }
                    }
                }
                Text(time).font(PFFonts.caption2).foregroundColor(PFColors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(PFColors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    @ViewBuilder
    private func attributeCard(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PFColors.primary.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundColor(PFColors.primary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textTertiary)
                Text(value)
                    .font(PFFonts.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(PFColors.textPrimary)
            }
            Spacer()
        }
        .padding(12)
        .background(PFColors.surface)
        .cornerRadius(12)
        .pfCardShadow()
    }
}

struct StrayUpdate: Decodable, Identifiable {
    let updateId: String
    let content: String?
    let imageUrls: String?
    let createTime: String?
    var id: String { updateId }
    var imageURLList: [URL] {
        (imageUrls ?? "").split(separator: ",").compactMap { URL(string: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
    }
    enum CodingKeys: String, CodingKey {
        case updateId = "update_id"
        case content
        case imageUrls = "image_urls"
        case createTime = "create_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringId = try? container.decode(String.self, forKey: .updateId) {
            updateId = stringId
        } else if let integerId = try? container.decode(Int64.self, forKey: .updateId) {
            updateId = String(integerId)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .updateId,
                in: container,
                debugDescription: "update_id must be a string or integer"
            )
        }
        content = try container.decodeIfPresent(String.self, forKey: .content)
        imageUrls = try container.decodeIfPresent(String.self, forKey: .imageUrls)
        createTime = try container.decodeIfPresent(String.self, forKey: .createTime)
    }
}

struct StrayUpdateForm: View {
    let pet: Pet; let completion: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""; @State private var image: UIImage?; @State private var showPicker = false; @State private var loading = false
    var body: some View { NavigationStack { VStack(spacing: 16) {
        PFVoiceInputEditor(placeholder: "stray_update_placeholder", text: $content, height: 140, maxLength: 500)
        Button { showPicker = true } label: {
            if let image {
                Image(uiImage: image).resizable().scaledToFill().frame(height: 150).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Label("stray_update_add_photo", systemImage: "photo.badge.plus").frame(maxWidth: .infinity).frame(height: 72)
            }
        }.buttonStyle(.bordered)
        Spacer()
        Button { submit() } label: { if loading { ProgressView() } else { Text("stray_update_submit").frame(maxWidth: .infinity) } }.buttonStyle(.borderedProminent).controlSize(.large).disabled(content.isEmpty && image == nil)
    }.padding().navigationTitle("stray_add_update").toolbar { ToolbarItem(placement: .cancellationAction) { Button("common_cancel") { dismiss() } } }.sheet(isPresented: $showPicker) { ImagePicker(image: $image) } } }
    private func submit() { loading = true; Task { do { var urls:[String]=[]; if let image { urls.append(try await NetworkManager.shared.uploadImage(image)) }; let _: RespWrapper<JSONAny> = try await NetworkManager.shared.request("/petFriendly/client/strayAnimals/\(pet.petId)/updates", method: .post, parameters:["content":content,"imageUrls":urls.joined(separator:",")], needToken:true); await MainActor.run { loading=false; completion(); dismiss() } } catch { await MainActor.run { loading=false; showErrorAlert(error) } } } }
}

// MARK: - 提交领养申请表单
