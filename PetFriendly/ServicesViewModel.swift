import Foundation
import Combine

class ServicesViewModel: ObservableObject {
    @Published var services: [ServiceItem] = []
    @Published var isLoading = false
    @Published var searchText: String = ""
    private var cancellables = Set<AnyCancellable>()
    
    private static var cachedServices: [ServiceItem]?
    private static var lastFetchTime: Date?
    
    init() {
        UIState.shared.$searchText
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] newSearch in
                if self?.searchText != newSearch {
                    self?.searchText = newSearch
                    if UIState.shared.selectedTab == 1 {
                        self?.fetchServices()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func fetchServices(force: Bool = false) {
        if !force && searchText.isEmpty {
            if let lastTime = Self.lastFetchTime, Date().timeIntervalSince(lastTime) < 300 {
                if let cached = Self.cachedServices {
                    self.services = cached
                    return
                }
            }
        }
        
        isLoading = true
        Task {
            do {
                var url = "/petFriendly/client/getServiceList"
                if !searchText.isEmpty {
                    url += "?title=\(searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                }
                let resp: ServiceListResp = try await NetworkManager.shared.request(url, method: .get)
                await MainActor.run {
                    let newServices = resp.data ?? resp.rows ?? []
                    self.services = newServices
                    if self.searchText.isEmpty {
                        Self.cachedServices = newServices
                        Self.lastFetchTime = Date()
                    }
                    self.isLoading = false
                }
            } catch {
                print("Fetch services error: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }
}

struct ServiceListResp: Decodable {
    let code: Int?
    let msg: String?
    let data: [ServiceItem]?
    // 如果是分页格式可能在 rows 里面
    let rows: [ServiceItem]?
}

struct ServiceItem: Identifiable, Decodable {
    @Int64String var serviceId: Int64?
    
    // 保证唯一性，防止 SwiftUI 列表渲染和 AsyncImage 取消复用 Bug
    var id: String { "\(serviceId ?? 0)_\(title ?? UUID().uuidString)" }
    
    var title: String?
    var subTitle: String?
    var icon: String?
    var serviceMainPicture: String?
    var jumpPageUrl: String?
    var jumpPageType: String?
    
    // 手动映射
    enum CodingKeys: String, CodingKey {
        case serviceId
        case title, subTitle, icon, serviceMainPicture, jumpPageUrl, jumpPageType
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // 使用 decodeIfPresent 避免 @Int64String 触发 keyNotFound 崩溃
        self.serviceId = try container.decodeIfPresent(Int64String.self, forKey: .serviceId)?.wrappedValue
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.subTitle = try container.decodeIfPresent(String.self, forKey: .subTitle)
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon)
        self.serviceMainPicture = try container.decodeIfPresent(String.self, forKey: .serviceMainPicture)
        self.jumpPageUrl = try container.decodeIfPresent(String.self, forKey: .jumpPageUrl)
        self.jumpPageType = try container.decodeIfPresent(String.self, forKey: .jumpPageType)
    }
    
    // View 层原先期待的计算属性
    var serviceName: String { title ?? NSLocalizedString("unknown_service", comment: "") }
    var description: String? { subTitle }
    var router: String? { jumpPageUrl }
    
    /// 是否为外部链接（管理端配置 jumpPageType=1：jumpPageUrl 是外部 http URL）
    var isExternalLink: Bool { jumpPageType == "1" }

    /// 有效的跳转 URL（外部链接用）
    var jumpURL: URL? {
        guard isExternalLink, let s = jumpPageUrl, !s.isEmpty else { return nil }
        return URL(string: s.hasPrefix("http") ? s : "https://\(s)")
    }

    var iconUrl: URL? {
        let path = serviceMainPicture ?? icon
        guard let i = path, !i.isEmpty else { return nil }
        if i.hasPrefix("http") { return URL(string: i) }
        return nil
    }
}
