//
//  Pets.swift
//  PetFriendly
//
//  萌宠档案 — 主页面（极致美化版）
//

import SwiftUI

// MARK: - 主页面
struct Pets: View {
    @EnvironmentObject private var viewModel: PetViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showRecycleBin = false
    @State private var showAddPet = false
    @State private var appearAnimation = false
    @State private var showLoginAlert = false
    @State private var showLoginSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                PFColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: 渐变头部
                    headerView
                    
                    // MARK: 内容
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: PFSpacing.xl) {
                            
                            // MARK: 宠物列表
                            if viewModel.pets.isEmpty && !viewModel.isLoading {
                                emptyStateView
                                    .transition(.opacity.combined(with: .scale))
                            } else {
                                petListSection
                            }
                            
                            // MARK: 提醒卡片
                            remindSection
                        }
                        .padding(.top, PFSpacing.lg)
                        .padding(.bottom, 100)
                    }
                    .refreshable {
                        viewModel.fetchPets()
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            .navigationBarHidden(true)
        }
        .trackScene("PetsListView")
        .pfToyBackground()
        .onAppear {
            viewModel.fetchPets()
            withAnimation(PFAnimation.springGentle) {
                appearAnimation = true
            }
        }
        .sheet(isPresented: $showRecycleBin) {
            PetRecycleBinView()
        }
        .sheet(isPresented: $showAddPet) {
            NavigationStack {
                AddPetWizardView()
            }
        }
        .alert(isPresented: $showLoginAlert) {
            Alert(
                title: Text("person_login_required"),
                message: Text("pets_login_message"),
                primaryButton: .default(Text("person_login_go")) {
                    showLoginSheet = true
                },
                secondaryButton: .cancel(Text("person_login_ok"))
            )
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginPage()
        }
    }
    
    private func handleAddPet() {
        guard NetworkManager.shared.token != nil else {
            showLoginAlert = true
            return
        }
        showAddPet = true
    }
    
    // MARK: - 渐变头部
    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("pets_title")
                    .font(PFFonts.title)
                    .foregroundColor(.white)
                
                Text("pets_subtitle")
                    .font(PFFonts.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // 回收站按钮
                Button(action: { showRecycleBin = true }) {
                    Image(systemName: "trash.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                
                // 添加按钮
                Button(action: { handleAddPet() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(PFColors.primary)
                        .padding(10)
                        .background(Color.white)
                        .clipShape(Circle())
                        .pfElevatedShadow()
                }
            }
        }
        .padding(.horizontal, PFSpacing.xl)
        .padding(.top, 44) // 适配状态栏高度
        .padding(.bottom, PFSpacing.lg)
        .frame(minHeight: PFSpacing.headerHeight + 44, alignment: .bottom)
        .background(PFGradients.brand)
    }
    
    // MARK: - 宠物列表区
    private var petListSection: some View {
        VStack(spacing: PFSpacing.md) {
            // 小标题
            HStack {
                Text("pets_my_pets")
                    .font(PFFonts.headline)
                    .foregroundColor(PFColors.textPrimary)
                
                // 数量 badge
                Text("\(viewModel.pets.count)")
                    .font(PFFonts.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(PFGradients.brand)
                    .clipShape(Capsule())
                
                Spacer()
                
                if viewModel.isLoading {
                    PFPetLoadingInline(size: 16)
                }
            }
            .padding(.horizontal, PFSpacing.xl)
            
            ForEach(Array(viewModel.pets.enumerated()), id: \.element.id) { index, pet in
                NavigationLink(destination: PetDetailView(pet: pet)) {
                    PetRow(pet: pet, viewModel: viewModel)
                }
                .buttonStyle(PlainButtonStyle())
                .contextMenu {
                    Button(role: .destructive) {
                        if let id = Int64(pet.petId) {
                            withAnimation(PFAnimation.spring) {
                                viewModel.deletePet(id: id)
                            }
                        }
                    } label: {
                        Label("pets_move_to_recycle", systemImage: "trash")
                    }
                }
                .offset(y: appearAnimation ? 0 : 30)
                .opacity(appearAnimation ? 1 : 0)
                .animation(
                    PFAnimation.springGentle.delay(Double(index) * 0.08),
                    value: appearAnimation
                )
            }
        }
    }
    
    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: PFSpacing.xl) {
            Spacer().frame(height: 40)
            
            ZStack {
                Circle()
                    .fill(PFColors.surfaceSecondary)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(PFGradients.brand)
            }
            
            VStack(spacing: 8) {
                Text("pets_empty_title")
                    .font(PFFonts.title2)
                    .foregroundColor(PFColors.textPrimary)
                
                Text("pets_empty_subtitle")
                    .font(PFFonts.body)
                    .foregroundColor(PFColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            PFButton("pets_add_button", icon: "plus") {
                handleAddPet()
            }
            
            Spacer().frame(height: 40)
        }
        .padding(.horizontal, PFSpacing.xxxl)
    }
    
    // MARK: - 提醒区域
    private var remindSection: some View {
        VStack(spacing: PFSpacing.md) {
            let reminders = buildReminders()
            if !reminders.isEmpty {
                HStack {
                    Text("pets_reminders")
                        .font(PFFonts.headline)
                        .foregroundColor(PFColors.textPrimary)
                    
                    Text("\(reminders.count)")
                        .font(PFFonts.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(PFGradients.emergency)
                        .clipShape(Capsule())
                    
                    Spacer()
                }
                .padding(.horizontal, PFSpacing.xl)
                
                ForEach(reminders, id: \.id) { reminder in
                    RemindCard(
                        title: reminder.title,
                        subtitle: reminder.subtitle,
                        icon: reminder.icon,
                        gradient: reminder.gradient,
                        buttonTitle: reminder.buttonTitle
                    )
                }
            }
        }
    }
    
    private struct ReminderItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let gradient: LinearGradient
        let buttonTitle: String
    }
    
    private func buildReminders() -> [ReminderItem] {
        var items: [ReminderItem] = []
        for pet in viewModel.pets {
            if pet.isBeautyDue == true {
                items.append(ReminderItem(
                    title: NSLocalizedString("pets_remind_beauty_title", comment: ""),
                    subtitle: String(format: NSLocalizedString("pets_remind_beauty_subtitle", comment: ""), pet.displayName),
                    icon: "scissors",
                    gradient: PFGradients.beauty,
                    buttonTitle: NSLocalizedString("pets_remind_beauty_button", comment: "")
                ))
            }
            if pet.isBirthdaySoon == true {
                items.append(ReminderItem(
                    title: NSLocalizedString("pets_remind_birthday_title", comment: ""),
                    subtitle: String(format: NSLocalizedString("pets_remind_birthday_subtitle", comment: ""), pet.displayName),
                    icon: "gift.fill",
                    gradient: PFGradients.birthday,
                    buttonTitle: NSLocalizedString("pets_remind_birthday_button", comment: "")
                ))
            }
            if pet.isVaccineDue == true {
                items.append(ReminderItem(
                    title: NSLocalizedString("pets_remind_vaccine_title", comment: ""),
                    subtitle: String(format: NSLocalizedString("pets_remind_vaccine_subtitle", comment: ""), pet.displayName),
                    icon: "cross.vial.fill",
                    gradient: PFGradients.vaccine,
                    buttonTitle: NSLocalizedString("pets_remind_vaccine_button", comment: "")
                ))
            }
        }
        return items
    }
}

// MARK: - 宠物卡片
struct PetRow: View {
    let pet: Pet
    @ObservedObject var viewModel: PetViewModel
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: PFSpacing.lg) {
            ZStack(alignment: .topTrailing) {
                GlowAvatar(
                    url: pet.avatarUrl,
                    size: 72,   
                    glowColor: pet.sex == 2 ? PFColors.genderFemale : (pet.sex == 1 ? PFColors.genderMale : PFColors.info)
                )
                
                if (pet.isBeautyDue == true || pet.isVaccineDue == true || pet.isBirthdaySoon == true) {
                    Circle()
                        .fill(PFColors.danger)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: -4, y: 4)
                }
            }
            
            // 信息区
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(pet.displayName)
                        .font(PFFonts.headline)
                        .foregroundColor(PFColors.textPrimary)
                    
                    PFTag(
                        text: pet.sex == 2 ? "pets_sex_female" : (pet.sex == 1 ? "pets_sex_male" : "pets_sex_private"),
                        gradient: pet.sex == 2
                            ? LinearGradient(colors: [PFColors.genderFemale], startPoint: .leading, endPoint: .trailing)
                            : (pet.sex == 1 ? LinearGradient(colors: [PFColors.genderMale], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [PFColors.info], startPoint: .leading, endPoint: .trailing))
                    ).font(PFFonts.caption2)
                }
                
                HStack(spacing: 8) {
                    Text(viewModel.breedMap[pet.petId] ?? pet.breed ?? NSLocalizedString("pets_unknown_breed", comment: ""))
                    Text("•")
                    Text(pet.ageString)
                }
                .font(PFFonts.body)
                .foregroundColor(PFColors.textSecondary)
                
                // 快捷操作
                HStack(spacing: 8) {
                    NavigationLink(destination: PetHealthRecordListView(petId: pet.petId, petName: pet.displayName)) {
                        quickTag(icon: "heart.text.square", title: NSLocalizedString("pets_health_records", comment: ""), color: PFColors.success)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    NavigationLink(destination: PetHealthRecordListView(petId: pet.petId, petName: pet.displayName)) {
                        quickTag(icon: "cross.case", title: NSLocalizedString("pets_vaccine_records", comment: ""), color: PFColors.info)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Spacer()
            
            // 右侧箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(PFColors.textTertiary)
        }
        .padding(PFSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PFRadius.lg)
                .fill(PFColors.surface)
        )
        .pfCardShadow()
        .padding(.horizontal, PFSpacing.xl)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(PFAnimation.spring, value: isPressed)
    }
    
    @ViewBuilder
    private func quickTag(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11))
            Text(LocalizedStringKey(title)).font(PFFonts.caption2)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(PFRadius.sm)
    }
}

// MARK: - 提醒卡片（重设计）
struct RemindCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: LinearGradient
    let buttonTitle: String
    
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: PFSpacing.lg) {
            // 左侧图标（脉冲）
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .opacity(isPulsing ? 0.3 : 0.6)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: isPulsing
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.25))
                    .clipShape(Circle())
            }
            
            // 文字
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(PFFonts.callout)
                    .foregroundColor(.white)
                
                Text(LocalizedStringKey(subtitle))
                    .font(PFFonts.caption)
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
            }
            
            Spacer()
            
            // 操作按钮
            Button(action: {}) {
                Text(LocalizedStringKey(buttonTitle))
                    .font(PFFonts.caption2)
                    .foregroundColor(PFColors.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
        }
        .padding(PFSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PFRadius.lg)
                .fill(gradient)
        )
        .pfCardShadow()
        .padding(.horizontal, PFSpacing.xl)
        .onAppear { isPulsing = true }
    }
}
