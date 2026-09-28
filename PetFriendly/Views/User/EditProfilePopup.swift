//
//  EditProfilePopup.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/11/05.
//

import SwiftUI

struct EditProfilePopup: View {
    @State var nickname: String
    @State var avatar: String
    var onSave: (String, String) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var isSubmitting = false
    @State private var showImagePicker = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                PFColors.background.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Avatar Edit
                    Button(action: { showImagePicker = true }) {
                        ZStack(alignment: .bottomTrailing) {
                            if !avatar.isEmpty {
                                CachedAsyncImage(url: NetworkManager.fullUrl(avatar)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Circle().fill(PFColors.surfaceSecondary)
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(PFGradients.brand)
                                    .frame(width: 100, height: 100)
                                    .overlay(Image(systemName: "person.fill").font(.largeTitle).foregroundColor(.white))
                            }
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(PFColors.primary)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Nickname Edit
                    VStack(alignment: .leading, spacing: 10) {
                        Text(NSLocalizedString("profile_nickname", comment: ""))
                            .font(PFFonts.headline)
                            .foregroundColor(PFColors.textSecondary)
                        
                        TextField("profile_nickname_placeholder", text: $nickname)
                            .font(PFFonts.title2)
                            .padding()
                            .background(PFColors.surface)
                            .cornerRadius(16)
                            .pfCardShadow()
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Save Button
                    Button(action: saveProfile) {
                        if isSubmitting {
                            PFPetLoadingInline(size: 14)
                        } else {
                            Text(NSLocalizedString("common_save", comment: ""))
                                .font(PFFonts.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(PFGradients.brand)
                    .clipShape(Capsule())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .disabled(isSubmitting || nickname.isEmpty)
                }
                .padding(.top, 40)
            }
            .navigationTitle("profile_edit_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common_cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: Binding(
                    get: { nil },
                    set: { if let img = $0 { uploadAvatar(img) } }
                ))
            }
        }
    }
    
    private func uploadAvatar(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.6) else { return }
        isSubmitting = true
        
        Task {
            do {
                struct UploadResp: Decodable {
                    let code: Int
                    let data: String?
                }
                let resp: UploadResp = try await NetworkManager.shared.upload(
                    path: "/petFriendly/client/upload",
                    fileData: data,
                    mimeType: "image/jpeg"
                )
                await MainActor.run {
                    if let url = resp.data {
                        self.avatar = url
                    }
                    isSubmitting = false
                }
            } catch {
                print("Upload avatar error: \(error)")
                await MainActor.run { isSubmitting = false }
            }
        }
    }
    
    private func saveProfile() {
        isSubmitting = true
        Task {
            do {
                let params: [String: Any] = [
                    "name": nickname,
                    "petAvatar": avatar
                ]
                let _: BoolResp = try await NetworkManager.shared.request("/petFriendly/client/updateProfile", method: .post, parameters: params)
                await MainActor.run {
                    onSave(nickname, avatar)
                    isSubmitting = false
                    dismiss()
                }
            } catch {
                print("Save profile error: \(error)")
                await MainActor.run { isSubmitting = false }
            }
        }
    }
}
