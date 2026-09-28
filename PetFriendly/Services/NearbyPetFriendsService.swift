import Foundation
import CoreLocation
import Alamofire
import Combine
import UIKit
import UserNotifications

struct NearbyFriendPet: Decodable, Identifiable {
    let petId: String
    let name: String?
    let petAvatar: String?
    let species: Int?
    let breeds: Int?
    let sex: Int?
    let birthday: String?
    let remark: String?
    var id: String { petId }

    enum CodingKeys: String, CodingKey { case petId, name, petAvatar, species, breeds, sex, birthday, remark }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        petId = try container.decode(String.self, forKey: .petId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        petAvatar = try container.decodeIfPresent(String.self, forKey: .petAvatar)
        species = container.flexibleInt(forKey: .species)
        breeds = container.flexibleInt(forKey: .breeds)
        sex = container.flexibleInt(forKey: .sex)
        birthday = try container.decodeIfPresent(String.self, forKey: .birthday)
        remark = try container.decodeIfPresent(String.self, forKey: .remark)
    }
}

struct NearbyFriend: Decodable, Identifiable, Hashable {
    let userId: String
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let userName: String?
    let userAvatar: String?
    let userBio: String?
    let loveLevel: Int?
    let distanceMeters: Double?
    let pets: [NearbyFriendPet]
    var id: String { userId }

    static func == (lhs: NearbyFriend, rhs: NearbyFriend) -> Bool {
        lhs.userId == rhs.userId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(userId)
    }

    init(userId: String, latitude: Double = 0, longitude: Double = 0, accuracy: Double? = nil,
         userName: String?, userAvatar: String?, userBio: String? = nil, loveLevel: Int? = nil,
         distanceMeters: Double? = nil, pets: [NearbyFriendPet] = []) {
        self.userId = userId; self.latitude = latitude; self.longitude = longitude; self.accuracy = accuracy
        self.userName = userName; self.userAvatar = userAvatar; self.userBio = userBio; self.loveLevel = loveLevel
        self.distanceMeters = distanceMeters; self.pets = pets
    }

    enum CodingKeys: String, CodingKey {
        case userId, latitude, longitude, accuracy, userName, userAvatar, userBio, loveLevel, distanceMeters, pets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        latitude = try container.requiredFlexibleDouble(forKey: .latitude)
        longitude = try container.requiredFlexibleDouble(forKey: .longitude)
        accuracy = container.flexibleDouble(forKey: .accuracy)
        userName = try container.decodeIfPresent(String.self, forKey: .userName)
        userAvatar = try container.decodeIfPresent(String.self, forKey: .userAvatar)
        userBio = try container.decodeIfPresent(String.self, forKey: .userBio)
        loveLevel = container.flexibleInt(forKey: .loveLevel)
        distanceMeters = container.flexibleDouble(forKey: .distanceMeters)
        pets = (try? container.decode([NearbyFriendPet].self, forKey: .pets)) ?? []
    }
}

private extension KeyedDecodingContainer {
    func flexibleDouble(forKey key: Key) -> Double? {
        if let value = try? decode(Double.self, forKey: key) { return value }
        if let value = try? decode(String.self, forKey: key) { return Double(value) }
        return nil
    }

    func requiredFlexibleDouble(forKey key: Key) throws -> Double {
        if let value = flexibleDouble(forKey: key) { return value }
        throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected a number or numeric string")
    }

    func flexibleInt(forKey key: Key) -> Int? {
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let value = try? decode(String.self, forKey: key) { return Int(value) }
        if let value = try? decode(Bool.self, forKey: key) { return value ? 1 : 0 }
        return nil
    }

    func flexibleString(forKey key: Key) -> String? {
        if let value = try? decode(String.self, forKey: key) { return value }
        if let value = try? decode(Double.self, forKey: key) { return String(value) }
        if let value = try? decode(Int.self, forKey: key) { return String(value) }
        return nil
    }
}

struct NearbySettings: Decodable { let enabled: Bool; let petIds: [String] }
struct NearbyMessageDTO: Decodable {
    let messageId: String
    let senderUserId: String
    let receiverUserId: String
    let messageType: String
    let content: String
    let createTime: String?
    let readTime: String?

    var serverDate: Date? {
        guard let createTime else { return nil }
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX", "yyyy-MM-dd'T'HH:mm:ssXXXXX"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = format.hasPrefix("yyyy-MM-dd HH") ? TimeZone(identifier: "Asia/Shanghai") : nil
            formatter.dateFormat = format
            if let date = formatter.date(from: createTime) { return date }
        }
        if let milliseconds = Double(createTime), milliseconds > 1_000_000_000_000 {
            return Date(timeIntervalSince1970: milliseconds / 1000)
        }
        return nil
    }

    enum CodingKeys: String, CodingKey { case messageId, senderUserId, receiverUserId, messageType, content, createTime, readTime }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageId = try container.decode(String.self, forKey: .messageId)
        senderUserId = try container.decode(String.self, forKey: .senderUserId)
        receiverUserId = try container.decode(String.self, forKey: .receiverUserId)
        messageType = try container.decode(String.self, forKey: .messageType)
        content = try container.decode(String.self, forKey: .content)
        createTime = container.flexibleString(forKey: .createTime)
        readTime = container.flexibleString(forKey: .readTime)
    }
}

struct NearbyMessagePreview: Equatable {
    let messageId: String
    let text: String
}

struct NearbyConversation: Decodable, Identifiable {
    let otherId: String
    let messageId: String
    let messageType: String
    let content: String
    let createTime: String?
    let lastActiveTime: String?
    let latitude: Double?
    let longitude: Double?
    let online: Bool
    let userName: String?
    let userAvatar: String?
    let pets: [NearbyFriendPet]
    var id: String { otherId }
    var friend: NearbyFriend { NearbyFriend(userId: otherId, latitude: latitude ?? 0, longitude: longitude ?? 0, userName: userName, userAvatar: userAvatar, pets: pets) }

    enum CodingKeys: String, CodingKey { case otherId, messageId, messageType, content, createTime, lastActiveTime, latitude, longitude, online, userName, userAvatar, pets }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        otherId = try c.decode(String.self, forKey: .otherId); messageId = try c.decode(String.self, forKey: .messageId)
        messageType = try c.decode(String.self, forKey: .messageType); content = try c.decode(String.self, forKey: .content)
        createTime = c.flexibleString(forKey: .createTime); lastActiveTime = c.flexibleString(forKey: .lastActiveTime)
        latitude = c.flexibleDouble(forKey: .latitude); longitude = c.flexibleDouble(forKey: .longitude)
        online = (c.flexibleInt(forKey: .online) ?? 0) == 1
        userName = try c.decodeIfPresent(String.self, forKey: .userName); userAvatar = try c.decodeIfPresent(String.self, forKey: .userAvatar)
        pets = (try? c.decode([NearbyFriendPet].self, forKey: .pets)) ?? []
    }
}

@MainActor
final class NearbyPetFriendsService: NSObject, ObservableObject, CLLocationManagerDelegate, URLSessionDataDelegate {
    static let shared = NearbyPetFriendsService()
    @Published var friends: [NearbyFriend] = []
    @Published var sharingEnabled = false
    @Published var selectedPetIds = Set<String>()
    @Published var location: CLLocation?
    @Published var errorMessage: String?
    @Published private(set) var messagePreviews: [String: NearbyMessagePreview] = [:]
    @Published var radiusMeters = 5000
    /// PassthroughSubject 逐条发出事件，避免并发消息覆盖单个 @Published 状态。
    let messageEvents = PassthroughSubject<NearbyMessageDTO, Never>()

    private let manager = CLLocationManager()
    private var lastSentAt = Date.distantPast
    private var eventTask: URLSessionDataTask?
    private var reconnectTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private lazy var eventSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    private var eventBuffer = Data()
    private var eventStartedAt = Date()
    private var eventURL: URL?
    private var previewDismissTasks: [String: Task<Void, Never>] = [:]

    override private init() {
        super.init()
        manager.delegate = self
        // 与 MapKit 用户蓝点采用接近的实时精度；请求发送仍由 8 秒节流控制。
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 2
    }

    func loadSettings() async {
        do {
            let response: RespWrapper<NearbySettings> = try await NetworkManager.shared.request("/petFriendly/client/nearbyFriends/settings", showLoading: false)
            sharingEnabled = response.data?.enabled == true
            selectedPetIds = Set(response.data?.petIds ?? [])
            if sharingEnabled { start() }
        } catch { errorMessage = error.localizedDescription }
    }

    func saveSettings(enabled: Bool, petIds: Set<String>) async throws {
        let _: RespWrapper<JSONAny> = try await NetworkManager.shared.request("/petFriendly/client/nearbyFriends/settings", method: .put,
            parameters: ["enabled": enabled, "petIds": Array(petIds)], encoding: JSONEncoding.default, showLoading: false)
        sharingEnabled = enabled; selectedPetIds = petIds
        if enabled { start() } else { stop() }
    }

    func start() {
        guard sharingEnabled, NetworkManager.shared.token != nil else { return }
        manager.requestWhenInUseAuthorization(); manager.startUpdatingLocation()
        startHeartbeat()
        if location != nil { connectEvents() }
    }

    func ensureRealtimeConnection() {
        guard NetworkManager.shared.token != nil else { return }
        if eventTask == nil { connectEvents() }
    }

    func stop() {
        manager.stopUpdatingLocation(); reconnectTask?.cancel(); reconnectTask = nil
        heartbeatTask?.cancel(); heartbeatTask = nil
        eventTask?.cancel(); eventTask = nil; friends = []
        Task { let _: RespWrapper<JSONAny>? = try? await NetworkManager.shared.request("/petFriendly/client/nearbyFriends/offline", method: .post, parameters: [:], encoding: JSONEncoding.default, showLoading: false) }
    }

    /// CLLocation 在设备静止时不会持续回调；独立心跳确保在线状态不会在 90 秒后过期。
    private func startHeartbeat() {
        guard heartbeatTask == nil else { return }
        heartbeatTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled, let self, self.sharingEnabled, let location = self.location else { continue }
                self.lastSentAt = Date()
                await self.publish(location)
                if self.eventTask == nil { self.connectEvents() }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last,
              latest.horizontalAccuracy >= 0,
              abs(latest.timestamp.timeIntervalSinceNow) < 30 else { return }
        Task { @MainActor in
            location = latest
            guard sharingEnabled, Date().timeIntervalSince(lastSentAt) >= 8 else { return }
            lastSentAt = Date(); await publish(latest)
            if eventTask == nil { connectEvents() }
        }
    }

    private func publish(_ value: CLLocation) async {
        do {
            let params: [String: Any] = ["latitude": value.coordinate.latitude, "longitude": value.coordinate.longitude, "accuracy": value.horizontalAccuracy]
            let _: RespWrapper<JSONAny> = try await NetworkManager.shared.request("/petFriendly/client/nearbyFriends/location", method: .post, parameters: params, encoding: JSONEncoding.default, showLoading: false)
            // SSE 可能被反向代理回收；每次位置心跳同步拉取快照，保证地图仍能实时出现其他宠友。
            await refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func refresh() async {
        guard let location else { return }
        do {
            let response: RespWrapper<[NearbyFriend]> = try await NetworkManager.shared.request("/petFriendly/client/nearbyFriends/users", parameters: ["latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude, "radiusMeters": radiusMeters], showLoading: false)
            friends = response.data ?? []
        } catch { errorMessage = error.localizedDescription }
    }

    private func connectEvents() {
        guard eventTask == nil, let location, let token = NetworkManager.shared.token else { return }
        var components = URLComponents(string: NetworkManager.shared.baseURL + "/petFriendly/client/nearbyFriends/events")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(location.coordinate.longitude)),
            URLQueryItem(name: "radiusMeters", value: String(radiusMeters))
        ]
        guard let url = components?.url else { return }
        var request = URLRequest(url: url); request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Secrets.appKey, forHTTPHeaderField: "X-APP-KEY"); request.setValue(Secrets.clientId, forHTTPHeaderField: "CliendId")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        eventBuffer.removeAll(keepingCapacity: true)
        eventStartedAt = Date()
        eventURL = url
        logEvent(method: "SSE CONNECT", responseCode: nil, body: nil, error: nil)
        eventTask = eventSession.dataTask(with: request)
        eventTask?.resume()
    }

    func updateRadius(_ meters: Int) {
        guard [5000, 10000, 20000].contains(meters), radiusMeters != meters else { return }
        radiusMeters = meters
        eventTask?.cancel(); eventTask = nil
        Task { await refresh(); connectEvents() }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        Task { @MainActor [weak self] in
            let status = (response as? HTTPURLResponse)?.statusCode
            self?.logEvent(method: "SSE CONNECT", responseCode: status, body: nil, error: nil)
        }
        completionHandler(.allow)
    }

    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        Task { @MainActor [weak self] in self?.consumeEventData(data) }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.sharingEnabled else { return }
            self.logEvent(
                method: "SSE DISCONNECT",
                responseCode: (task.response as? HTTPURLResponse)?.statusCode,
                body: nil,
                error: error?.localizedDescription ?? "连接已由服务端或反向代理结束"
            )
            self.eventTask = nil
            self.reconnectTask?.cancel()
            self.reconnectTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                self?.connectEvents()
            }
        }
    }

    private func consumeEventData(_ data: Data) {
        eventBuffer.append(data)
        // NPS/Nginx 等反向代理可能按 HTTP 标准传递 CRLF，统一为 LF 后再解析 SSE 帧。
        if let text = String(data: eventBuffer, encoding: .utf8), text.contains("\r\n") {
            eventBuffer = Data(text.replacingOccurrences(of: "\r\n", with: "\n").utf8)
        }
        let separator = Data("\n\n".utf8)
        while let range = eventBuffer.range(of: separator) {
            let block = eventBuffer.subdata(in: eventBuffer.startIndex..<range.lowerBound)
            eventBuffer.removeSubrange(eventBuffer.startIndex..<range.upperBound)
            guard let text = String(data: block, encoding: .utf8) else { continue }
            let event = text.split(separator: "\n").first(where: { $0.hasPrefix("event:") })?.dropFirst(6).trimmingCharacters(in: .whitespaces)
            let payload = text.split(separator: "\n").filter { $0.hasPrefix("data:") }.map { $0.dropFirst(5).trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
            if event == "message" {
                guard let payloadData = payload.data(using: .utf8) else {
                    logEvent(method: "SSE RECEIVE [message]", responseCode: 200, body: payload, error: "事件载荷不是有效 UTF-8")
                    continue
                }
                do {
                    let message = try JSONDecoder().decode(NearbyMessageDTO.self, from: payloadData)
                    messageEvents.send(message)
                    handleIncomingMessage(message)
                    logEvent(method: "SSE RECEIVE [message]", responseCode: 200, body: payload, error: nil)
                } catch {
                    let detail = Self.decodingDescription(error)
                    logEvent(method: "SSE RECEIVE [message]", responseCode: 200, body: payload, error: detail)
                }
                continue
            }
            guard event == "nearby" else {
                logEvent(method: "SSE RECEIVE [\(event ?? "unknown")]", responseCode: 200, body: payload, error: nil)
                continue
            }
            guard let payloadData = payload.data(using: .utf8) else {
                logEvent(method: "SSE RECEIVE [nearby]", responseCode: 200, body: payload, error: "事件载荷不是有效 UTF-8")
                continue
            }
            do {
                let snapshot = try JSONDecoder().decode([NearbyFriend].self, from: payloadData)
                friends = snapshot
                logEvent(
                    method: "SSE RECEIVE [nearby]",
                    responseCode: 200,
                    body: "解析成功：\(snapshot.count) 位附近宠友\n\n\(payload)",
                    error: nil
                )
            } catch {
                let detail = Self.decodingDescription(error)
                errorMessage = detail
                logEvent(method: "SSE RECEIVE [nearby]", responseCode: 200, body: payload, error: detail)
            }
        }
    }

    private func handleIncomingMessage(_ message: NearbyMessageDTO) {
        let currentUserId = AccountStore.shared.user?.userId.map { String($0) }
        guard message.senderUserId != currentUserId else { return }
        let preview = message.messageType == "image" ? NSLocalizedString("nearby_message_image_preview", comment: "") : message.content
        messagePreviews[message.senderUserId] = NearbyMessagePreview(messageId: message.messageId, text: preview)
        previewDismissTasks[message.senderUserId]?.cancel()
        previewDismissTasks[message.senderUserId] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            self?.messagePreviews.removeValue(forKey: message.senderUserId)
            self?.previewDismissTasks.removeValue(forKey: message.senderUserId)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        scheduleSystemNotification(message: message, preview: preview)
    }

    private func scheduleSystemNotification(message: NearbyMessageDTO, preview: String) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            let schedule = {
                Task { @MainActor in
                    let content = UNMutableNotificationContent()
                    content.title = self?.friends.first(where: { $0.userId == message.senderUserId })?.userName
                        ?? NSLocalizedString("nearby_message_notification_title", comment: "")
                    content.body = preview
                    content.sound = .default
                    content.userInfo = ["nearbyUserId": message.senderUserId]
                    center.add(UNNotificationRequest(identifier: "nearby-message-\(message.messageId)", content: content, trigger: nil))
                }
            }
            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional { schedule() }
            else if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in if granted { schedule() } }
            }
        }
    }

    private func logEvent(method: String, responseCode: Int?, body: String?, error: String?) {
        guard let url = eventURL else { return }
        ApiLogger.shared.add(entry: ApiLogEntry(
            timestamp: Date(),
            url: url.absoluteString,
            method: method,
            headers: ["Accept": "text/event-stream"],
            parameters: "latitude=\(location?.coordinate.latitude ?? 0), longitude=\(location?.coordinate.longitude ?? 0), radiusMeters=5000",
            responseCode: responseCode,
            responseBody: body,
            error: error,
            duration: Date().timeIntervalSince(eventStartedAt) * 1000
        ))
    }

    private static func decodingDescription(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else { return "SSE 解析失败：\(error.localizedDescription)" }
        switch decodingError {
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .keyNotFound(_, let context), .dataCorrupted(let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "SSE JSON 解码失败 [\(path.isEmpty ? "root" : path)]：\(context.debugDescription)"
        @unknown default:
            return "SSE JSON 解码失败：\(error.localizedDescription)"
        }
    }

    func messages(with userId: String) async throws -> [NearbyMessageDTO] {
        let response: RespWrapper<[NearbyMessageDTO]> = try await NetworkManager.shared.request("/petFriendly/client/nearbyFriends/conversations/\(userId)/messages", parameters: ["pageNum": 1, "pageSize": 50], showLoading: false)
        return (response.data ?? []).reversed()
    }

    func send(to userId: String, type: String, content: String) async throws -> NearbyMessageDTO {
        let response: RespWrapper<NearbyMessageDTO> = try await NetworkManager.shared.request("/petFriendly/client/nearbyFriends/conversations/\(userId)/messages", method: .post, parameters: ["messageType": type, "content": content], encoding: JSONEncoding.default, showLoading: false)
        guard let message = response.data else { throw BizError.biz(code: response.code, msg: response.msg ?? "") }; return message
    }

    func conversations() async throws -> [NearbyConversation] {
        let response: RespWrapper<[NearbyConversation]> = try await NetworkManager.shared.request("/petFriendly/client/nearbyFriends/conversations", showLoading: false)
        return response.data ?? []
    }

    func hideConversation(with userId: String) async throws {
        let _: RespWrapper<String> = try await NetworkManager.shared.request("/petFriendly/client/nearbyFriends/conversations/\(userId)", method: .delete, showLoading: false)
    }

    func block(_ userId: String) async throws {
        let _: BoolResp = try await NetworkManager.shared.request("/petFriendly/client/nearbyFriends/users/\(userId)/block", method: .post, parameters: [:], encoding: JSONEncoding.default, showLoading: false)
        friends.removeAll { $0.userId == userId }
    }
}
