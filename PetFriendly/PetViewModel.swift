import Foundation
import Combine
import SwiftUI
import Alamofire

class PetViewModel: ObservableObject {
    static let shared = PetViewModel()
    @Published var pets: [Pet] = []
    @Published var rescuePets: [Pet] = []
    @Published var hasMoreRescuePets = true
    @Published private(set) var isLoadingRescuePets = false
    private var rescuePage = 1
    private let rescuePageSize = 20
    @Published var deletedPets: [Pet] = []
    @Published var isLoading = false
    @Published var breedMap: [String: String] = [:] // petId -> localizedBreedName
    @Published var searchText: String = ""
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        UIState.shared.$searchText
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] newSearch in
                if self?.searchText != newSearch {
                    self?.searchText = newSearch
                    // 仅当在萌宠档案页或已经有数据时才自动刷新，或者由外部 onSubmit 触发
                    if UIState.shared.selectedTab == 2 {
                        self?.fetchPets()
                    }
                }
            }
            .store(in: &cancellables)
        
        // 自动初始化：如果已经有 token（已登录状态打开 App），默认拉取一次
        if NetworkManager.shared.token != nil {
            DispatchQueue.main.async {
                self.fetchPets()
            }
        }
    }
    
    func fetchPets(contactType: Int? = nil, loadMore: Bool = false) {
        // 未登录时不要请求，防止报错或冗余请求
        guard NetworkManager.shared.token != nil else { return }

        // 首屏请求和 LazyVStack 底部分页触发器可能在同一轮布局中同时出现。
        // 流浪宠物列表只允许一个在途请求，避免重复翻页和高频刷新造成界面假死。
        if contactType == 1 {
            guard !isLoadingRescuePets else { return }
            guard !loadMore || hasMoreRescuePets else { return }
            isLoadingRescuePets = true
        }
        
        isLoading = true
        Task {
            do {
                if contactType == 1 {
                    if !loadMore {
                        rescuePage = 1
                        hasMoreRescuePets = true
                    }
                }
                var url = (contactType == 1) ? "/petFriendly/client/strayAnimals" : "/petFriendly/client/myPets"
                var queryItems: [String] = []
                if contactType == 1 {
                    queryItems.append("pageNum=\(rescuePage)")
                    queryItems.append("pageSize=\(rescuePageSize)")
                }
                if !searchText.isEmpty {
                    queryItems.append("name=\(searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
                }
                // myPets 需要 contactType 过滤，strayAnimals 已经包含了
                if let type = contactType, url.contains("myPets") {
                    queryItems.append("contactType=\(type)")
                }
                
                if !queryItems.isEmpty {
                    url += "?" + queryItems.joined(separator: "&")
                }
                
                let resp: PetListResp = try await NetworkManager.shared.request(url, method: .get, needToken: true)
                await MainActor.run {
                    if contactType == 1 {
                        let rows = resp.rows ?? []
                        if loadMore { self.rescuePets.append(contentsOf: rows) }
                        else { self.rescuePets = rows }
                        self.hasMoreRescuePets = self.rescuePets.count < (resp.total ?? 0)
                        if self.hasMoreRescuePets { self.rescuePage += 1 }
                    } else {
                        self.pets = resp.rows ?? []
                    }
                    self.isLoading = false
                    if contactType == 1 { self.isLoadingRescuePets = false }
                    self.resolveBreedNames(for: contactType == 1 ? self.rescuePets : self.pets)
                }
            } catch {
                print("Fetch pets error: \(error)")
                await MainActor.run {
                    self.isLoading = false
                    if contactType == 1 { self.isLoadingRescuePets = false }
                }
            }
        }
    }
    
    /// 软删除（移至回收站）
    func deletePet(id: Int64) {
        Task {
            do {
                struct Empty: Decodable {}
                _ = try await NetworkManager.shared.request("/petFriendly/client/deletePet?petId=\(id)", method: .get, needToken: true) as Empty?
                await MainActor.run { showSuccessHUD(message: NSLocalizedString("pets_delete_success", comment: "")) }
                fetchPets()
            } catch {
                print("Delete pet error: \(error)")
            }
        }
    }
    
    @Published var isLoadingDeletedPets = false

    /// 获取已删除宠物列表
    func fetchDeletedPets() {
        isLoadingDeletedPets = true
        Task {
            do {
                let resp: PetListResp = try await NetworkManager.shared.request("/petFriendly/client/deletedPets", method: .get, needToken: true)
                await MainActor.run {
                    self.deletedPets = resp.data ?? resp.rows ?? []
                    self.isLoadingDeletedPets = false
                }
            } catch {
                print("Fetch deleted pets error: \(error)")
                await MainActor.run {
                    self.isLoadingDeletedPets = false
                }
            }
        }
    }
    
    /// 恢复已删除宠物
    func restorePet(id: Int64) {
        Task {
            do {
                struct Empty: Decodable {}
                _ = try await NetworkManager.shared.request("/petFriendly/client/restorePet?id=\(id)", method: .get, needToken: true) as Empty?
                await MainActor.run { showSuccessHUD(message: NSLocalizedString("pets_restore_success", comment: "")) }
                fetchDeletedPets()
            } catch {
                print("Restore pet error: \(error)")
            }
        }
    }
    
    /// 解析并缓存品种名称
    private func resolveBreedNames(for pets: [Pet]) {
        Task {
            let uniqueSpecies = Set(pets.compactMap { $0.species })
            var speciesDict: [Int: String] = [:]
            
            // 1. 获取 species 字典
            do {
                let sResp: DictDataResp = try await NetworkManager.shared.request("/petFriendly/client/dictType/pet_information_species", method: .get, needToken: true)
                for item in sResp.data {
                    if let val = Int(item.dictValue) {
                        speciesDict[val] = item.dictValue
                    }
                }
            } catch {
                print("Resolve species error: \(error)")
                return
            }
            
            // 2. 为每个 species 获取 breed 字典
            for sId in uniqueSpecies {
                guard let sValue = speciesDict[sId] else { continue }
                do {
                    let bResp: DictDataResp = try await NetworkManager.shared.request("/petFriendly/client/dictType/pet_information_breeds_\(sValue)", method: .get, needToken: true)
                    
                    let petsInSpecies = pets.filter { $0.species == sId }
                    await MainActor.run {
                        for pet in petsInSpecies {
                            if let bId = pet.breeds, let breed = bResp.data.first(where: { Int($0.dictValue) == bId }) {
                                self.breedMap[pet.petId] = breed.dictLabel
                            } else {
                                self.breedMap[pet.petId] = pet.breed ?? NSLocalizedString("pets_unknown_breed", comment: "")
                            }
                        }
                    }
                } catch {
                    print("Resolve breeds for species \(sValue) error: \(error)")
                }
            }
        }
    }
    
    /// 清空所有数据 (用于登出)
    @MainActor
    func clear() {
        self.pets = []
        self.deletedPets = []
        self.breedMap = [:]
        self.searchText = ""
    }
    
    // --- 启动优化：缓存最年幼宠物的头像 URL ---
    private static let ymdFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var smallestPetAvatarUrl: URL? {
        let formatter = Self.ymdFormatter
        
        // 1. 获取所有有头像的宠物
        let petsWithAvatar = pets.filter { $0.avatarUrl != nil }
        
        // 2. 按生日从晚到早排序（生日越晚 = 越小/年轻）
        let sortedPets = petsWithAvatar.sorted { p1, p2 in
            guard let d1Str = p1.birthday?.prefix(10).description, let d1 = formatter.date(from: d1Str) else { return false }
            guard let d2Str = p2.birthday?.prefix(10).description, let d2 = formatter.date(from: d2Str) else { return true }
            return d1 > d2 // d1 > d2 means d1 is more recent
        }
        
        return sortedPets.first?.avatarUrl
    }
}

// MARK: - 宠物表单 ViewModel (新增/编辑)
class PetFormViewModel: ObservableObject {
    @Published var speciesList: [DictData] = []
    @Published var breedList: [DictData] = []
    @Published var sexList: [DictData] = []
    
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var currentError: IdentifiableError?
    
    @MainActor
    func fetchSpecies() async {
        do {
            let resp: DictDataResp = try await NetworkManager.shared.request("/petFriendly/client/dictType/pet_information_species", method: .get, needToken: true)
            self.speciesList = resp.data
        } catch {
            print("Fetch species error: \(error)")
        }
    }
    
    @MainActor
    func fetchBreeds(for speciesValue: String) async {
        do {
            let resp: DictDataResp = try await NetworkManager.shared.request("/petFriendly/client/dictType/pet_information_breeds_\(speciesValue)", method: .get, needToken: true)
            self.breedList = resp.data
        } catch {
            print("Fetch breeds error: \(error)")
            self.breedList = []
        }
    }
    
    @MainActor
    func fetchSex() async {
        do {
            let resp: DictDataResp = try await NetworkManager.shared.request("/petFriendly/client/dictType/pet_information_sex", method: .get, needToken: true)
            self.sexList = resp.data
        } catch {
            print("Fetch sex error: \(error)")
        }
    }
    
    func addPet(name: String, species: Int, breed: Int, sex: Int, birthday: Date, petAvatar: Any?, contactType: Int = 0) async -> Bool {
        await MainActor.run { self.isLoading = true }
        
        var avatarPath = ""
        if let avatar = petAvatar {
            if let img = avatar as? UIImage {
                await MainActor.run {
                    UIState.shared.isUploading = true
                    UIState.shared.uploadProgress = 0
                    UIState.shared.isUploadFinished = false
                }
                do {
                    let result: UploadResponse = try await NetworkManager.shared.upload(
                        fileData: img.jpegData(compressionQuality: 1.0) ?? Data(),
                        mimeType: "image/jpeg",
                        onProgress: { progress in
                            Task { @MainActor in
                                UIState.shared.uploadProgress = progress
                            }
                        }
                    )
                    
                    await MainActor.run {
                        UIState.shared.uploadProgress = 1.0
                        UIState.shared.isUploadFinished = true
                    }
                    
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    
                    await MainActor.run {
                        UIState.shared.isUploading = false
                        UIState.shared.isUploadFinished = false
                    }
                    
                    if let d = result.data {
                        avatarPath = d
                        print("[DEBUG] addPet: 图片上传成功, URL=\(avatarPath)")
                    }
                } catch {
                    await MainActor.run {
                        UIState.shared.isUploading = false
                        UIState.shared.isUploadFinished = false
                        let format = NSLocalizedString("err_upload_avatar %@", comment: "")
                        self.errorMessage = String(format: format, error.localizedDescription)
                        self.currentError = IdentifiableError(self.errorMessage)
                        self.showError = true
                        self.isLoading = false
                    }
                    return false
                }
            } else if let str = avatar as? String {
                avatarPath = str
            }
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: birthday)
        
        let params: [String: Any] = [
            "name": name,
            "species": species,
            "breeds": breed,
            "sex": sex,
            "birthday": dateStr,
            "petAvatar": avatarPath,
            "contactType": contactType
        ]
        
        do {
            struct Empty: Decodable {}
            _ = try await NetworkManager.shared.request("/petFriendly/client/addPet", method: .post, parameters: params, encoding: JSONEncoding.default, needToken: true) as Empty?
            await MainActor.run { 
                self.isLoading = false 
                showSuccessHUD(message: NSLocalizedString("msg_add_pet_success", comment: ""))
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.currentError = IdentifiableError(self.errorMessage)
                self.showError = true
                self.isLoading = false
            }
            return false
        }
    }
    
    func updatePet(petId: String, name: String, species: Int, breed: Int, sex: Int, birthday: Date, petAvatar: Any?, contactType: Int = 0, voiceUrl: String? = nil) async -> Bool {
        await MainActor.run { self.isLoading = true }
        
        var avatarPath = ""
        if let avatar = petAvatar {
            if let img = avatar as? UIImage {
                await MainActor.run {
                    UIState.shared.isUploading = true
                    UIState.shared.uploadProgress = 0
                    UIState.shared.isUploadFinished = false
                }
                do {
                    let result: UploadResponse = try await NetworkManager.shared.upload(
                        fileData: img.jpegData(compressionQuality: 1.0) ?? Data(),
                        mimeType: "image/jpeg",
                        onProgress: { progress in
                            Task { @MainActor in
                                UIState.shared.uploadProgress = progress
                            }
                        }
                    )
                    
                    await MainActor.run {
                        UIState.shared.uploadProgress = 1.0
                        UIState.shared.isUploadFinished = true
                    }
                    
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    
                    await MainActor.run {
                        UIState.shared.isUploading = false
                        UIState.shared.isUploadFinished = false
                    }
                    
                    if let d = result.data {
                        avatarPath = d
                        print("[DEBUG] updatePet: 图片上传成功, URL=\(avatarPath)")
                    }
                } catch {
                    await MainActor.run {
                        UIState.shared.isUploading = false
                        UIState.shared.isUploadFinished = false
                        let format = NSLocalizedString("err_upload_avatar %@", comment: "")
                        self.errorMessage = String(format: format, error.localizedDescription)
                        self.currentError = IdentifiableError(self.errorMessage)
                        self.showError = true
                        self.isLoading = false
                    }
                    return false
                }
            } else if let str = avatar as? String {
                avatarPath = str
            }
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: birthday)
        
        let params: [String: Any] = [
            "petId": petId,
            "name": name,
            "species": species,
            "breeds": breed,
            "sex": sex,
            "birthday": dateStr,
            "petAvatar": avatarPath,
            "contactType": contactType,
            "voiceUrl": voiceUrl ?? ""
        ]
        
        do {
            struct Empty: Decodable {}
            _ = try await NetworkManager.shared.request("/petFriendly/client/updatePet", method: .post, parameters: params, encoding: JSONEncoding.default, needToken: true) as Empty?
            await MainActor.run { 
                self.isLoading = false 
                showSuccessHUD(message: NSLocalizedString("msg_edit_pet_success", comment: ""))
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.currentError = IdentifiableError(self.errorMessage)
                self.showError = true
                self.isLoading = false
            }
            return false
        }
    }
}

struct PetListResp: Decodable {
    let rows: [Pet]?
    let data: [Pet]?
    let total: Int?
}

struct Pet: Identifiable, Decodable {
    let petId: String
    let name: String
    let nickName: String?
    let breed: String?
    let species: Int?
    let breeds: Int?
    /// 流浪动物上报在转为待领养卡片前可能尚未确认性别。
    let sex: Int?
    let birthday: String?
    let petAvatar: String?
    let contactType: Int?
    let voiceUrl: String?
    
    let isBeautyDue: Bool?
    let isBirthdaySoon: Bool?
    let isVaccineDue: Bool?
    let updateTime: String?
    let status: Int?
    let ext1: String?
    let ext2: String?
    let ext3: String?
    
    var id: String { petId }
    
    var displayName: String { nickName ?? name }

    var strayStatusTitle: LocalizedStringKey { Pet.strayStatusKey(status ?? 0) }

    var reportAgeText: String {
        guard let value = birthday else { return "" }
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = formatter.date(from: value) else { return "" }
        let hours = max(0, Int(Date().timeIntervalSince(date) / 3600))
        if hours >= 24 { return String(format: NSLocalizedString("stray_report_elapsed_days_hours", comment: ""), hours / 24, hours % 24) }
        return String(format: NSLocalizedString("stray_report_elapsed_hours", comment: ""), hours)
    }

    static func strayStatusKey(_ value: Int) -> LocalizedStringKey {
        switch value {
        case 1: return "stray_status_pending_adoption"
        case 2: return "stray_status_rescued_pending_adoption"
        case 3: return "stray_status_adopted"
        default: return "stray_status_pending_rescue"
        }
    }
    
    var ageString: String {
        if contactType == 1 {
            guard let value = ext1, let months = Int(value), months >= 0 else {
                return NSLocalizedString("common_unknown", comment: "")
            }
            if months >= 12 {
                let years = months / 12
                let remainingMonths = months % 12
                let yearText = String(format: NSLocalizedString("pets_age_years %lld", comment: ""), years)
                let monthText = remainingMonths > 0 ? String(format: NSLocalizedString("pets_age_months %lld", comment: ""), remainingMonths) : ""
                return yearText + monthText
            }
            return String(format: NSLocalizedString("pets_age_months %lld", comment: ""), months)
        }
        guard let birthday, !birthday.isEmpty else { return NSLocalizedString("common_unknown", comment: "") }
        let bday = birthday.prefix(10).description
        guard
              let date = YMDFormatter.date(from: bday) else { return NSLocalizedString("pets_age_unknown", comment: "") }
        let components = Calendar.current.dateComponents([.year, .month], from: date, to: Date())
        let years = components.year ?? 0
        let months = components.month ?? 0
        
        if years > 0 {
            let yearStr = String(format: NSLocalizedString("pets_age_years %lld", comment: ""), years)
            let monthStr = months > 0 ? String(format: NSLocalizedString("pets_age_months %lld", comment: ""), months) : ""
            return yearStr + monthStr
        } else if months > 0 {
            return String(format: NSLocalizedString("pets_age_months %lld", comment: ""), months)
        } else {
            return NSLocalizedString("pets_age_just_born", comment: "")
        }
    }
    
    var formattedBirthday: String {
        guard let bday = birthday else { return NSLocalizedString("common_unknown", comment: "") }
        // 保持 yyyy-MM-dd 格式并确保精度
        return bday.trimmingCharacters(in: .whitespaces).prefix(10).description
    }
    
    var avatarUrl: URL? {
        guard let str = petAvatar, !str.isEmpty else { return nil }
        return str.hasPrefix("http") ? URL(string: str) : URL(string: Secrets.objectStorageBaseURL + str)
    }
    
    var voiceURL: URL? {
        guard let str = voiceUrl, !str.isEmpty else { return nil }
        return URL(string: str)
    }
    
    var daysUntilCleared: Int? {
        guard let updateStr = updateTime?.prefix(10).description,
              let date = YMDFormatter.date(from: updateStr) else { return nil }
        let expirationDate = Calendar.current.date(byAdding: .day, value: 360, to: date)!
        let components = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate)
        return max(0, components.day ?? 0)
    }
    
    private enum CodingKeys: String, CodingKey {
        case petId, name, nickName, breed, species, breeds, sex, birthday, petAvatar, contactType, voiceUrl
        case isBeautyDue, isBirthdaySoon, isVaccineDue, updateTime, status, ext1, ext2, ext3
    }
}

fileprivate let YMDFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

// iOS 27 现代化弹窗所需的错误结构体
struct IdentifiableError: Identifiable, LocalizedError {
    let id = UUID()
    let errorDescription: String?
    
    init(_ description: String) {
        self.errorDescription = description
    }
}
