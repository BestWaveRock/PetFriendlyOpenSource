import Foundation
import MapKit
import Combine
import CoreLocation
import WeatherKit

class MapViewModel: ObservableObject {
    static let shared = MapViewModel()
    @Published var places: [PetFriendlyPlace] = []
    @Published var filteredPlaces: [PetFriendlyPlace] = []
    @Published var placeTypes: [DictData] = []
    @Published var centerCoordinate: CLLocationCoordinate2D?
    @Published var currentRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
    
    @Published var selectedPlace: PetFriendlyPlace? // For sheet detail    
    @Published var searchText = ""
    @Published var selectedCategory = "全部"
    
    // Filters
    @Published var onlyLookFriendly = false
    @Published var onlyLookFavorite = false
    @Published var searchRadius: Int = 5000 // 默认 5KM (单位：米)
    @Published var isLoading = false
    @Published var totalPlaces: Int = 0
    
    // Weather Info (iOS 27+)
    @Published var weatherTemp: String = "26°"
    @Published var weatherSymbol: String = "sun.max.fill"
    @Published var weatherCondition: String = NSLocalizedString("weather_sunny", comment: "")
    @Published var isLoadingWeather: Bool = false
    @Published var maxLimit: Int = 100 // 当前用户等级最多可查看条数
    @Published var targetRegion: MKCoordinateRegion?
    @Published var highlightedPlaceId: Int64? // 列表点击后高亮的场所 ID
    
    // Pagination (分页)
    @Published var pageNum: Int = 1
    @Published var pageSize: Int = 20
    @Published var hasMoreData: Bool = true
    @Published var isLoadingMore: Bool = false
    
    // Recent Searches (最近搜索, UserDefaults 持久化)
    @Published var recentSearches: [String] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(recentSearches) {
                UserDefaults.standard.set(data, forKey: "pf_recent_searches")
            }
        }
    }
    
    /// 指南建议：距离最近且评分 >= 4.5 的友好地
    var guideSuggestion: PetFriendlyPlace? {
        filteredPlaces
            .filter { $0.rate >= 4.5 }
            .sorted { ($0.distanceM ?? Int.max) < ($1.distanceM ?? Int.max) }
            .first
    }
    
    /// 最近收藏的 1 个地点
    var recentFavorite: PetFriendlyPlace? {
        filteredPlaces.first { $0.favoriteId != nil && $0.favoriteId != 0 }
    }
    
    // Location
    private let locationManager = LocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 从 UserDefaults 恢复最近搜索
        if let data = UserDefaults.standard.data(forKey: "pf_recent_searches"),
           let saved = try? JSONDecoder().decode([String].self, from: data) {
            self.recentSearches = saved
        }
        setupSubscriptions()
        fetchDictData()
        setupFavoriteSync()
    }
    
    /// 添加搜索记录
    func addRecentSearch(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentSearches.removeAll { $0 == trimmed }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > 3 {
            recentSearches = Array(recentSearches.prefix(3))
        }
    }
    
    private func setupFavoriteSync() {
        NotificationCenter.default.publisher(for: .PFPlaceFavoriteChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let self = self,
                      let userInfo = note.userInfo,
                      let isFav = userInfo["isFavorite"] as? Bool else { return }
                
                let pid: Int64
                if let idString = userInfo["placeId"] as? String {
                    pid = Int64(idString) ?? 0
                } else if let idInt = userInfo["placeId"] as? Int64 {
                    pid = idInt
                } else if let idInt = userInfo["placeId"] as? Int {
                    pid = Int64(idInt)
                } else {
                    return
                }
                
                // 同步 places 列表
                var changed = false
                for i in 0..<self.places.count {
                    if self.places[i].placeId == pid {
                        var p = self.places[i]
                        p.favoriteId = isFav ? 1 : nil 
                        self.places[i] = p
                        changed = true
                    }
                }
                
                if changed {
                    self.applyFilters()
                    // 强制触发 UI 刷新，防止某些组件不响应 filteredPlaces 内容变化
                    self.objectWillChange.send()
                }
                print("🔄 MapViewModel: 同步场所 \(pid) 收藏状态 -> \(isFav)")
            }
            .store(in: &cancellables)
    }
    
    func setupSubscriptions() {
        // Location updates
        locationManager.$location
            .compactMap { $0 }
            .first() // Only take first location to center map initially
            .receive(on: RunLoop.main)
            .sink { [weak self] loc in
                guard let self = self else { return }
                print("📍 MapViewModel: Initial location received: \(loc.coordinate)")
                self.centerCoordinate = loc.coordinate
                self.currentRegion.center = loc.coordinate
                // 1. 立即触发一次带缩放的数据拉取
                self.resetAndFetch(at: loc.coordinate, shouldZoom: true)
                // 2. 确保启动时自动缩放到 20km 搜索范围
                self.zoomToNearest10()
            }
            .store(in: &cancellables)
            
        // 文本搜索 + 分类筛选 — 需要 debounce 防抖（输入场景）
        Publishers.CombineLatest(
            $searchText,
            $selectedCategory
        )
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, let center = self.centerCoordinate else { return }
                self.resetAndFetch(at: center, shouldZoom: true, forceRefresh: true)
            }
            .store(in: &cancellables)
        
        // 开关类筛选 — 立即触发服务端重新请求（无 debounce）
        // 附近距离档位切换 (20Km, 50Km, 1000Km)
        $searchRadius
            .dropFirst()
            .sink { [weak self] _ in
                guard let self = self, let center = self.centerCoordinate else { return }
                self.resetAndFetch(at: center, shouldZoom: true, forceRefresh: true)
                // 修复：切换距离单位时，同步更新地图缩放比例
                self.zoomToNearest10()
            }
            .store(in: &cancellables)
        
        // 只看友好
        $onlyLookFriendly
            .dropFirst()
            .sink { [weak self] _ in
                guard let self = self, let center = self.centerCoordinate else { return }
                self.resetAndFetch(at: center, shouldZoom: true, forceRefresh: true)
            }
            .store(in: &cancellables)
        
        // 只看收藏 — 与服务端 favoriteFlag 联动
        $onlyLookFavorite
            .dropFirst()
            .sink { [weak self] _ in
                guard let self = self, let center = self.centerCoordinate else { return }
                self.resetAndFetch(at: center, shouldZoom: true, forceRefresh: true)
            }
            .store(in: &cancellables)
        
        // Auto-move on category change
        $selectedCategory
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // Delay slightly to wait for applyFilters
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if let first = self?.filteredPlaces.first {
                        self?.centerCoordinate = first.coordinate
                    }
                }
            }
            .store(in: &cancellables)
        
        // 与全局搜索文本同步
        UIState.shared.$searchText
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] newSearch in
                // 仅在文本真的变化时才触发，避免重复刷新
                if self?.searchText != newSearch {
                    self?.searchText = newSearch
                    // searchText 的变化会自动触发上面的 CombinedLatest 订阅
                }
            }
            .store(in: &cancellables)
    }
    
    private var lastFetchCoordinate: CLLocationCoordinate2D?
    
    /// 重置分页并重新请求第一页数据
    /// - Parameters:
    ///   - coordinate: 地图中心坐标
    ///   - shouldZoom: 是否同时调整地图缩放
    ///   - forceRefresh: 是否忽略 100 米距离优化强制刷新（筛选条件变化时使用）
    func resetAndFetch(at coordinate: CLLocationCoordinate2D, shouldZoom: Bool = false, forceRefresh: Bool = false) {
        // 性能优化：如果移动距离小于 100 米且不是强制缩放/筛选，不重复请求地点数据，但仍刷新天气
        if !forceRefresh, let last = lastFetchCoordinate {
            let lastLoc = CLLocation(latitude: last.latitude, longitude: last.longitude)
            let newLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if lastLoc.distance(from: newLoc) < 100 && !shouldZoom {
                refreshWeather(at: coordinate)
                return
            }
        }
        
        lastFetchCoordinate = coordinate
        pageNum = 1
        hasMoreData = true
        fetchPlaces(at: coordinate, page: 1, isLoadMore: false, shouldZoom: shouldZoom)
        
        // 实时加载当前视窗天气数据
        refreshWeather(at: coordinate)
    }
    
    /// 加载下一页数据
    func loadNextPage() {
        guard hasMoreData, !isLoadingMore, !isLoading else { return }
        guard let center = centerCoordinate else { return }
        pageNum += 1
        fetchPlaces(at: center, page: pageNum, isLoadMore: true, shouldZoom: false)
    }
    
    func fetchPlaces(at coordinate: CLLocationCoordinate2D, page: Int = 1, isLoadMore: Bool = false, shouldZoom: Bool = false) {
        Task {
            await MainActor.run {
                if isLoadMore {
                    self.isLoadingMore = true
                } else {
                    self.isLoading = true
                }
            }
            do {
                let radius = self.searchRadius
                let url = "/petFriendly/client/getNearbyPlaces"
                var components = URLComponents(string: url)!
                components.queryItems = [
                    URLQueryItem(name: "longitude", value: "\(coordinate.longitude)"),
                    URLQueryItem(name: "latitude", value: "\(coordinate.latitude)"),
                    URLQueryItem(name: "radius", value: "\(radius)"),
                    URLQueryItem(name: "favoriteFlag", value: "\(onlyLookFavorite ? 1 : 0)"),
                    URLQueryItem(name: "friendlyFlag", value: "\(onlyLookFriendly ? 1 : 0)"),
                    URLQueryItem(name: "pageNum", value: "\(page)"),
                    URLQueryItem(name: "pageSize", value: "\(pageSize)")
                ]
                if !searchText.isEmpty {
                    components.queryItems?.append(URLQueryItem(name: "placeName", value: searchText))
                }
                // 分类筛选
                if selectedCategory != "全部" {
                    if let type = placeTypes.first(where: { $0.dictLabel == selectedCategory }) {
                        components.queryItems?.append(URLQueryItem(name: "placeType", value: type.dictValue))
                    }
                }
                
                let resp: PlaceListResp = try await NetworkManager.shared.request(components.url!.absoluteString, method: .get)
                await MainActor.run {
                    self.isLoading = false
                    self.isLoadingMore = false
                    
                    // 锁定首屏统计
                    if !isLoadMore {
                        self.totalPlaces = resp.total ?? resp.rows.count
                    }
                    
                    // 解析显示限额
                    if let msg = resp.msg, msg.hasPrefix("MAX_LIMIT:") {
                        let limitStr = msg.replacingOccurrences(of: "MAX_LIMIT:", with: "")
                        if let limit = Int(limitStr) {
                            self.maxLimit = limit
                        }
                    }
                    
                    if isLoadMore {
                        // 追加数据
                        self.places.append(contentsOf: resp.rows)
                    } else {
                        // 替换数据（首页）
                        self.places = resp.rows
                    }
                    
                    // 判断是否还有更多数据
                    if resp.rows.isEmpty || resp.rows.count < self.pageSize {
                        self.hasMoreData = false
                    }
                    
                    for p in resp.rows {
                        print("📌 [FetchPlaces p\(page)] name=\(p.name), lat=\(p.latitude), lng=\(p.longitude), placeId=\(p.placeId ?? 0)")
                    }
                    self.applyFilters()
                    if !isLoadMore && shouldZoom {
                        self.zoomToNearest10()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.isLoadingMore = false
                }
                print("Fetch places error: \(error)")
            }
        }
    }
    
    func fetchDictData() {
        Task {
            do {
                // /system/dict/data/type/pet_friendly_place_type
                // Assuming response common structure
                let resp: DictDataResp = try await NetworkManager.shared.request("/petFriendly/client/dictType/pet_friendly_place_type", method: .get)
                await MainActor.run {
                    self.placeTypes = resp.data
                    // Add "全部"
                    self.placeTypes.insert(DictData(dictCode: 0, dictLabel: "全部", dictValue: "全部"), at: 0)
                }
            } catch {
                print("Fetch dict error: \(error)")
            }
        }
    }
    
    func applyFilters() {
        // 筛选条件已由服务端处理，此处仅做本地搜索文本的二次过滤
        var result = places
        
        // 本地搜索文本兜底过滤
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        self.filteredPlaces = result
    }
    
    func focus(on place: PetFriendlyPlace) {
        self.centerCoordinate = place.coordinate
    }
    
    /// 将目标地点定位到地图上半部分可见区域
    /// 列表展开时占据屏幕下半部（约55%），因此将地图中心向南偏移，
    /// 使目标坐标出现在地图视图的上部 1/3 位置
    /// 将首次获取数据的调用也走 resetAndFetch
    func initialFetch(at coordinate: CLLocationCoordinate2D) {
        resetAndFetch(at: coordinate)
    }
    
    func focusUpperHalf(on place: PetFriendlyPlace) {
        // 对于特定缩放要求：场所详情定位时缩放至 1km 比例尺
        // 不再这里手动计算 shiftedCenter，交给 MapViewRepresentable 的 updateUIView 统一处理偏移系数
        self.centerCoordinate = place.coordinate
        self.targetRegion = MKCoordinateRegion(
            center: place.coordinate,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
        // 高亮选中的场所，直到下一个被选择或地图被缩放/移动
        self.highlightedPlaceId = place.placeId
    }
    
    func focusCurrentLocation() {
        guard let center = centerCoordinate else { return }
        self.targetRegion = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
    }
    
    /// 自动缩放到指定地点的搜索半径范围 (如 20km, 50km)
    func zoomToNearest10() {
        guard let center = centerCoordinate else { return }
        let radius: Double = Double(searchRadius)
        // 缩放范围应包含完整的圆圈，因此直径是半径的两倍，额外加一点边距系数 (2.2) 更加美观
        self.targetRegion = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radius * 1.8,
            longitudinalMeters: radius * 1.8
        )
    }
    
    /// 统一更新搜索半径，并同步更新地图缩放目标
    func updateSearchRadius(_ radius: Int) {
        self.searchRadius = radius
        // 立即触发一次缩放更新，减少 UI 异步延迟
        self.zoomToNearest10()
        
        if let center = self.centerCoordinate {
            self.resetAndFetch(at: center, shouldZoom: true)
        }
    }
    
    private var weatherTask: Task<Void, Never>?
    
    /// 统一入口：iOS 16+ 使用 WeatherKit，否则使用 Open-Meteo 免费接口
    func refreshWeather(at coordinate: CLLocationCoordinate2D) {
        weatherTask?.cancel()
        weatherTask = Task {
            // 防抖 300ms，避免用户拖拽地图时频繁重发天气请求
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            
            await MainActor.run { self.isLoadingWeather = true }
            
            defer {
                Task { @MainActor in
                    self.isLoadingWeather = false
                }
            }
            
            await fetchWeatherKitOrFallback(at: coordinate)
        }
    }
    
    /// 异步获取当前屏幕中心天气数据 (iOS 16+)
    func fetchWeather(at coordinate: CLLocationCoordinate2D) {
        refreshWeather(at: coordinate)
    }
    
    private func fetchWeatherKitOrFallback(at coordinate: CLLocationCoordinate2D) async {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let weather = try await WeatherService.shared.weather(for: location)
            let current = weather.currentWeather
            let tempVal = current.temperature.converted(to: .celsius).value
            await MainActor.run {
                self.weatherTemp = String(format: "%.0f°", tempVal)
                self.weatherSymbol = current.symbolName
                self.weatherCondition = getLocalizedCondition(current.condition)
                self.isLoadingWeather = false
            }
        } catch {
            print("WeatherKit fetch failed: \(error), fallback to Open-Meteo.")
            await fetchWeatherFromOpenMeteo(coordinate: coordinate)
        }
    }
    
    /// Open-Meteo 免费天气接口（无需 API Key，国内可访问）
    func fetchWeatherFromOpenMeteo(coordinate: CLLocationCoordinate2D) async {
        let urlString = String(format: "https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f&current_weather=true",
                               coordinate.latitude, coordinate.longitude)
        guard let url = URL(string: urlString) else {
            await applyMockWeather()
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteoCurrentWeather.self, from: data)
            await MainActor.run {
                self.weatherTemp = String(format: "%.0f°", decoded.currentWeather.temperature)
                self.weatherSymbol = Self.openMeteoSymbol(for: decoded.currentWeather.weathercode)
                self.weatherCondition = Self.openMeteoCondition(for: decoded.currentWeather.weathercode)
                self.isLoadingWeather = false
            }
        } catch {
            print("Open-Meteo fetch failed: \(error), using mock weather.")
            await applyMockWeather()
        }
    }
    
    @MainActor
    private func applyMockWeather() {
        self.weatherTemp = "26°"
        self.weatherSymbol = "sun.max.fill"
        self.weatherCondition = NSLocalizedString("weather_sunny", comment: "")
        self.isLoadingWeather = false
    }
    
    private static func openMeteoSymbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2, 3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67, 80, 81, 82: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "sun.max.fill"
        }
    }
    
    private static func openMeteoCondition(for code: Int) -> String {
        switch code {
        case 0: return NSLocalizedString("weather_sunny", comment: "")
        case 1, 2, 3: return NSLocalizedString("weather_cloudy", comment: "")
        case 45, 48: return NSLocalizedString("weather_fog", comment: "")
        case 51, 53, 55, 56, 57: return NSLocalizedString("weather_drizzle", comment: "")
        case 61, 63, 65, 66, 67, 80, 81, 82: return NSLocalizedString("weather_rain", comment: "")
        case 71, 73, 75, 77, 85, 86: return NSLocalizedString("weather_snow", comment: "")
        case 95, 96, 99: return NSLocalizedString("weather_thunder", comment: "")
        default: return NSLocalizedString("weather_sunny", comment: "")
        }
    }
    
    private func getLocalizedCondition(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear: return NSLocalizedString("weather_sunny", comment: "")
        case .cloudy: return NSLocalizedString("weather_cloudy", comment: "")
        case .mostlyCloudy: return NSLocalizedString("weather_cloudy", comment: "")
        case .partlyCloudy: return NSLocalizedString("weather_partly", comment: "")
        case .rain: return NSLocalizedString("weather_rain", comment: "")
        case .heavyRain: return NSLocalizedString("weather_heavyrain", comment: "")
        case .drizzle: return NSLocalizedString("weather_drizzle", comment: "")
        case .snow: return NSLocalizedString("weather_snow", comment: "")
        case .heavySnow: return NSLocalizedString("weather_heavysnow", comment: "")
        case .thunderstorms: return NSLocalizedString("weather_thunder", comment: "")
        case .windy: return NSLocalizedString("weather_windy", comment: "")
        case .foggy: return NSLocalizedString("weather_foggy", comment: "")
        case .haze: return NSLocalizedString("weather_haze", comment: "")
        default: return NSLocalizedString("weather_sunny", comment: "")
        }
    }
}

// MARK: - Weather Models
/// Open-Meteo 免费天气接口响应模型（无需 API Key）
struct OpenMeteoCurrentWeather: Decodable {
    let currentWeather: OpenMeteoWeatherData
    
    enum CodingKeys: String, CodingKey {
        case currentWeather = "current_weather"
    }
}

struct OpenMeteoWeatherData: Decodable {
    let temperature: Double
    let weathercode: Int
    let windspeed: Double
}

// Models
struct PlaceListResp: Decodable {
    let rows: [PetFriendlyPlace]
    let total: Int?
    let msg: String?
}

struct DictDataResp: Decodable, Encodable {
    let data: [DictData]
}

struct DictData: Identifiable, Decodable, Encodable, Hashable {
    let dictCode: Int?
    let dictLabel: String
    let dictValue: String
    
    var id: String { dictValue }
}

// Location Manager Wrapper
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        location = loc
    }
}
