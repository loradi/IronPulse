import SwiftUI
import PhotosUI
import UIKit

struct EditableAvatarView: View {
    @Bindable var profile: UserProfile
    var size: CGFloat = 56

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingMenu = false
    @State private var showingPhotoPicker = false

    var body: some View {
        AvatarPlaceholder(name: profile.name, photoData: profile.photoData, size: size)
            .contentShape(Circle())
            .onTapGesture { showingMenu = true }
            .confirmationDialog("Foto de perfil", isPresented: $showingMenu) {
                Button("Elegir de galeria") {
                    showingPhotoPicker = true
                }

                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Tomar foto") {
                        showingCamera = true
                    }
                }

                if profile.photoData != nil {
                    Button("Eliminar foto", role: .destructive) {
                        profile.photoData = nil
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    guard let newItem,
                          let data = try? await newItem.loadTransferable(type: Data.self),
                          let uiImage = UIImage(data: data) else { return }
                    profile.photoData = resizedProfilePhotoData(from: uiImage)
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraPicker { image in
                    profile.photoData = resizedProfilePhotoData(from: image)
                    showingCamera = false
                }
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
    }
}
