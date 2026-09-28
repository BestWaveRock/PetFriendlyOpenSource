import SwiftUI
import PhotosUI
import Alamofire

struct EvaluateFormView: View {
    let placeId: Int64
    var onReviewSubmitted: (() -> Void)?
    @Environment(\.dismiss) var dismiss
    
    @State private var rate: Double = 5.0
    @State private var comments: String = ""
    @State private var selectedImages: [UIImage] = []
    
    @State private var isPickerPresented = false
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var isPrivate: Bool = false
    @State private var isAnonymous: Bool = false
    
    
    // Pets Selection
    @StateObject private var petViewModel = PetViewModel()
    @State private var selectedPetIds: Set<String> = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(NSLocalizedString("eval_rating", comment: ""))) {
                    HStack {
                        Spacer()
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(rate) ? "star.fill" : "star")
                                .foregroundColor(star <= Int(rate) ? PFColors.warning : PFColors.surfaceSecondary)
                                .font(.system(size: 32))
                                .onTapGesture {
                                    rate = Double(star)
                                }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text(NSLocalizedString("eval_content", comment: ""))) {
                    PFTextEditor(
                        placeholder: "eval_placeholder",
                        text: $comments,
                        height: 120,
                        maxLength: 500
                    )
                    .padding(.vertical, 4)
                }
                
                Section(header: Text(NSLocalizedString("eval_pets_title", comment: ""))) {
                    if petViewModel.isLoading && petViewModel.pets.isEmpty {
                        PFPetLoadingView(size: 36).padding()
                    } else if petViewModel.pets.isEmpty {
                        Text(NSLocalizedString("eval_no_pets", comment: "")).foregroundColor(.gray).font(PFFonts.caption)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(petViewModel.pets) { pet in
                                    let id = pet.id
                                    let currentlySelected = selectedPetIds.contains(id)
                                    
                                    Button(action: {
                                        if currentlySelected {
                                            selectedPetIds.remove(id)
                                        } else {
                                            selectedPetIds.insert(id)
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: currentlySelected ? "checkmark.circle.fill" : "circle")
                                            Text(pet.name)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(currentlySelected ? PFColors.primary.opacity(0.15) : PFColors.surfaceSecondary)
                                        .foregroundColor(currentlySelected ? PFColors.primary : PFColors.textSecondary)
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(currentlySelected ? PFColors.primary : Color.clear, lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text(NSLocalizedString("eval_photos_header", comment: ""))) {
                    VStack {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(selectedImages.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: selectedImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .clipped()
                                        
                                        Button(action: {
                                            selectedImages.remove(at: index)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Color.black.opacity(0.5))
                                                .clipShape(Circle())
                                        }
                                        .padding(4)
                                    }
                                }
                                
                                if selectedImages.count < 3 {
                                    Button(action: { isPickerPresented = true }) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(PFColors.surfaceSecondary)
                                                .frame(width: 80, height: 80)
                                            Image(systemName: "plus")
                                                .font(.system(size: 24))
                                                .foregroundColor(PFColors.textSecondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Toggle(isOn: $isPrivate) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("eval_private_title", comment: ""))
                                .font(PFFonts.callout)
                            Text(NSLocalizedString("eval_private_subtitle", comment: ""))
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.textSecondary)
                        }
                    }
                    .tint(PFColors.primary)
                    
                    Toggle(isOn: $isAnonymous) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("eval_anonymous_title", comment: ""))
                                .font(PFFonts.callout)
                            Text(NSLocalizedString("eval_anonymous_subtitle", comment: ""))
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.textSecondary)
                        }
                    }
                    .tint(PFColors.primary)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(PFColors.danger)
                            .font(PFFonts.caption)
                    }
                }
            }
            .navigationTitle("eval_title")
            .navigationBarItems(
                leading: Button("common_cancel") { dismiss() }.foregroundColor(PFColors.textSecondary),
                trailing: Button(action: submitReview) {
                    if isSubmitting {
                        PFPetLoadingInline(size: 18)
                    } else {
                        Text(LocalizedStringKey("form_submit"))
                            .bold()
                            .foregroundColor(PFColors.primary)
                    }
                }
                .disabled(isSubmitting)
            )
            .sheet(isPresented: $isPickerPresented) {
                ImagePicker(image: Binding(
                    get: { nil },
                    set: { newImage in
                        if let img = newImage {
                            selectedImages.append(img)
                        }
                    }
                ))
            }
            .background(PFColors.background.ignoresSafeArea())
            .onAppear {
                petViewModel.fetchPets()
            }
        }
    }
    
    // MARK: - API Submission
    private func submitReview() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                struct UploadStringResponse: Decodable {
                    let code: Int
                    let msg: String?
                    let data: String?
                }
                
                // 1. Upload images if any
                var uploadedUrls: [String] = []
                for image in selectedImages {
                    if let fileData = image.jpegData(compressionQuality: 0.7) {
                        let resp: UploadStringResponse = try await NetworkManager.shared.upload(
                            path: "/petFriendly/client/upload",
                            fileData: fileData,
                            mimeType: "image/jpeg"
                        )
                        if let url = resp.data {
                            uploadedUrls.append(url)
                        }
                    }
                }
                
                let picturesString = uploadedUrls.joined(separator: ",")
                
                // 2. Submit evaluation
                var param: [String: Any] = [
                    "placeId": placeId,
                    "rate": rate,
                    "comments": comments,
                    "pictures": picturesString,
                    "visibleStatus": isPrivate ? 1 : (isAnonymous ? 2 : 0)
                ]
                
                if !selectedPetIds.isEmpty {
                    param["ext"] = selectedPetIds.joined(separator: ",")
                }
                
                struct BoolRespX: Decodable { let data: Bool? }
                
                let _: BoolRespX = try await NetworkManager.shared.request(
                    "/petFriendly/client/evaluate",
                    method: .post,
                    parameters: param,
                    encoding: JSONEncoding.default  // handled correctly via request mapping
                )
                
                await MainActor.run {
                    Haptics.notify(.success)
                    showSuccessHUD(message: NSLocalizedString("eval_success", comment: ""))
                    onReviewSubmitted?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isSubmitting = false
                    Haptics.notify(.error)
                }
            }
        }
    }
}
