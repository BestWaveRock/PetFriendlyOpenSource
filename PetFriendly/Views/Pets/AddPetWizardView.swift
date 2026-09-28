//
//  AddPetWizardView.swift
//  PetFriendly
//
//  添加萌宠向导（极致美化版）— 全屏卡片式步骤
//

import SwiftUI
import Alamofire

@MainActor
struct AddPetWizardView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.locale) var envLocale
    @StateObject private var viewModel = PetFormViewModel()
    
    @State private var currentStep = 0
    @State private var name = ""
    @State private var birthday = Date()
    @State private var avatarImage: UIImage?
    @State private var showImagePicker = false
    
    @State private var selectedSpecies: DictData?
    @State private var selectedBreed: DictData?
    @State private var selectedSex: DictData?
    @FocusState private var isNameFocused: Bool
    
    private let totalSteps = 6
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: 渐变进度条
                progressBar
                    .padding(.top, PFSpacing.md)
                
                // MARK: 步骤内容
                TabView(selection: $currentStep) {
                    speciesStep.tag(0)
                    breedStep.tag(1)
                    nameStep.tag(2)
                    sexStep.tag(3)
                    birthdayStep.tag(4)
                    avatarStep.tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(PFAnimation.spring, value: currentStep)
                
                // MARK: 底部导航
                bottomBar
            }
        }
        .navigationTitle("add_pet_title")
        .navigationBarTitleDisplayMode(.inline)
        .trackScene("AddPetWizard_Step\(currentStep)")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(LocalizedStringKey("alert_cancel")) { dismiss() }
                    .foregroundColor(PFColors.textSecondary)
            }
        }
        .alert(item: $viewModel.currentError) { error in
            Alert(
                title: Text(LocalizedStringKey("alert_hint")),
                message: Text(error.errorDescription ?? ""),
                dismissButton: .default(Text(LocalizedStringKey("alert_ok")))
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $avatarImage)
        }
    }
    
    // MARK: - 渐变进度条
    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? AnyShapeStyle(PFGradients.brand) : AnyShapeStyle(PFColors.divider))
                    .frame(height: 4)
                    .animation(PFAnimation.spring, value: currentStep)
            }
        }
        .padding(.horizontal, PFSpacing.xl)
    }
    
    // MARK: - Step 1: 种类选择
    private var speciesStep: some View {
        VStack(spacing: PFSpacing.xxxl) {
            Spacer().frame(height: 20)
            
            stepHeader(icon: "pawprint.fill", title: "add_pet_species_title", color: PFColors.primary)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(viewModel.speciesList) { species in
                        selectionCard(
                            title: LocalizedStringKey(species.dictLabel),
                            isSelected: selectedSpecies?.id == species.id,
                            action: {
                                selectedSpecies = species
                                Task { await viewModel.fetchBreeds(for: species.dictValue) }
                                nextAction()
                            }
                        )
                    }
                }
                .padding(.horizontal, PFSpacing.xl)
            }
            
            Spacer()
        }
        .onAppear {
            if viewModel.speciesList.isEmpty {
                Task { await viewModel.fetchSpecies() }
            }
        }
    }
    
    // MARK: - Step 2: 品种选择
    private var breedStep: some View {
        VStack(spacing: PFSpacing.xxxl) {
            Spacer().frame(height: 20)
            
            stepHeader(icon: "hare.fill", title: "add_pet_breed_title", color: PFColors.accent)
            
            if viewModel.breedList.isEmpty {
                VStack(spacing: 12) {
                    PFPetLoadingView(size: 36)
                    Text(LocalizedStringKey("add_pet_breed_loading")).font(PFFonts.caption).foregroundColor(PFColors.textSecondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(viewModel.breedList) { breed in
                            Button(action: {
                                selectedBreed = breed
                                nextAction()
                            }) {
                                HStack {
                                    Text(breed.dictLabel)
                                        .font(PFFonts.body)
                                        .foregroundColor(selectedBreed?.id == breed.id ? .white : PFColors.textPrimary)
                                    Spacer()
                                    if selectedBreed?.id == breed.id {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(.white)
                                    }
                                }
                                .padding()
                                .background(selectedBreed?.id == breed.id ? AnyShapeStyle(PFGradients.brand) : AnyShapeStyle(PFColors.surface))
                                .cornerRadius(PFRadius.md)
                                .pfCardShadow()
                            }
                        }
                    }
                    .padding(.horizontal, PFSpacing.xl)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Step 3: 昵称输入
    private var nameStep: some View {
        VStack(spacing: PFSpacing.xxxl) {
            Spacer().frame(height: 20)
            
            stepHeader(icon: "heart.fill", title: "add_pet_name_title", color: PFColors.danger)
            
            VStack(spacing: 20) {
                TextField(LocalizedStringKey("add_pet_name_placeholder"), text: $name)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .focused($isNameFocused)
                    .padding(.vertical, 20)
                
                Text(LocalizedStringKey("add_pet_name_hint"))
                    .font(PFFonts.body)
                    .foregroundColor(PFColors.textTertiary)
            }
            .padding(.horizontal, PFSpacing.xxxl)
            
            Spacer()
        }
        .offset(y: isNameFocused ? -150 : 0)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isNameFocused)
    }
    
    // MARK: - Step 4: 性别选择
    private var sexStep: some View {
        VStack(spacing: PFSpacing.xxxl) {
            Spacer().frame(height: 20)
            
            stepHeader(icon: "figure.dress.line.vertical.figure.arms.open", title: "add_pet_sex_title", color: PFColors.info)
            
            HStack(spacing: 24) {
                ForEach(viewModel.sexList) { sex in
                    let isMale = sex.dictValue == "1"
                    let isFemale = sex.dictValue == "2"
                    let sexKey: LocalizedStringKey = isMale ? "pets_sex_male" : (isFemale ? "pets_sex_female" : "pets_sex_private")
                    
                    selectionCard(
                        title: sexKey,
                        icon: isMale ? "leaf.fill" : "heart.fill",
                        isSelected: selectedSex?.id == sex.id,
                        color: isMale ? PFColors.genderMale : (isFemale ? PFColors.genderFemale : PFColors.textTertiary),
                        action: {
                            selectedSex = sex
                            nextAction()
                        }
                    )
                }
            }
            .padding(.horizontal, PFSpacing.xl)
            
            Spacer()
        }
        .onAppear {
            if viewModel.sexList.isEmpty {
                Task { await viewModel.fetchSex() }
            }
        }
    }
    
    // MARK: - 通用组件
    private func stepHeader(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
            }
            
            Text(LocalizedStringKey(title))
                .font(PFFonts.title)
                .foregroundColor(PFColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private func selectionCard(title: LocalizedStringKey, icon: String? = nil, isSelected: Bool, color: Color? = nil, action: @escaping () -> Void) -> some View {
        let activeColor = color ?? PFColors.primary
        return Button(action: action) {
            VStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 30))
                        .foregroundColor(isSelected ? .white : activeColor)
                }
                
                Text(title)
                    .font(PFFonts.headline)
                    .foregroundColor(isSelected ? .white : PFColors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(isSelected ? AnyShapeStyle(activeColor) : AnyShapeStyle(PFColors.surface))
            .cornerRadius(24)
            .pfCardShadow()
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(activeColor.opacity(0.2), lineWidth: isSelected ? 0 : 1)
            )
        }
    }
    
    // MARK: - Step 5: 生日选择
    private var birthdayStep: some View {
        VStack(spacing: PFSpacing.xxxl) {
            Spacer().frame(height: 20)
            
            stepHeader(icon: "birthday.cake.fill", title: "add_pet_birthday_title", color: PFColors.accent)
            
            DatePicker("", selection: $birthday, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding(.horizontal, PFSpacing.xl)
                .environment(\.locale, envLocale)
            
            Spacer()
        }
    }
    
    // MARK: - Step 6: 头像上传
    private var avatarStep: some View {
        VStack(spacing: PFSpacing.xxxl) {
            Spacer().frame(height: 20)
            
            ZStack {
                Circle()
                    .fill(PFColors.success.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "camera.fill")
                    .font(.system(size: 32))
                    .foregroundColor(PFColors.success)
            }
            
            Text(LocalizedStringKey("add_pet_avatar_title"))
                .font(PFFonts.title)
                .foregroundColor(PFColors.textPrimary)
            
            Button(action: { showImagePicker = true }) {
                if let img = avatarImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    PFGradients.brand,
                                    lineWidth: 3
                                )
                        )
                        .pfElevatedShadow()
                } else {
                    VStack(spacing: PFSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(PFColors.surfaceSecondary)
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(PFGradients.brand)
                        }
                        
                        Text(LocalizedStringKey("add_pet_avatar_click"))
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.textSecondary)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - 底部导航栏
    private var bottomBar: some View {
        HStack {
            // 左侧
            if currentStep > 0 {
                Button(action: {
                    withAnimation(PFAnimation.spring) { currentStep -= 1 }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text(LocalizedStringKey("add_pet_back"))
                            .font(PFFonts.callout)
                    }
                    .foregroundColor(PFColors.textSecondary)
                }
            } else {
                Button(LocalizedStringKey("alert_cancel")) { dismiss() }
                    .font(PFFonts.callout)
                    .foregroundColor(PFColors.textTertiary)
            }
            
            Spacer()
            
            // 草稿按钮（仅最后一步）
            if currentStep == totalSteps - 1 {
                Button(action: { saveDraft() }) {
                    Text(LocalizedStringKey("add_pet_draft"))
                        .font(PFFonts.callout)
                        .foregroundColor(PFColors.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(PFColors.primary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(.trailing, 8)
            }
            
            // 右侧（下一步 / 提交）
            Button(action: nextAction) {
                HStack(spacing: 6) {
                    if viewModel.isLoading {
                        PFPetLoadingInline(size: 14)
                    } else {
                        Text(LocalizedStringKey(currentStep == totalSteps - 1 ? "alert_done" : "add_pet_next"))
                            .font(PFFonts.callout)
                        if currentStep < totalSteps - 1 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(canProceed ? PFGradients.brand : LinearGradient(colors: [PFColors.textTertiary], startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
                .pfElevatedShadow()
            }
            .disabled(!canProceed || viewModel.isLoading)
        }
        .padding(.horizontal, PFSpacing.xl)
        .padding(.vertical, PFSpacing.lg)
        .background(
            PFColors.surface
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    // MARK: - 逻辑
    private var canProceed: Bool {
        switch currentStep {
        case 0: return selectedSpecies != nil
        case 1: return selectedBreed != nil
        case 2: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 3: return selectedSex != nil
        case 4: return true
        case 5: return true
        default: return false
        }
    }
    
    private func nextAction() {
        if currentStep < totalSteps - 1 {
            withAnimation(PFAnimation.spring) { currentStep += 1 }
        } else {
            submit()
        }
    }
    
    private func submit() {
        Task {
            let speciesId = Int(selectedSpecies?.dictValue ?? "0") ?? 0
            let breedId = Int(selectedBreed?.dictValue ?? "0") ?? 0
            let sexId = Int(selectedSex?.dictValue ?? "0") ?? 0
            
            let success = await viewModel.addPet(
                name: name,
                species: speciesId,
                breed: breedId,
                sex: sexId,
                birthday: birthday,
                petAvatar: avatarImage
            )
            if success { dismiss() }
        }
    }
    
    private func saveDraft() {
        UserDefaults.standard.set(name, forKey: "pet_draft_name")
        UserDefaults.standard.set(selectedSpecies?.dictValue, forKey: "pet_draft_species")
        UserDefaults.standard.set(selectedBreed?.dictValue, forKey: "pet_draft_breed")
        UserDefaults.standard.set(selectedSex?.dictValue, forKey: "pet_draft_sex")
        UserDefaults.standard.set(birthday, forKey: "pet_draft_birthday")
        dismiss()
    }
}

// Remove the local AddPetViewModel definition since it's now in PetViewModel.swift
// [DELETE] class AddPetViewModel: ObservableObject { ... }
