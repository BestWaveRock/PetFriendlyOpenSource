import SwiftUI
import MapKit

struct NearbySharingSettingsView: View {
    @ObservedObject private var service = NearbyPetFriendsService.shared
    @ObservedObject private var pets = PetViewModel.shared
    @Environment(\.dismiss) private var dismiss
    @State private var enabled = false
    @State private var selected = Set<String>()
    @State private var saving = false

    var body: some View {
        List {
            Section {
                Toggle("nearby_sharing_toggle", isOn: $enabled)
            } footer: { Text("nearby_sharing_privacy_hint") }
            Section("nearby_choose_pets") {
                ForEach(pets.pets.filter { $0.contactType != 1 }) { pet in
                    Button { togglePet(pet.petId) } label: {
                        petSelectionRow(pet)
                    }
                }
            }
            Section("nearby_search_range") {
                Picker("nearby_search_range", selection: Binding(get: { service.radiusMeters }, set: { service.updateRadius($0) })) {
                    Text("5 km").tag(5000); Text("10 km").tag(10000); Text("20 km").tag(20000)
                }.pickerStyle(.segmented)
            }
        }
        .navigationTitle("nearby_sharing_title")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("common_save") { Task { await save() } }.disabled(saving || (enabled && selected.isEmpty)) } }
        .task {
            service.ensureRealtimeConnection()
            pets.fetchPets(); await service.loadSettings(); enabled = service.sharingEnabled; selected = service.selectedPetIds
        }
        .alert("nearby_choose_pet_required", isPresented: Binding(get: { enabled && selected.isEmpty }, set: { _ in })) { Button("common_ok") {} }
    }
    private func save() async {
        saving = true
        defer { saving = false }
        do {
            try await service.saveSettings(enabled: enabled, petIds: selected)
            let key = enabled ? "nearby_sharing_enabled_success" : "nearby_sharing_disabled_success"
            showSuccessHUD(message: NSLocalizedString(key, comment: ""))
            dismiss()
        } catch {
            service.errorMessage = error.localizedDescription
            UIState.shared.showToast(error.localizedDescription, style: .error)
        }
    }

    private func togglePet(_ petId: String) {
        if selected.contains(petId) { selected.remove(petId) }
        else { selected.insert(petId) }
    }

    private func petSelectionRow(_ pet: Pet) -> some View {
        let isSelected = selected.contains(pet.petId)
        return HStack(spacing: 12) {
            AsyncImage(url: NetworkManager.fullUrl(pet.petAvatar)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "pawprint.fill")
                    .foregroundColor(.secondary)
            }
            .frame(width: 42, height: 42)
            .clipShape(Circle())

            Text(pet.displayName).foregroundColor(.primary)
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
        }
    }

}

struct NearbyFriendsHomeView: View {
    @ObservedObject private var service = NearbyPetFriendsService.shared

    var body: some View {
        List {
            Section {
                NavigationLink(destination: NearbyConversationListView()) {
                    Label("nearby_conversation_history", systemImage: "message.fill")
                }
                NavigationLink(destination: NearbySharingSettingsView()) {
                    Label("nearby_sharing_title", systemImage: "location.circle.fill")
                }
            }
            Section("nearby_friends_in_range") {
                if service.friends.isEmpty { Text("nearby_no_online_friends").foregroundStyle(.secondary) }
                ForEach(service.friends) { friend in
                    NavigationLink(destination: NearbyFriendNamecardView(friend: friend)) {
                        NearbyFriendRow(friend: friend)
                    }
                }
            }
        }
        .navigationTitle("nearby_pet_friends_title")
        .task { service.ensureRealtimeConnection(); await service.refresh() }
    }
}

struct NearbyConversationListView: View {
    @ObservedObject private var service = NearbyPetFriendsService.shared
    @State private var conversations: [NearbyConversation] = []
    @State private var loading = true

    var body: some View {
        List {
            if loading && conversations.isEmpty { ProgressView().frame(maxWidth: .infinity) }
            else if conversations.isEmpty {
                VStack(spacing: 10) { Image(systemName: "message").font(.largeTitle); Text("nearby_no_conversations") }
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 40)
            }
            ForEach(conversations) { item in
                NavigationLink(destination: NearbyPrivateChatView(friend: item.friend)) {
                    NearbyConversationRow(item: item, currentLocation: service.location)
                }
                .swipeActions(edge: .leading) {
                    Button(role: .destructive) { Task { await hide(item) } } label: { Label("common_delete", systemImage: "trash") }
                }
            }
        }
        .navigationTitle("nearby_conversation_history")
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async { loading = true; conversations = (try? await service.conversations()) ?? []; loading = false }
    private func hide(_ item: NearbyConversation) async {
        do { try await service.hideConversation(with: item.otherId); conversations.removeAll { $0.id == item.id } }
        catch { UIState.shared.showToast(error.localizedDescription, style: .error) }
    }
}

private struct NearbyFriendRow: View {
    let friend: NearbyFriend
    var body: some View {
        HStack(spacing: 12) {
            NearbyAvatar(avatar: friend.userAvatar, pets: friend.pets)
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.userName ?? NSLocalizedString("nearby_pet_friend", comment: ""))
                HStack(spacing: 6) {
                    Circle().fill(.green).frame(width: 7, height: 7)
                    Text("nearby_online_now")
                    if let distance = friend.distanceMeters { Text("· \(formatDistance(distance))") }
                }.font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct NearbyConversationRow: View {
    let item: NearbyConversation
    let currentLocation: CLLocation?
    var body: some View {
        HStack(spacing: 12) {
            NearbyAvatar(avatar: item.userAvatar, pets: item.pets)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.userName ?? NSLocalizedString("nearby_pet_friend", comment: ""))
                Text(preview).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                Label(item.online ? NSLocalizedString("nearby_online_now", comment: "") : lastSeen, systemImage: item.online ? "circle.fill" : "clock")
                if let distance { Label(formatDistance(distance), systemImage: "location.fill") }
                Label(item.createTime ?? "", systemImage: "message.fill")
            }
            .font(.caption)
        }
    }
    private var preview: String { item.messageType == "image" ? NSLocalizedString("nearby_message_image_preview", comment: "") : item.messageType == "file" ? NSLocalizedString("nearby_message_file_preview", comment: "") : item.content }
    private var lastSeen: String { item.lastActiveTime.map { String(format: NSLocalizedString("nearby_last_seen_format", comment: ""), $0) } ?? NSLocalizedString("nearby_offline", comment: "") }
    private var distance: Double? { guard let currentLocation, let lat=item.latitude, let lng=item.longitude else { return nil }; return currentLocation.distance(from: CLLocation(latitude: lat, longitude: lng)) }
}

private struct NearbyAvatar: View {
    let avatar: String?; let pets: [NearbyFriendPet]
    var body: some View { ZStack(alignment: .bottomTrailing) {
        AsyncImage(url: NetworkManager.fullUrl(avatar)) { $0.resizable().scaledToFill() } placeholder: { Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary) }.frame(width: 48,height:48).clipShape(Circle())
        if let pet=pets.first { AsyncImage(url: NetworkManager.fullUrl(pet.petAvatar)) { $0.resizable().scaledToFill() } placeholder: { Image(systemName:"pawprint.fill") }.frame(width:22,height:22).clipShape(Circle()).overlay(Circle().stroke(.background,lineWidth:2)) }
    } }
}

private func formatDistance(_ meters: Double) -> String { meters < 1000 ? "\(Int(meters)) m" : String(format: "%.1f km", meters/1000) }

struct NearbyFriendProfileView: View {
    let friend: NearbyFriend
    @Environment(\.dismiss) private var dismiss
    @State private var showChat = false
    @State private var confirmBlock = false
    var body: some View {
        NavigationStack {
            ScrollView { VStack(spacing: 18) {
                AsyncImage(url: NetworkManager.fullUrl(friend.userAvatar)) { $0.resizable().scaledToFill() } placeholder: { Image(systemName:"person.crop.circle.fill").resizable().foregroundStyle(.secondary) }.frame(width:88,height:88).clipShape(Circle())
                Text(friend.userName ?? NSLocalizedString("nearby_pet_friend", comment: "")).font(.title2.bold())
                if let bio=friend.userBio, !bio.isEmpty { Text(bio).foregroundStyle(.secondary) }
                ForEach(friend.pets) { pet in HStack { AsyncImage(url: NetworkManager.fullUrl(pet.petAvatar)) { $0.resizable().scaledToFill() } placeholder: { Image(systemName:"pawprint.fill") }.frame(width:56,height:56).clipShape(RoundedRectangle(cornerRadius:14)); VStack(alignment:.leading) { Text(pet.name ?? "").font(.headline); if let remark=pet.remark { Text(remark).font(.caption).foregroundStyle(.secondary).lineLimit(2) } }; Spacer() }.padding().background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius:18)) }
                NavigationLink(destination: NearbyPrivateChatView(friend: friend), isActive: $showChat) {
                    Label("nearby_start_chat",systemImage:"message.fill").frame(maxWidth:.infinity).padding().background(Color.accentColor).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius:16))
                }
                Button(role:.destructive) { confirmBlock=true } label: { Label("nearby_block_user",systemImage:"hand.raised.fill") }
            }.padding() }
            .navigationTitle("nearby_profile_title").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("nearby_block_confirm",isPresented:$confirmBlock) { Button("nearby_block_user",role:.destructive) { Task { try? await NearbyPetFriendsService.shared.block(friend.userId); dismiss() } } }
        }
    }
}

struct NearbyPrivateChatView: View {
    let friend: NearbyFriend
    @ObservedObject private var service = NearbyPetFriendsService.shared
    @State private var messages: [ChatMessage] = []
    @State private var text = ""
    @State private var showProfile = false
    var body: some View {
        VStack(spacing:0) {
            ScrollViewReader { proxy in ScrollView { LazyVStack { ForEach(messages) { PFChatBubble(message:$0,cornerStyle:.all) } }.padding(.vertical) }.onChange(of:messages.count) { _ in if let id=messages.last?.id { withAnimation { proxy.scrollTo(id,anchor:.bottom) } } } }
            PFChatInputBar(
                text: $text,
                onSend: { value in await sendText(value) },
                onAttachImage: { image in Task { await sendImage(image) } },
                onAttachFile: { url in Task { await sendFile(url) } }
            )
        }
        .navigationTitle(friend.userName ?? NSLocalizedString("nearby_pet_friend",comment:""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { showProfile = true } label: { Image(systemName: "person.crop.circle") }.accessibilityLabel("nearby_view_profile") } }
        .navigationDestination(isPresented: $showProfile) { NearbyFriendNamecardView(friend: friend) }
        .task {
            service.ensureRealtimeConnection()
            await reconcile()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { return }
                await reconcile()
            }
        }
        .onReceive(service.messageEvents) { dto in
            guard dto.senderUserId == friend.userId || dto.receiverUserId == friend.userId else { return }
            appendIfNeeded(dto)
        }
    }
    private func convert(_ dto: NearbyMessageDTO) -> ChatMessage {
        let outgoing = dto.senderUserId != friend.userId
        let content: MessageContent
        if dto.messageType == "image", let url = NetworkManager.fullUrl(dto.content) {
            content = .image(url: url, thumbURL: nil)
        } else if dto.messageType == "file", let descriptor = NearbyFileDescriptor.decode(dto.content), let url = NetworkManager.fullUrl(descriptor.url) {
            content = .file(name: descriptor.name, url: url, size: descriptor.size)
        } else {
            content = .text(dto.content)
        }
        return ChatMessage(id: dto.messageId, content: content, senderId: dto.senderUserId,
                           senderName: outgoing ? "" : (friend.userName ?? ""), senderAvatar: friend.userAvatar,
                           timestamp: dto.serverDate ?? Date(), status: dto.readTime == nil ? .sent : .read, isOutgoing: outgoing)
    }
    private func reconcile() async {
        guard let list = try? await service.messages(with: friend.userId) else { return }
        for dto in list { appendIfNeeded(dto) }
    }
    private func sendText(_ value: String) async {
        let local = ChatMessage(content: .text(value), status: .sending)
        messages.append(local)
        await finish(localId: local.id, type: "text", content: value)
    }

    private func sendImage(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 1),
              let localURL = try? persistTemporary(data: data, extension: "jpg") else { return }
        let local = ChatMessage(content: .image(url: localURL, thumbURL: nil), status: .sending, uploadProgress: 0)
        messages.append(local)
        do {
            let uploaded = try await NetworkManager.shared.uploadChatImage(image, onProgress: { progress in
                Task { @MainActor in updateProgress(local.id, progress) }
            })
            await finish(localId: local.id, type: "image", content: uploaded.url.absoluteString)
        } catch { markFailed(local.id, error) }
    }

    private func sendFile(_ url: URL) async {
        let size = ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)?.int64Value ?? 0
        let local = ChatMessage(content: .file(name: url.lastPathComponent, url: url, size: size), status: .sending, uploadProgress: 0)
        messages.append(local)
        do {
            let remote = try await NetworkManager.shared.uploadChatFile(url, onProgress: { progress in
                Task { @MainActor in updateProgress(local.id, progress) }
            })
            let payload = NearbyFileDescriptor(name: url.lastPathComponent, url: remote, size: size).encoded
            await finish(localId: local.id, type: "file", content: payload)
        } catch { markFailed(local.id, error) }
    }

    private func finish(localId: String, type: String, content: String) async {
        do {
            let dto = try await service.send(to: friend.userId, type: type, content: content)
            replace(localId: localId, with: convert(dto))
        } catch { markFailed(localId, error) }
    }

    private func replace(localId: String, with message: ChatMessage) {
        if messages.contains(where: { $0.id == message.id }) { messages.removeAll { $0.id == localId } }
        else if let index = messages.firstIndex(where: { $0.id == localId }) { messages[index] = message }
        else { appendIfNeeded(message) }
    }

    private func appendIfNeeded(_ message: ChatMessage) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message)
    }

    private func updateProgress(_ id: String, _ progress: Double) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].uploadProgress = progress
    }

    private func markFailed(_ id: String, _ error: Error) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        let old = messages[index]
        messages[index] = ChatMessage(id: old.id, content: old.content, senderId: old.senderId,
                                      senderName: old.senderName, senderAvatar: old.senderAvatar,
                                      timestamp: old.timestamp, status: .failed(error.localizedDescription), isOutgoing: true)
    }

    private func persistTemporary(data: Data, extension ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        try data.write(to: url, options: .atomic)
        return url
    }
    private func appendIfNeeded(_ dto: NearbyMessageDTO) {
        appendIfNeeded(convert(dto))
    }
}

private struct NearbyFileDescriptor: Codable {
    let name: String
    let url: String
    let size: Int64
    var encoded: String { String(data: (try? JSONEncoder().encode(self)) ?? Data(), encoding: .utf8) ?? url }
    static func decode(_ value: String) -> Self? { try? JSONDecoder().decode(Self.self, from: Data(value.utf8)) }
}

/// 地图头像直接进入项目统一用户名片，保留附近宠友即时聊天入口。
struct NearbyFriendNamecardView: View {
    let friend: NearbyFriend
    @State private var showChat = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let userId = Int64(friend.userId) {
                UserNamecardView(
                    userId: userId,
                    visiblePetIds: Set(friend.pets.map(\.petId)),
                    petDetailsReadOnly: true
                )
            }
            Button { showChat = true } label: {
                Image(systemName: "message.fill")
                    .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                    .frame(width: 54, height: 54).background(Color.accentColor, in: Circle())
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            }.padding(22)
        }
        .navigationDestination(isPresented: $showChat) { NearbyPrivateChatView(friend: friend) }
    }
}
