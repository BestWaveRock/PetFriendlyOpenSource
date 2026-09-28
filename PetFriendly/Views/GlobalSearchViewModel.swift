//
//  GlobalSearchViewModel.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2026/3/19.
//


import SwiftUI
import Combine
import MapKit

enum GlobalSearchCategory: String, CaseIterable {
    case map = "search_category_map"
    case service = "search_category_service"
    case order = "search_category_order"
    case download = "search_category_download"
    
    var localizedTitle: String {
        return NSLocalizedString(self.rawValue, comment: "")
    }
}

// MARK: - 全局搜索 ViewModel
@MainActor
class GlobalSearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedCategory: GlobalSearchCategory = .map
    
    // 地图搜索结果
    @Published var mapResults: [PetFriendlyPlace] = []
    @Published var isSearching: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let locationManager = LocationManager() // 复用 MapViewModel 里的 LocationManager
    private var userCoordinate: CLLocationCoordinate2D?
    
    init() {
        // 监听位置
        locationManager.$location
            .compactMap { $0 }
            .first()
            .receive(on: RunLoop.main)
            .sink { [weak self] loc in
                self?.userCoordinate = loc.coordinate
            }
            .store(in: &cancellables)
            
        // 防抖搜索
        $searchText
            .debounce(for: .milliseconds(600), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                guard let self = self else { return }
                if text.isEmpty {
                    self.mapResults = []
                } else {
                    Task { await self.performSearch() }
                }
            }
            .store(in: &cancellables)
            
        // 切换分类时如果处于不同页也尝试刷新
        $selectedCategory
            .sink { [weak self] _ in
                Task { await self?.performSearch() }
            }
            .store(in: &cancellables)
    }
    
    func performSearch() async {
        guard !searchText.isEmpty else { return }
        isSearching = true
        
        // 根据分类执行不同的搜索逻辑
        switch selectedCategory {
        case .map:
            await searchMapPlaces()
        case .service:
            // TODO: 服务搜索 API
            try? await Task.sleep(nanoseconds: 500_000_000)
        case .order:
            // TODO: 订单搜索 API
            try? await Task.sleep(nanoseconds: 500_000_000)
        case .download:
            // TODO: 下载文件搜索 API
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        isSearching = false
    }
    
    private func searchMapPlaces() async {
        let lat = userCoordinate?.latitude ?? 39.9
        let lon = userCoordinate?.longitude ?? 116.4
        let radius = 20000 // 默认搜索半径20km
        
        let url = "/petFriendly/client/getNearbyPlaces"
        var components = URLComponents(string: url)!
        components.queryItems = [
            URLQueryItem(name: "longitude", value: "\(lon)"),
            URLQueryItem(name: "latitude", value: "\(lat)"),
            URLQueryItem(name: "radius", value: "\(radius)"),
            URLQueryItem(name: "placeName", value: searchText)
        ]
        
        do {
            let resp: PlaceListResp = try await NetworkManager.shared.request(components.url!.absoluteString, method: .get)
            self.mapResults = resp.rows
        } catch {
            print("Global Map Search Error: \\(error)")
            self.mapResults = []
        }
    }
}

// MARK: - 主视图
struct GlobalSearchView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = GlobalSearchViewModel()
    @FocusState private var isSearchFocused: Bool
    @State private var selectedPlace: PetFriendlyPlace? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. 顶部自定义导航栏 + 搜索框
            searchHeaderRow
            
            // 2. 分类菜单
            categoryMenuBar
            
            // 3. 搜索内容区域
            ZStack {
                PFColors.background.ignoresSafeArea()
                
                if viewModel.searchText.isEmpty {
                    emptyPromptView
                } else if viewModel.isSearching {
                    PFPetLoadingView("search_loading", size: 36)
                } else {
                  searchResultsView
                }
            }
        }
        .pfToyBackground()
        .sheet(item: $selectedPlace) { place in
            PlaceDetailView(place: place)
        }
        .onAppear {
            // 自动拉起键盘
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSearchFocused = true
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Header
    private var searchHeaderRow: some View {
        HStack(spacing: PFSpacing.md) {
            HStack(spacing: PFSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(PFColors.textTertiary)
                
                TextField("search_placeholder", text: $viewModel.searchText)
                    .font(PFFonts.body)
                    .foregroundColor(PFColors.textPrimary)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await viewModel.performSearch() }
                    }
              
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(PFColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, PFSpacing.md)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(PFColors.surfaceSecondary)
            )
        }
        .padding(.horizontal, PFSpacing.lg)
        .padding(.top, 10)
        .padding(.bottom, PFSpacing.sm)
        .background(PFColors.background)
    }
    
    // MARK: - 分类菜单栏
    private var categoryMenuBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PFSpacing.lg) {
                ForEach(GlobalSearchCategory.allCases, id: \.self) { category in
                    categoryItemView(for: category)
                }
            }
            .padding(.horizontal, PFSpacing.lg)
        }
        .background(PFColors.surface)
        .pfElevatedShadow(.black.opacity(0.05))
    }
    
    private func categoryItemView(for category: GlobalSearchCategory) -> some View {
        let isSelected = viewModel.selectedCategory == category
        return VStack(spacing: 6) {
            Text(category.localizedTitle)
                .font(isSelected ? PFFonts.headline : PFFonts.body)
                .foregroundColor(isSelected ? PFColors.primary : PFColors.textSecondary)
            
            // 下划线指示器
            Rectangle()
                .fill(isSelected ? PFColors.primary : Color.clear)
                .frame(height: 3)
                .cornerRadius(1.5)
        }
        .padding(.top, 10)
        .onTapGesture {
            withAnimation(PFAnimation.ease) {
                viewModel.selectedCategory = category
            }
        }
    }
    
    // MARK: - 搜索结果渲染
    @ViewBuilder
    private var searchResultsView: some View {
        switch viewModel.selectedCategory {
        case .map:
            if viewModel.mapResults.isEmpty {
                noResultPromptView
            } else {
                List(viewModel.mapResults) { place in
                    PlaceCardView(place: place, onTapCard: {
                        // 留空或绑定事件
                    }, onDetailTap: {
                        selectedPlace = place
                    })
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
            }
            
        case .service, .order, .download:
            // 其余状态目前留空显示 API 占位
            noResultPromptView
        }
    }
    
    // MARK: - 辅助占位页
    private var emptyPromptView: some View {
        VStack(spacing: PFSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(PFColors.textTertiary.opacity(0.5))
            Text(NSLocalizedString("search_empty_prompt", comment: ""))
                .font(PFFonts.body)
                .foregroundColor(PFColors.textSecondary)
      }
        .frame(maxHeight: .infinity)
    }
    
    private var noResultPromptView: some View {
        VStack(spacing: PFSpacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(PFColors.textTertiary.opacity(0.5))
            Text(String(format: NSLocalizedString("search_no_results", comment: ""), viewModel.searchText))
                .font(PFFonts.body)
                .foregroundColor(PFColors.textSecondary)
      }
        .frame(maxHeight: .infinity)
    }
}
