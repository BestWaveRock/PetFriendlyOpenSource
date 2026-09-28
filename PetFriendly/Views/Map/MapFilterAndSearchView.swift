//
//  MapFilterAndSearchView.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2026/06/23.
//

import SwiftUI

struct MapFilterAndSearchView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vm: MapViewModel
    
    @State private var localSearchText = ""
    @FocusState private var isSearchFocused: Bool
    @GestureState private var isDraggingScroll = false
    private var safeAreaTop: CGFloat { PFScreen.safeAreaTop }
    
    var body: some View {
        VStack(spacing: 0) {
            customHeader
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 1. Search Bar
                    searchSection
                    
                    // 2. Map Category Filter
                    categorySection
                    
                    // 3. Search Radius Filter
                    radiusSection
                    
                    // 4. Filtered Places List
                    filteredPlacesSection
                }
                .padding(.vertical, 16)
                .padding(.bottom, 24)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 2)
                    .updating($isDraggingScroll) { _, state, _ in
                        state = true
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Group {
                if isDraggingScroll {
                    // 拖动时：只保留透明液态玻璃效果，无模糊
                    Color(.systemGroupedBackground).opacity(0.96)
                } else {
                    // 静止时：恢复液态模糊效果
                    Color(.systemGroupedBackground)
                }
            }
        )
        .animation(.easeInOut(duration: 0.25), value: isDraggingScroll)
        .ignoresSafeArea()
        .onAppear {
            localSearchText = vm.searchText
        }
    }
    
    private var customHeader: some View {
        HStack(spacing: 12) {
            Button(action: {
                dismiss()
                Haptics.play(.light)
            }) {
                Text(NSLocalizedString("common_cancel", comment: ""))
                    .font(PFFonts.body)
                    .foregroundColor(PFColors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(Capsule())
            }
            .buttonStyle(PFSimplePressButtonStyle())
            
            Spacer()
            
            Text(NSLocalizedString("map_filter_search_sheet_title", comment: ""))
                .font(PFFonts.headline)
                .foregroundColor(PFColors.textPrimary)
            
            Spacer()
            
            Button(action: {
                vm.searchText = localSearchText
                dismiss()
                Haptics.play(.medium)
            }) {
                Text(NSLocalizedString("settings_confirm", comment: ""))
                    .font(PFFonts.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(PFColors.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(PFSimplePressButtonStyle())
        }
        .padding(.horizontal, PFSpacing.lg)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, safeAreaTop)
        .padding(.bottom, 12)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(UIColor.separator))
                .opacity(0.5),
            alignment: .bottom
        )
    }

    
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("map_filter_search_title", comment: ""))
                .font(PFFonts.headline)
                .foregroundColor(PFColors.textPrimary)
            
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(PFColors.textTertiary)
                    .font(.system(size: 15))
                
                TextField("search_placeholder", text: $localSearchText)
                    .font(PFFonts.body)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        vm.searchText = localSearchText
                        isSearchFocused = false
                        Haptics.play(.medium)
                    }
                
                if !localSearchText.isEmpty {
                    Button(action: {
                        localSearchText = ""
                        vm.searchText = ""
                        Haptics.play(.light)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(PFColors.textTertiary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(PFSimplePressButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSearchFocused ? PFColors.primary.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.15), value: isSearchFocused)
        }
        .padding(.horizontal, PFSpacing.lg)
    }

    
    /// 根据分类标签匹配对应的 Emoji 表情
    private func emojiForCategory(_ label: String) -> String {
        switch label {
        case "全部":       return "🌍"
        case "宠物公园":    return "🌳"
        case "宠物医院":    return "🏥"
        case "宠物友好餐厅": return "🍽️"
        case "饮水点":     return "💧"
        case "小草坪":     return "🌿"
        case "公开广场":    return "🏛️"
        case "派出所":     return "🚔"
        case "宠物摄影":    return "📸"
        case "宠物美容":    return "✂️"
        case "寄养":       return "🏠"
        default:          return "🐾"
        }
    }
    
    private var categorySection: some View {
        Group {
            if !vm.placeTypes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("map_filter_category_title", comment: ""))
                        .font(PFFonts.headline)
                        .foregroundColor(PFColors.textPrimary)
                        .padding(.horizontal, PFSpacing.lg)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104, maximum: 160))], alignment: .leading, spacing: 10) {
                        ForEach(vm.placeTypes) { type in
                            let isActive = vm.selectedCategory == type.dictLabel
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if isActive {
                                        vm.selectedCategory = "全部"
                                    } else {
                                        vm.selectedCategory = type.dictLabel
                                    }
                                }
                                Haptics.play(.medium)
                            }) {
                                HStack(spacing: 6) {
                                    Text(emojiForCategory(type.dictLabel))
                                        .font(.system(size: 16))
                                    Text(LocalizedStringKey(type.dictLabel))
                                        .font(PFFonts.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(isActive ? .white : PFColors.textPrimary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 12)
                                .frame(minHeight: 46)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(isActive ? PFColors.primary : Color(UIColor.secondarySystemBackground))
                                )
                                .scaleEffect(isActive ? 1.03 : 1.0)
                            }
                            .buttonStyle(PFSimplePressButtonStyle())
                        }
                    }
                    .padding(.horizontal, PFSpacing.lg)
                }
                .padding(.vertical, 16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 16)
            }
        }
    }

    
    // MARK: - 搜索半径滚轮选择器 (秒表式上下滑动)
    
    private let radiusOptions: [Int] = [1000, 3000, 5000, 10000, 20000, 50000, 100000]
    
    private var radiusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("map_filter_radius_title", comment: ""))
                .font(PFFonts.headline)
                .foregroundColor(PFColors.textPrimary)
                .padding(.horizontal, PFSpacing.lg)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86))], spacing: 10) {
                ForEach(radiusOptions, id: \.self) { radius in
                    let selected = vm.searchRadius == radius
                    Button {
                        vm.updateSearchRadius(radius); Haptics.play(.light)
                    } label: {
                        Label(radius >= 1000 ? "\(radius / 1000) km" : "\(radius) m", systemImage: selected ? "location.fill" : "location")
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(selected ? .white : PFColors.textPrimary)
                            .background(selected ? PFColors.primary : Color(.tertiarySystemGroupedBackground), in: Capsule())
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, PFSpacing.lg)
        }
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 16)
    }

    
    private var filteredPlacesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("map_filtered_places_title", comment: ""))
                    .font(PFFonts.headline)
                    .foregroundColor(PFColors.textPrimary)
                Spacer()
                if vm.totalPlaces > 0 {
                    Text(String(format: NSLocalizedString("map_destinations_count %lld", comment: ""), vm.totalPlaces))
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textSecondary)
                }
            }
            .padding(.horizontal, PFSpacing.lg)
            
            if vm.isLoading && vm.filteredPlaces.isEmpty {
                HStack {
                    Spacer()
                    PFPetLoadingView("map_loading", size: 36)
                        .padding(.vertical, 30)
                    Spacer()
                }
                .padding(.horizontal, PFSpacing.lg)
            } else if vm.filteredPlaces.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 28))
                            .foregroundColor(PFColors.textTertiary)
                        Text(NSLocalizedString("map_no_results", comment: ""))
                            .font(PFFonts.body)
                            .foregroundColor(PFColors.textSecondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .padding(.horizontal, PFSpacing.lg)
            } else {
                ZStack {
                    LazyVStack(spacing: PFSpacing.md) {
                        ForEach(vm.filteredPlaces) { place in
                            PlaceCardView(place: place, onTapCard: {
                                vm.focusUpperHalf(on: place)
                                dismiss()
                                Haptics.play(.medium)
                            })
                        }
                    }
                    .padding(.horizontal, PFSpacing.lg)
                    .opacity(vm.isLoading ? 0.4 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: vm.isLoading)
                    
                    // 加载中覆盖层
                    if vm.isLoading {
                        VStack(spacing: 10) {
                            PFPetLoadingInline(size: 20)
                            Text("map_loading")
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.textSecondary)
                        }
                        .padding(.vertical, 30)
                    }
                }
            }
        }
    }

}
