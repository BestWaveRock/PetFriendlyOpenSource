//
//  NetworkManager.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 22/9/25.
//
import Foundation
import CommonCrypto
import Alamofire
import CryptoKit                    // 用于随机 AES 密钥
import Security                     // 用于 RSA 加密
import SwiftUI
import UniformTypeIdentifiers

/// 后端统一返回格式
struct RespWrapper<T: Decodable>: Decodable {
    let code: Int
    let msg: String?
    let data: T?
}

struct BoolResp: Decodable {
    let code: Int
    let msg: String?
    let data: Bool?
}

struct UploadResponse: Decodable {
    let code: Int
    let data: String?
    let msg: String?
}

/// 自己抛出的错误
enum BizError: LocalizedError {
    case http(code: Int, msg: String)   // 500、400 等
    case biz(code: Int, msg: String)    // 业务自定义 1xxx、2xxx …
    
    var errorDescription: String? {
        switch self {
        case .http(_, let msg), .biz(_, let msg):
            return msg
        }
    }

    /// 服务端 5xx 由网络层统一展示；调用方仍可据此结束加载或保持当前页面状态。
    var isSystemError: Bool {
        switch self {
        case .http(let code, _), .biz(let code, _):
            return code >= 500
        }
    }
}

// MARK: - 万能占位解码器
struct JSONAny: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self)   { value = v; return }
        if let v = try? container.decode(Int.self)    { value = v; return }
        if let v = try? container.decode(Double.self) { value = v; return }
        if let v = try? container.decode(String.self) { value = v; return }
        if let v = try? container.decode([JSONAny].self) { value = v.map{$0.value}; return }
        if let v = try? container.decode([String: JSONAny].self) { value = v.mapValues{$0.value}; return }
        value = [:]   // 兜底
    }
}

/// 从接口返回的 data 中解析订单ID（Long，JSON 数字可能解为 Int/Double/NSNumber）
func orderId(from data: JSONAny?) -> Int64? {
    guard let value = data?.value else { return nil }
    if let i = value as? Int { return Int64(i) }
    if let i = value as? Int64 { return i }
    if let d = value as? Double { return Int64(d) }
    if let n = value as? NSNumber { return n.int64Value }
    if let s = value as? String, let i = Int64(s) { return i }
    return nil
}

// MARK: - API 日志记录器（调试用）
func apiTitle(from url: String) -> String {
    let path = url.replacingOccurrences(of: ".*/petFriendly/client/", with: "", options: .regularExpression)
        .replacingOccurrences(of: "\\?.*", with: "", options: .regularExpression)
    let titles: [String: String] = [
        "assetsRecordList": "积分收支记录",
        "mallOrderList": "积分兑换订单",
        "serviceOrderList": "服务订单列表",
        "dispatchHall/list": "派单大厅",
        "dispatchHall/grab": "抢单",
        "mall/list": "积分商品列表",
        "mall/buy": "积分兑换",
        "place/list": "场所列表",
        "place/detail": "场所详情",
        "service/book": "预约服务",
        "comment/list": "评论列表",
        "comment/add": "发表评论",
        "getNamecard": "获取名片",
        "myContributions": "我的贡献",
        "user/info": "用户信息",
    ]
    for (key, title) in titles {
        if path.contains(key) {
            return title
        }
    }
    return path
}

func formatParameters(_ params: [String: Any]?) -> String {
    guard let params = params, !params.isEmpty else { return "(空)" }
    if let data = try? JSONSerialization.data(withJSONObject: params, options: [.sortedKeys]),
       let str = String(data: data, encoding: .utf8) {
        return str
    }
    return params.description
}

struct ApiLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let url: String
    let method: String
    let headers: [String: String]
    let parameters: String
    let responseCode: Int?
    let responseBody: String?
    let error: String?
    let duration: Double // ms
}

final class ApiLogger {
    static let shared = ApiLogger()
    private var logs: [ApiLogEntry] = []
    private let maxLogs = 200
    private let queue = DispatchQueue(label: "api-logger")
    private var _isEnabled: Bool = false

    /// 是否启用 API 日志记录，受 App 内"调试模式"开关控制
    var isEnabled: Bool {
        queue.sync { _isEnabled }
    }

    /// 设置启用状态；关闭时同时清空已缓存日志
    func setEnabled(_ enabled: Bool) {
        queue.sync {
            _isEnabled = enabled
            if !enabled {
                logs.removeAll()
            }
        }
    }

    var allLogs: [ApiLogEntry] {
        queue.sync { Array(logs) }
    }
    
    func add(entry: ApiLogEntry) {
        queue.sync {
            guard _isEnabled else { return }
            logs.append(entry)
            if logs.count > maxLogs {
                logs.removeFirst(logs.count - maxLogs)
            }
        }
    }
    
    func clear() {
        queue.sync { logs.removeAll() }
    }
}

final class NetworkManager {
    static let shared = NetworkManager()

    private static func validatedBaseURL(_ candidate: String?) -> String {
        guard let candidate, let url = URL(string: candidate), let scheme = url.scheme?.lowercased() else {
            return Secrets.defaultBaseURL
        }
#if DEBUG
        guard scheme == "https" || scheme == "http" else { return Secrets.defaultBaseURL }
        return candidate
#else
        guard scheme == "https",
              let productionHost = URL(string: Secrets.defaultBaseURL)?.host,
              url.host == productionHost else {
            return Secrets.defaultBaseURL
        }
        return candidate
#endif
    }
    
    /// 基础地址：优先从系统设置读取（支持彩蛋修改），缺省使用外部配置默认值
    var baseURL: String = NetworkManager.validatedBaseURL(UserDefaults.standard.string(forKey: "api_base_url")) {
        didSet {
            let validated = NetworkManager.validatedBaseURL(baseURL)
            if validated != baseURL {
                baseURL = validated
                return
            }
            UserDefaults.standard.set(validated, forKey: "api_base_url")
        }
    }
    // 加密公钥
    private let encryptPublicKey = Secrets.encryptPublicKey
    // 解密私钥
    private let encryptPrivateKey = Secrets.encryptPrivateKey
    // 客户端ID
    private let clientId = Secrets.clientId
    
    // 1. 私有存储属性
    private var _token: String? {
        get { KeychainManager.shared.get(forKey: "access_token") }
        set {
            if let val = newValue {
                KeychainManager.shared.set(val, forKey: "access_token")
            } else {
                KeychainManager.shared.delete(forKey: "access_token")
            }
        }
    }
    // 2. 对外只读
    var token: String? { _token }
    // 3. 对外写入
    func setToken(_ newToken: String?) {
        _token = newToken
    }
    func clearToken() {
        _token = nil
    }
    
    // --- Session Configuration ---
    
    private lazy var session: Session = {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = 30
        return Session(configuration: configuration)
    }()

    private lazy var uploadSession: Session = {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = 180
        // Use a longer resource timeout for uploads to ensure server processing time
        configuration.timeoutIntervalForResource = 300 
        return Session(configuration: configuration)
    }()

    /// AI 生图等耗时较长的请求专用会话（证件照生成可能长达数分钟）
    private lazy var longSession: Session = {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 600
        return Session(configuration: configuration)
    }()
    
    private init() {}
    
    /// 静态工具：将相对路径转为完整 URL
    static func fullUrl(_ path: String?) -> URL? {
        guard let path = path, !path.isEmpty else { return nil }
        if path.hasPrefix("http") {
            return URL(string: path)
        }
        // 拼接基础地址。注意：shared.baseURL 可能是 https://your-api.domain.com/prod-api
        // 通常上传的文件在服务器根目录下，或者在 prod-api 下有映射
        let base = shared.baseURL
        if let url = URL(string: base),
           let scheme = url.scheme,
           let host = url.host {
            let portStr = url.port != nil ? ":\(url.port!)" : ""
            let serverRoot = "\(scheme)://\(host)\(portStr)"
            
            // 如果路径不包含 /prod-api 且不是以 http 开头，尝试拼接到 serverRoot
            // 针对 RuoYi 的常见情况：/profile/upload 映射在 serverRoot/profile/upload
            let safePath = path.hasPrefix("/") ? path : "/\(path)"
            return URL(string: serverRoot + safePath)
        }
        return URL(string: base + path)
    }
    
    // 通用异步请求，支持字典参数 + 自动解码
    func request<T: Decodable>(_ path: String,
                             method: HTTPMethod = .get,
                             parameters: Parameters? = nil,
                             encoding: ParameterEncoding = URLEncoding.default,
                             needToken: Bool = true,
                             encryptFlag: Bool = false,
                             showLoading: Bool = true,
                             longTimeout: Bool = false) async throws -> T {
        
        // 字典缓存拦截判断
        if path.contains("/client/dictType/") {
            if let cachedData = DictCacheManager.shared.getCache(for: path) {
                do {
                    let decoded = try JSONDecoder().decode(T.self, from: cachedData)
                    #if DEBUG
                    print("命中缓存 [Dict]: \(path)")
                    #endif
                    return decoded
                } catch {
                    #if DEBUG
                    print("缓存数据解析失败 [Dict]: \(path), 将重新发起请求")
                    #endif
                }
            }
        }
        
        let url = baseURL + path               // 你的基础地址
        #if DEBUG
        print("🛜 request \(url)")    // 你的基础地址
        if let params = parameters,
           let jsonData = try? JSONSerialization.data(withJSONObject: params, options: .prettyPrinted),
           let prettyString = String(data: jsonData, encoding: .utf8) {
            print("""
             ==============>
             原始请求参数: \(prettyString)
             <==============
             """)
        }
        #endif
        
        if showLoading {
            DispatchQueue.main.async {
                AppState.shared.isRequestDown = true
            }
        }
        let start = CFAbsoluteTimeGetCurrent()
        
        // 先拷贝一份可变的
        let parameters = parameters
        
        var headers: HTTPHeaders = [
            "Content-Type": "application/json;charset=UTF-8",
            "X-APP-KEY": Secrets.appKey,
            "Content-Language": "zh_CN",
            "CliendId": clientId
        ]
        if needToken, let tk = token {
            headers.add(.authorization(bearerToken: tk))
        }
        
        // 最终要发出去的 Body（可能是原始 JSON，也可能是加密后的字符串）
        var httpBody: Data?
        
        if encryptFlag,
           let params = parameters {

            // 如果想把密钥存到 Keychain，先转 Data
            let key = randomAlphanumeric(32)
            // 2. 先 Base64 编码成字符串
            let aesKeyBase64 = key.data(using: .utf8)!.base64EncodedString()

            // 3. 把 Base64 字符串当二进制再 RSA 加密
            let aesKeyBase64Data = Data(aesKeyBase64.utf8)          // UTF-8 字节流
            let rsaCipherB64 = try rsaEncrypt(aesKeyBase64Data, publicKeyPEM: encryptPublicKey)

            // 4. 放进 header
            headers.add(name: "Encrypt-Key", value: rsaCipherB64)
            
            // 3. parameters → JSON 字符串
            let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
            guard let jsonStr = String(data: jsonData, encoding: .utf8) else {
                throw NSError(domain: "Encrypt", code: -1,
                               userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("err_json", comment: "")])
            }
            
            // 4. AES-256-ECB_PKCS5 加密
            let cipherData = try aesEncryptECB_PKCS5(string: jsonStr, key: aesKeyBase64)
            let dataBase64 = cipherData.base64EncodedString()
            httpBody = Data(dataBase64.utf8)
            
            #if DEBUG
            print("[Security] Payload encrypted via AES-256.")
            #endif
        } else if let params = parameters {
            httpBody = try JSONSerialization.data(withJSONObject: params, options: [])
        }
        
        // 构造 URLRequest 以便手动设置 body
        var urlRequest = try URLRequest(url: url, method: method, headers: headers)
        
        if method != .get, let body = httpBody {
            urlRequest.httpBody = body
        } else {
            // 把参数重新交给 AF，让它按 encoding 拼到 URL 或放 Body
            let encoding: ParameterEncoding = (method == .get) ? URLEncoding.default : JSONEncoding.default

            // 让 Alamofire 把参数拼到 URL 或放 Body
            urlRequest = try encoding.encode(urlRequest, with: parameters)
            print("Get 参数 set")
        }

        
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000   // 毫秒
        #if DEBUG
        print("""
        ==============>
        请求方式: \(method.rawValue)
        请求地址: \(url)
        请求头体: \(headers)
        入参处理耗时: \(String(format: "%.2f", elapsed)) ms
        <==============
        """)
        #endif
        let reqStart = CFAbsoluteTimeGetCurrent()
        
        // 真正发请求（耗时接口走长超时会话）
        let request = (longTimeout ? longSession : session).request(urlRequest)
            .validate()

        #if DEBUG
        // 挂事件监听（仅用于调试日志）
        request.response { resp in
            print("🔥 AF response: \(resp.response?.statusCode ?? 0), error: \(String(describing: resp.error))")
        }
        #endif

        // 再串行化数据
        let data: Data
        do {
            data = try await request.serializingData().value
        } catch {
            let statusCode = request.response?.statusCode ?? 0
            // 记录失败日志（网络层）
            let entry = ApiLogEntry(
                timestamp: Date(),
                url: url,
                method: method.rawValue,
                headers: headers.dictionary,
                parameters: formatParameters(parameters),
                responseCode: statusCode,
                responseBody: nil,
                error: error.localizedDescription,
                duration: (CFAbsoluteTimeGetCurrent() - reqStart) * 1000
            )
            ApiLogger.shared.add(entry: entry)
            if statusCode >= 500 {
                let unifiedMsg = NSLocalizedString("net_system_updating", comment: "")
                let bizError = BizError.http(code: statusCode, msg: unifiedMsg)
                presentSystemError(bizError)
                throw bizError
            }
            
            // 拦截超时错误 (NSURLErrorTimedOut = -1001)
            let nsError = (error as NSError)
            if nsError.code == NSURLErrorTimedOut || (error.asAFError?.underlyingError as NSError?)?.code == NSURLErrorTimedOut {
                Task { @MainActor in
                    UIState.shared.showToast(NSLocalizedString("err_network_timeout", comment: ""))
                }
            }
            throw error
        }
        
        let reqElapsed = (CFAbsoluteTimeGetCurrent() - reqStart) * 1000   // 毫秒
        
        if let body = httpBody,
            let jsonStr = String(data: body, encoding: .utf8),
            let jsonData = jsonStr.data(using: .utf8),
            let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
            let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
            let prettyString = String(data: prettyData, encoding: .utf8) {
            #if DEBUG
            print("""
             ==============>
             POST请求参数: \(prettyString)
             <==============
             """)
            #endif
        }
        
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8),
           let jsonData = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            print("""
            ==============>
            接口耗时: \(String(format: "%.2f", reqElapsed)) ms
            响应结果: \(prettyString)
            <==============
            """)
        } else {
            print("🔥 网络返回 内容展示 \(String(data: data, encoding: .utf8) ?? "")")
        }
        #endif
        
        if showLoading {
            DispatchQueue.main.async {
                AppState.shared.isRequestDown = false
            }
        }
        /* ====== 新增：拦截 500/业务错误 ====== */
        let wrapper: RespWrapper<JSONAny>
        do {
            wrapper = try JSONDecoder().decode(RespWrapper<JSONAny>.self, from: data)
            try errorFilter(code: wrapper.code, msg: wrapper.msg)
        } catch {
            // 记录业务错误日志
            let respBody = String(data: data, encoding: .utf8)
            let entry = ApiLogEntry(
                timestamp: Date(),
                url: url,
                method: method.rawValue,
                headers: headers.dictionary,
                parameters: formatParameters(parameters),
                responseCode: nil,
                responseBody: respBody,
                error: error.localizedDescription,
                duration: reqElapsed
            )
            ApiLogger.shared.add(entry: entry)
            throw error
        }

        /* =================================== */

        // 如果 code == 200 再走正常解析
        let decodedResponse: T
        do {
            decodedResponse = try JSONDecoder().decode(T.self, from: data)
        } catch {
            let respBody = String(data: data, encoding: .utf8)
            let entry = ApiLogEntry(
                timestamp: Date(),
                url: url,
                method: method.rawValue,
                headers: headers.dictionary,
                parameters: formatParameters(parameters),
                responseCode: wrapper.code,
                responseBody: respBody,
                error: "JSON解码失败: \(error.localizedDescription)",
                duration: reqElapsed
            )
            ApiLogger.shared.add(entry: entry)
            throw error
        }
        
        // 字典数据缓存写入
        if path.contains("/client/dictType/") && (wrapper.code == 200 || wrapper.code == 0) {
            DictCacheManager.shared.setCache(data: data, for: path)
        }
        
        // API 日志记录（始终记录响应体，便于在任意构建下排查接口问题）
        let respBody = String(data: data, encoding: .utf8)
        let entry = ApiLogEntry(
            timestamp: Date(),
            url: url,
            method: method.rawValue,
            headers: headers.dictionary,
            parameters: formatParameters(parameters),
            responseCode: wrapper.code,
            responseBody: respBody,
            error: nil,
            duration: reqElapsed
        )
        ApiLogger.shared.add(entry: entry)
        
        return decodedResponse
    }
    
    func errorFilter(code: Int, msg: String?) throws {
        if code == 401 {
            // Token 失效或被踢出，必须强制重登，并终止任何登录/登出加载态。
            DispatchQueue.main.async {
                AccountStore.shared.handleSession(.tokenExpired)
                NetworkManager.shared.clearToken()
                AccountStore.shared.logout()
                UIState.shared.showGlobalLogin = true
            }
            throw BizError.biz(code: code, msg: NSLocalizedString("net_session_expired", comment: ""))
        }
        if code >= 500 {                 // 系统异常、服务更新等
            // 保留服务端文案；仅将展示渠道统一为全局错误通知。
            let errorMsg = msg ?? NSLocalizedString("net_service_recovering", comment: "")
            let bizError = BizError.biz(code: code, msg: errorMsg)
            presentSystemError(bizError)
            throw bizError
        }
        if code != 200 && code != 0 {                 // 其他业务异常
            let errorMsg = msg ?? NSLocalizedString("net_service_recovering", comment: "")
            // 不弹 toast，让调用方自行处理错误展示
            throw BizError.biz(code: code, msg: errorMsg)
        }
    }

    /// 5xx 不由各页面截获后各自改写文案，统一使用全局错误通知展示服务端消息。
    private func presentSystemError(_ error: BizError) {
        guard error.isSystemError else { return }
        showErrorAlert(error)
    }
    
    
    /// 统一上传文件（图片 or 任意文件）
    /// - Parameters:
    ///   - path: 接口路径，如 /system/user/profile/avatar
    ///   - fileData: 文件二进制
    ///   - fileName: 文件名（服务端用）
    ///   - mimeType: 如 image/jpeg
    ///   - formData: 其它额外字段，可空
    ///   - onProgress: 进度回调 (0.0 ~ 1.0)
    ///   - suppressGlobalUI: 为 true 时不驱动全局上传弹窗（如聊天内图片上传，进度由气泡蒙版展示）
    /// - Returns: 业务模型 T
    func upload<T: Decodable>(
        path: String = "/petFriendly/client/upload",
        fileData: Data,
        mimeType: String,
        fileName: String = "x.jpg",
        formData: [String: String]? = nil,
        onProgress: ((Double) -> Void)? = nil,
        suppressGlobalUI: Bool = false
    ) async throws -> T {

        let url = baseURL + path
        var headers: HTTPHeaders = [
            "X-APP-KEY": Secrets.appKey,
            "CliendId": clientId
        ]
        if let tk = token { headers.add(.authorization(bearerToken: tk)) }

        let mp = MultipartFormData()
        formData?.forEach { mp.append($0.value.data(using: .utf8)!, withName: $0.key) }
        mp.append(fileData, withName: "file", fileName: fileName, mimeType: mimeType)
        
        print("""
        ==============>
        [UPLOAD] 开始上传: \(url)
        MIME 类型: \(mimeType)
        数据大小: \(ByteCountFormatter.string(fromByteCount: Int64(fileData.count), countStyle: .file))
        请求头: \(headers)
        <==============
        """)
        
        // 更新全局上传状态（聊天内上传需抑制全局弹窗，由气泡蒙版展示进度）
        if !suppressGlobalUI {
            await MainActor.run {
                UIState.shared.isUploading = true
                UIState.shared.uploadProgress = 0
                UIState.shared.isUploadFinished = false
            }
        }
        
        let start = CFAbsoluteTimeGetCurrent()

        let request = uploadSession.upload(multipartFormData: mp,
                                to: url,
                                headers: headers)
            .uploadProgress { progress in
                let percent = String(format: "%.2f", progress.fractionCompleted * 100)
                print("[UPLOAD] 进度: \(percent)%, (总大小: \(progress.totalUnitCount) bytes)")
                onProgress?(progress.fractionCompleted)
                
                // 同步更新全局进度
                if !suppressGlobalUI {
                    Task { @MainActor in
                        UIState.shared.uploadProgress = progress.fractionCompleted
                    }
                }
            }
            .validate()

        let data: Data
        do {
            data = try await request.serializingData().value
        } catch {
            let statusCode = request.response?.statusCode ?? 0
            if statusCode >= 500 {
                let unifiedMsg = NSLocalizedString("net_system_updating", comment: "")
                let bizError = BizError.http(code: statusCode, msg: unifiedMsg)
                presentSystemError(bizError)
                throw bizError
            }
            
            // 拦截超时错误 (NSURLErrorTimedOut = -1001)
            let nsError = (error as NSError)
            if nsError.code == NSURLErrorTimedOut || (error.asAFError?.underlyingError as NSError?)?.code == NSURLErrorTimedOut {
                Task { @MainActor in
                    UIState.shared.showToast(NSLocalizedString("err_network_timeout", comment: ""))
                }
            }
            
            // 失败时也关闭上传蒙层
            if !suppressGlobalUI {
                await MainActor.run {
                    UIState.shared.isUploading = false
                }
            }
            
            throw error
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        
        if let jsonString = String(data: data, encoding: .utf8),
           let jsonData = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            print("""
            ==============>
            [UPLOAD] 上传完成: \(url)
            耗时: \(String(format: "%.2f", elapsed)) ms
            响应结果: \(prettyString)
            <==============
            """)
        }

        /* =================================== */
        /* ====== 改进：更健壮的响应体解析 ====== */
        // 使用 JSONSerialization 快速检查 code，避免 RespWrapper<JSONAny> 可能的解析开销或异常
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = json["code"] as? Int {
            let msg = json["msg"] as? String
            try errorFilter(code: code, msg: msg)
            
            if let resultData = json["data"] {
                print("[UPLOAD] 业务解析成功, Data: \(resultData)")
            }
        }

        // 成功后延迟关闭蒙层，展示“打勾”状态（聊天内上传跳过，进度由气泡蒙版控制）
        if !suppressGlobalUI {
            await MainActor.run {
                UIState.shared.uploadProgress = 1.0
                UIState.shared.isUploadFinished = true
            }
            
            // 给用户 0.8s 看到打勾状态，然后自动消失
            try? await Task.sleep(nanoseconds: 800_000_000)
            
            await MainActor.run {
                UIState.shared.isUploading = false
                UIState.shared.isUploadFinished = false
            }
        }

        // 如果 code == 200 再走正常解析
        return try JSONDecoder().decode(T.self, from: data) // ← 不会再出现 UInt8 报错
    }

    func uploadChatFile(_ fileURL: URL,
                        onProgress: ((Double) -> Void)? = nil) async throws -> String {
        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer { if accessed { fileURL.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: fileURL)
        let mimeType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        let response: RespWrapper<String> = try await upload(
            fileData: data,
            mimeType: mimeType,
            fileName: fileURL.lastPathComponent,
            onProgress: onProgress,
            suppressGlobalUI: true
        )
        guard let remoteURL = response.data else {
            throw NSError(domain: "Upload", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg ?? NSLocalizedString("err_upload_code", comment: "")])
        }
        return remoteURL
    }
    
    
    /// 上传图片并返回 URL
    func uploadImage(_ image: UIImage,
                     to path: String = "/petFriendly/client/upload",
                     onProgress: ((Double) -> Void)? = nil,
                     suppressGlobalUI: Bool = false) async throws -> String {
        // 用户要求不压缩，使用 1.0
        guard let data = image.jpegData(compressionQuality: 1.0) else {
            throw NSError(domain: "Image", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("err_img_conv", comment: "")])
        }
        let resp: RespWrapper<String> = try await upload(path: path, fileData: data, mimeType: "image/jpeg", onProgress: onProgress, suppressGlobalUI: suppressGlobalUI)
        guard let url = resp.data else {
             throw NSError(domain: "Upload", code: resp.code, userInfo: [NSLocalizedDescriptionKey: resp.msg ?? NSLocalizedString("err_upload_code", comment: "")])
        }
        return url
    }

    /// 上传聊天图片，返回 (原图URL, 缩略图URL)。
    /// 后端 /petFriendly/client/uploadImage 在同一次上传中额外生成 800px 缩略图，
    /// 聊天列表只显示缩略图以提升加载速度；原图以质量 1.0 保存不压缩。
    func uploadChatImage(_ image: UIImage,
                         to path: String = "/petFriendly/client/uploadImage",
                         onProgress: ((Double) -> Void)? = nil,
                         suppressGlobalUI: Bool = true) async throws -> (url: URL, thumbURL: URL?) {
        // 聊天上传保留原图质量不压缩（用户要求）；体积优化交给后端缩略图
        guard let data = image.jpegData(compressionQuality: 1.0) else {
            throw NSError(domain: "Image", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("err_img_conv", comment: "")])
        }
        struct ImageUploadResult: Decodable {
            let url: String
            let thumbUrl: String
        }
        let resp: RespWrapper<ImageUploadResult> = try await upload(
            path: path, fileData: data, mimeType: "image/jpeg",
            onProgress: onProgress, suppressGlobalUI: suppressGlobalUI
        )
        guard let urlStr = resp.data?.url,
              let url = NetworkManager.fullUrl(urlStr) else {
            throw NSError(domain: "Upload", code: resp.code,
                          userInfo: [NSLocalizedDescriptionKey: resp.msg ?? NSLocalizedString("err_upload_code", comment: "")])
        }
        var thumb: URL? = nil
        if let t = resp.data?.thumbUrl, !t.isEmpty, let tu = NetworkManager.fullUrl(t) {
            thumb = tu
        }
        return (url, thumb)
    }

    /// 语音转文字（ASR）：将 base64 音频发送到后端 /emergencyChat/asr，返回识别文本
    func speechToText(audioBase64: String, format: String = "wav") async throws -> String {
        struct ASRResp: Decodable {
            let code: Int
            let msg: String?
            let data: String?
        }
        let params: [String: String] = ["audio": audioBase64, "format": format]
        guard let url = URL(string: baseURL + "/petFriendly/client/emergencyChat/asr") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Secrets.appKey, forHTTPHeaderField: "X-APP-KEY")
        request.setValue(Secrets.clientId, forHTTPHeaderField: "CliendId")
        if let tk = token {
            request.setValue("Bearer \(tk)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: params)

        let (respData, _) = try await URLSession.shared.data(for: request)
        guard let resp = try? JSONDecoder().decode(ASRResp.self, from: respData) else {
            throw NSError(domain: "ASR", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("voice_parse_error", comment: "")])
        }
        if resp.code == 200, let text = resp.data, !text.isEmpty {
            return text
        }
        throw NSError(domain: "ASR", code: resp.code,
                      userInfo: [NSLocalizedDescriptionKey: resp.msg ?? NSLocalizedString("voice_recognize_failed", comment: "")])
    }
    
    
    // MARK: - AI 图片识别
    
    /// 上传图片到服务器进行 AI 识别，自动生成描述文字
    /// - Parameter imageUrl: 已上传图片的 URL（由 uploadImage 返回）
    /// - Returns: AI 生成的描述文本
    func aiDescribeImage(imageUrl: String) async throws -> String {
        let params: [String: Any] = ["imageUrl": imageUrl]
        let resp: RespWrapper<String> = try await request(
            "/petFriendly/client/aiDescribeImage",
            method: .post,
            parameters: params,
            needToken: true,
            showLoading: false
        )
        guard let description = resp.data, !description.isEmpty else {
            throw BizError.biz(code: resp.code, msg: resp.msg ?? NSLocalizedString("ai_desc_failed", comment: ""))
        }
        return description
    }
    
    /// 生成一次性的 32 位密钥
    func randomAlphanumeric(_ length: Int) -> String {
        let charset = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<length).map { _ in charset.randomElement()! })
    }

    /// AES-256-ECB + PKCS5Padding 加密（无 IV）
    /// - Parameters:
    ///   - string: 待加密明文
    ///   - key:    32 字节密钥（Base64 字符串）
    /// - Returns:  密文 Data
    private func aesEncryptECB_PKCS5(string: String, key: String) throws -> Data {
        guard let keyData = Data(base64Encoded: key) else {
            throw NSError(domain: "AES", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("err_b64", comment: "")])
        }
        precondition(keyData.count == kCCKeySizeAES256, "AES-256 密钥必须是 32 字节")
        let plainData = Data(string.utf8)

        let cryptLen = plainData.count + kCCBlockSizeAES128
        var cryptData = Data(count: cryptLen)
        var numBytes: size_t = 0

        let status = cryptData.withUnsafeMutableBytes { cryptBytes in
            plainData.withUnsafeBytes { plainBytes in
                keyData.withUnsafeBytes { keyBytes in
                    CCCrypt(CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
                            keyBytes.baseAddress, kCCKeySizeAES256,
                            nil,                    // ECB 无 IV
                            plainBytes.baseAddress, plainData.count,
                            cryptBytes.baseAddress, cryptLen,
                            &numBytes)
                }
            }
        }

        guard status == kCCSuccess else {
            throw NSError(domain: "AES", code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("err_aes", comment: "")])
        }
        cryptData.count = numBytes
        return cryptData
    }

    // MARK: - RSA/ECB/PKCS1Padding 一次加密
    private func rsaEncrypt(_ data: Data, publicKeyPEM: String) throws -> String {
        guard let secKey = try loadPublicKey(pem: publicKeyPEM) else {
            throw NSError(domain: "RSA", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("err_pubkey", comment: "")])
        }

        // 一次能加密的最大长度：keySize/8 - 11（PKCS1 填充）
        let blockSize = SecKeyGetBlockSize(secKey)
        let maxChunk = blockSize - 11
        guard data.count <= maxChunk else {
            throw NSError(domain: "RSA", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("err_rsa_len", comment: "")])
        }

        var error: Unmanaged<CFError>?
        guard let cipherData = SecKeyCreateEncryptedData(secKey, .rsaEncryptionPKCS1, data as CFData, &error) as Data? else {
            if let err = error?.takeRetainedValue() {
                throw err as Error
            } else {
                throw NSError(domain: "RSA", code: -3, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("err_rsa", comment: "")])
            }
        }
        return cipherData.base64EncodedString()
    }

    /// PEM 字符串 → SecKey
    private func loadPublicKey(pem: String) throws -> SecKey? {
        let stripped = pem
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        
        guard let data = Data(base64Encoded: stripped) else { return nil }
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 2048
        ]
        return SecKeyCreateWithData(data as CFData, attributes as CFDictionary, nil)
    }

    
}

struct NearbyPlaceResp: Decodable {
    let code: Int
    let msg: String?
    let rows: [NearbyPlaceRow]   // ✅ 这里 rows 就是我们要 of 数组
}

// NetworkManager+Nearby.swift

extension NetworkManager {
    
    /// 查询附近场所（回调版，内部用 NetworkManager.request）
    func getNearbyPlaces(lat: Double,
                         lon: Double,
                         radius: Int = 20000,
                         placeLevel: Int,
                         favoriteFlag: Bool = false,
                         name: String? = nil,
                         completion: @escaping (Result<[NearbyPlaceRow], Error>) -> Void) {
        
        print("🔍 NetworkManager.getNearbyPlaces called: lat=\(lat), lon=\(lon), name=\(name ?? "nil"), radius=\(String(radius)), placeLevel=\(String(placeLevel))")
        
        var param: [String: Any] = [
            "latitude": lat,
            "longitude": lon,
            "radius": radius,
            "placeLevel": placeLevel,
            "favoriteFlag": favoriteFlag,
            "pageSize": 100
        ]
        if let name = name, !name.isEmpty {
            param["placeName"] = name
        }
        
        // ✅ 用 Task 桥接 async/await → 回调
        Task.detached {
            do {
                // ✅ 这里用你自己的 NetworkManager.request
                let resp: NearbyPlaceResp = try await NetworkManager.shared.request(
                    "/petFriendly/client/getNearbyPlaces",
                    method: .get,
                    parameters: param,
                    encoding: URLEncoding.default,   // GET 查询串
                    needToken: true,
                    encryptFlag: false
                )
                
                if resp.code == 200 || resp.code == 0 {
                    print("🔥 网络返回 rows=\(resp.rows.count)")   // ← 新增
                    completion(.success(resp.rows))
                } else {
                    print("🔥 返回异常")   // ← 新增
                    completion(.failure(BizError.biz(code: resp.code,
                                                     msg: resp.msg ?? NSLocalizedString("err_biz", comment: ""))))
                }
            } catch {
                print("🔥 返回报错 \(error)")   // ← 新增
                completion(.failure(error))
            }
        }
    }
    
    func favoritePlaces(placeId: String?, favoriteId: String?,
                completion: @escaping (Result<BoolResp, Error>) -> Void) {
        
        guard let placeIdStr = placeId,
              let placeIdNum = UInt64(placeIdStr) else {
            completion(.failure(BizError.biz(code: -1,
                                             msg: NSLocalizedString("err_placeid", comment: ""))))
            return
        }

        var param: [String: Any] = ["placeId": placeIdNum]

        if let favStr = favoriteId,
           let favNum = UInt64(favStr) {
            param["favoriteId"] = favNum
        }
        Task.detached {
            do {
                let resp: BoolResp = try await NetworkManager.shared.request(
                    "/petFriendly/client/collectPlaces",
                    method: .get,
                    parameters: param,
                    encoding: URLEncoding.default,   // GET 查询串
                    encryptFlag: false
                )
                
                if resp.code == 200 || resp.code == 0 {
                    print("🔥 网络返回 rows=\(resp)")   // ← 新增
                    completion(.success(resp))
                } else {
                    print("🔥 返回异常")   // ← 新增
                    completion(.failure(BizError.biz(code: resp.code,
                                                     msg: resp.msg ?? NSLocalizedString("err_biz", comment: ""))))
                }
            } catch {
                print("🔥 返回报错 \(error)")   // ← 新增
                completion(.failure(error))
            }
        }
    }
    
    
    /// 回调式请求封装 (适配已有代码)
    func request<T: Decodable>(_ path: String,
                             method: HTTPMethod = .get,
                             parameters: Parameters? = nil,
                             completion: @escaping (Result<T, Error>) -> Void) {
        Task {
            do {
                let resp: T = try await request(path, method: method, parameters: parameters)
                completion(.success(resp))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// 原始数据请求 (用于获取 CSV 等非 JSON 资源)
    func requestRaw(_ path: String,
                  method: HTTPMethod = .get,
                  parameters: Parameters? = nil,
                  completion: @escaping (Result<Data, Error>) -> Void) {
        let url = baseURL + path
        let h = headers()
        
        session.request(url, method: method, parameters: parameters, headers: h)
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
                    completion(.success(data))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }

    private func headers() -> HTTPHeaders {
        var h = HTTPHeaders([
            "X-APP-KEY": Secrets.appKey,
            "CliendId": clientId
        ])
        if let tk = token {
            h.add(.authorization(bearerToken: tk))
        }
        return h
    }
}
