//
//  ProfileDetailPage.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 22/9/25.
//

import SwiftUI

struct ProfileDetailPage: View {
    @Environment(\.dismiss) var dismiss
    @State private var loading = false
    @State private var petOwner: PetOwner? = AccountStore.shared.petOwner
    @State private var editedNickname: String = ""
    @EnvironmentObject var uiState: UIState
    @EnvironmentObject var store: AccountStore
    
    var body: some View {
        NavigationStack {
            Group {
                if let po = store.petOwner {
                    Form {
                        Section("头像") {
                            HStack {
                                Spacer()
                                Button(action: { showImagePicker = true }) {
                                    if let avatarUrl = store.petOwner?.petAvatar ?? store.user?.avatar, let url = URL(string: avatarUrl) {
                                        let versionedUrl = store.avatarVersion.isEmpty ? avatarUrl : (avatarUrl.contains("?") ? "\(avatarUrl)&v=\(store.avatarVersion)" : "\(avatarUrl)?v=\(store.avatarVersion)")
                                        CachedAsyncImage(url: NetworkManager.fullUrl(versionedUrl)) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            PFPetLoadingInline(size: 14)
                                        }
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                    } else {
                                        Image("avatar_placeholder")
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                Spacer()
                            }
                        }
                        
                        Section("基本信息") {
                            HStack {
                                Text(NSLocalizedString("profile_nickname", comment: ""))
                                    .foregroundColor(.secondary)
                                Spacer()
                                TextField("profile_nickname_placeholder", text: $editedNickname)
                                    .multilineTextAlignment(.trailing)
                            }
                            
                            LabeledRow(label: NSLocalizedString("profile_username", comment: ""), value: store.user?.userName ?? "")
                            LabeledRow(label: NSLocalizedString("profile_love_level", comment: ""), value: "Lv.\(po.loveLevel ?? 1)")
                            LabeledRow(label: NSLocalizedString("profile_phone", comment: ""), value: "\(store.user?.phonenumber ?? "")")
                        }
                        
                        Section {
                            Button(action: {
                                Task { await save() }
                            }) {
                                if loading {
                                    PFPetLoadingInline(size: 14)
                                } else {
                                    Text(NSLocalizedString("save_changes", comment: ""))
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(PFColors.primary)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .listRowInsets(EdgeInsets())
                            .disabled(loading || editedNickname.isEmpty)
                        }
                        
                        Section {
                            Button(role: .destructive) {
                                Task { await logout() }
                            } label: {
                                Text(NSLocalizedString("settings_logout", comment: ""))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        PFPetLoadingView("loading", size: 36)
                        Button("refresh_btn") { Task { await load() } }
                    }
                }
            }
            .navigationTitle("personal_info")
            .navigationBarTitleDisplayMode(.inline)
            .trackScene("ProfileDetail")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_close") { dismiss() }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .onChange(of: selectedImage) { newImage in
                if let img = newImage {
                    uploadAvatar(img)
                }
            }
            .overlay(
                EmptyView()
            )
            .task { 
                await load()
                if let name = store.petOwner?.name ?? store.user?.nickName {
                    editedNickname = name
                }
            }
        }
    }
    
    private func load() async {
        loading = true
        do {
            let userResp = try await AuthService.shared.fetchUserInfo()
            await AuthService.shared.cache(userResp)
            if let name = store.petOwner?.name ?? store.user?.nickName {
                editedNickname = name
            }
            loading = false
        } catch {
            print("加载用户信息失败: \(error)")
            loading = false
        }
    }
    
    private func save() async {
        loading = true
        do {
            try await AuthService.shared.updateProfile(name: editedNickname, avatar: nil)
            Haptics.notify(.success)
            loading = false
            dismiss()
        } catch {
            print("保存个人信息失败: \(error)")
            loading = false
        }
    }
    
    private func logout() async {
        do {
            try await AuthService.shared.logout()
            dismiss()
        } catch {}
    }
    
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage? = nil
    
    private func uploadAvatar(_ image: UIImage) {
        // 优化：0.8 质量大幅缩小体积
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        Task {
            do {
                let imageUrl: String = try await NetworkManager.shared.upload(
                    path: "/petFriendly/client/upload",
                    fileData: data,
                    mimeType: "image/jpeg",
                    onProgress: { _ in }
                )
                
                try await AuthService.shared.updateProfile(name: nil, avatar: imageUrl)
                
                if let fullUrl = NetworkManager.fullUrl(imageUrl)?.absoluteString {
                    ImageCacheManager.shared.remove(forKey: fullUrl)
                }
                
                await MainActor.run {
                    store.avatarVersion = "\(Date().timeIntervalSince1970)"
                    selectedImage = nil
                    
                    // 强制刷新用户信息以更新 UI
                    Task {
                        if let info = try? await AuthService.shared.fetchUserInfo() {
                            await AuthService.shared.cache(info)
                        }
                    }
                }
                Haptics.notify(.success)
            } catch {
                print("上传头像失败: \(error)")
                await MainActor.run {
                    selectedImage = nil
                    showErrorAlert(error)
                }
            }
        }
    }
}

// MARK: - 资料行
struct LabeledRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}
