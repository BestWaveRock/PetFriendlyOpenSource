//
//  PetRecycleBinView.swift
//  PetFriendly
//
//  回收站 — 已删除宠物列表（360 天保留，性能优化版）
//

import SwiftUI

struct PetRecycleBinView: View {
    @ObservedObject private var viewModel = PetViewModel.shared
    @Environment(\.dismiss) var dismiss
    @State private var appearAnim = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                PFColors.background.ignoresSafeArea()
                
                if viewModel.isLoadingDeletedPets && viewModel.deletedPets.isEmpty {
                    // 加载中状态
                    VStack {
                        Spacer()
                        PFPetLoadingView("pet_bin_loading", size: 32)
                        Spacer()
                    }
                } else if viewModel.deletedPets.isEmpty {
                    // 空状态
                    VStack(spacing: PFSpacing.xl) {
                        ZStack {
                            Circle()
                                .fill(PFColors.surfaceSecondary)
                                .frame(width: 90, height: 90)
                            
                            Image(systemName: "trash.slash")
                                .font(.system(size: 38))
                                .foregroundStyle(PFGradients.brand)
                        }
                        
                        Text("pet_bin_empty")
                            .font(PFFonts.title2)
                            .foregroundColor(PFColors.textPrimary)
                        
                        Text("pet_bin_empty_sub")
                            .font(PFFonts.body)
                            .foregroundColor(PFColors.textSecondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: PFSpacing.md) {
                            // 提示横幅
                            HStack(spacing: PFSpacing.sm) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(PFColors.warning)
                                Text("pet_bin_hint")
                                    .font(PFFonts.caption)
                                    .foregroundColor(PFColors.textSecondary)
                                Spacer()
                            }
                            .padding(PFSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: PFRadius.sm)
                                    .fill(PFColors.warning.opacity(0.1))
                            )
                            .padding(.horizontal, PFSpacing.xl)
                            
                            ForEach(Array(viewModel.deletedPets.enumerated()), id: \.element.id) { index, pet in
                                deletedPetRow(pet: pet)
                                    .opacity(appearAnim ? 1 : 0)
                                    .offset(y: appearAnim ? 0 : 12)
                                    .animation(
                                        PFAnimation.springGentle.delay(Double(min(index, 8)) * 0.04),
                                        value: appearAnim
                                    )
                            }
                        }
                        .padding(.top, PFSpacing.lg)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("pet_bin_title")
            .navigationBarTitleDisplayMode(.inline)
            .trackScene("PetRecycleBin")
            .pfToyBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_close") { dismiss() }
                        .foregroundColor(PFColors.primary)
                }
            }
            .onAppear {
                viewModel.fetchDeletedPets()
                withAnimation(PFAnimation.springGentle) {
                    appearAnim = true
                }
            }
        }
    }
    
    @ViewBuilder
    private func deletedPetRow(pet: Pet) -> some View {
        HStack(spacing: PFSpacing.lg) {
            GlowAvatar(url: pet.avatarUrl, size: 52, glowColor: PFColors.textTertiary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(pet.displayName)
                    .font(PFFonts.headline)
                    .foregroundColor(PFColors.textPrimary)
                
                Text(pet.breed ?? NSLocalizedString("pet_breed_unknown", comment: ""))
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textSecondary)
                
                if let days = pet.daysUntilCleared {
                    Text(String(format: NSLocalizedString("pet_bin_days_left %lld", comment: ""), days))
                        .font(PFFonts.caption2)
                        .foregroundColor(PFColors.danger)
                }
            }
            
            Spacer()
            
            // 恢复按钮
            Button(action: {
                if let id = Int64(pet.petId) {
                    withAnimation(PFAnimation.spring) {
                        viewModel.restorePet(id: id)
                    }
                }
            }) {
                Text("pet_bin_restore")
                    .font(PFFonts.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(PFGradients.brand)
                    .clipShape(Capsule())
            }
        }
        .padding(PFSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PFRadius.lg)
                .fill(PFColors.surface)
        )
        .pfCardShadow()
        .padding(.horizontal, PFSpacing.xl)
    }
}
