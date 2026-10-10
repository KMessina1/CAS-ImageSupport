/*-------------------------------------------------------------------------------------------------------------------------
     File: Image_Picker.swift
   Author: Kevin Messina
  Created: 6/21/24
 Modified: 10/10/2026 03:40 PM EDT
  Version: 10
   Source: CODEX: (GPT-5) 🤖AI Code a portion or all of this code.

©2026 Creative App Solutions, LLC. - All Rights Reserved.
--------------------------------------------------------------------------------------------------------------------------
NOTES:
Cleaned up commented code.
-------------------------------------------------------------------------------------------------------------------------*/

import SwiftUI
import PhotosUI
import UIKit
import CASExternalFoundations

public extension View {
    // Retains existing call sites; this profile picker always saves Documents/myphoto.jpg with a circular crop.
    func cropImagePicker(
        options: [Crop] = [.circle],
        show: Binding<Bool>,
        croppedImage: Binding<UIImage?>,
        directory: Files.directories = .docsDir,
        fileName: String = "myphoto.jpg",
        backupFileName: String = "myphoto_backup.jpg"
    ) -> some View {
        ImagePicker(show: show, croppedImage: croppedImage, backupFileName: backupFileName) {
            self
        }
    }
}

@MainActor
private struct ImagePicker<Content: View>: View {
    let content: Content
    @Binding var show: Bool
    @Binding var croppedImage: UIImage?
    let backupFileName: String

    init(show: Binding<Bool>, croppedImage: Binding<UIImage?>, backupFileName: String, @ViewBuilder content: () -> Content) {
        self.content = content()
        _show = show
        _croppedImage = croppedImage
        self.backupFileName = backupFileName
    }

    var body: some View {
        content.fullScreenCover(isPresented: $show) {
            ProfilePhotoPicker(croppedImage: $croppedImage, backupFileName: backupFileName)
        }
    }
}

@MainActor
private struct ProfilePhotoPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var croppedImage: UIImage?
    let backupFileName: String

    @State private var showPhotoLibrary = true
    @State private var photosItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorTitle = ""
    @State private var errorMessage = ""
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var cropSide: CGFloat = 0
    @GestureState private var magnification: CGFloat = 1
    @GestureState private var translation: CGSize = .zero

    private var displayedScale: CGFloat { min(max(scale * magnification, 0.25), 8) }
    private var displayedOffset: CGSize {
        CGSize(width: offset.width + translation.width, height: offset.height + translation.height)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let image {
                    GeometryReader { geometry in
                        let side = max(1, min(min(geometry.size.width - 40, geometry.size.height - 90), 420))

                        VStack(spacing: 20) {
                            Spacer(minLength: 0)
                            cropPreview(image: image, side: side)
                            Text("Pinch to resize. Drag to position.")
                                .font(.footnote)
                                .foregroundStyle(.white)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else if !showPhotoLibrary {
                    ProgressView("Loading Photo…")
                        .tint(.white)
                        .foregroundStyle(.white)
                }
            }
            .navigationTitle("Profile Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { savePhoto() }
                        .disabled(image == nil || cropSide <= 0 || showPhotoLibrary || isLoading || isSaving)
                }
            }
            .tint(.white)
        }
        .photosPicker(isPresented: $showPhotoLibrary, selection: $photosItem, matching: .images, preferredItemEncoding: .current)
        .onChange(of: showPhotoLibrary) { _, isPresented in
            if !isPresented, photosItem == nil {
                dismiss()
            }
        }
        .task(id: photosItem) {
            guard let photosItem else { return }
            isLoading = true
            defer { isLoading = false }

            do {
                guard let data = try await photosItem.loadTransferable(type: Data.self),
                      let loadedImage = UIImage(data: data), loadedImage.size.width > 0, loadedImage.size.height > 0 else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                try Task.checkCancellation()
                image = loadedImage
            } catch {
                guard !Task.isCancelled else { return }
                errorTitle = "Unable to Load Photo"
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        .alert(errorTitle, isPresented: $showError) {
            Button("OK") {
                if image == nil { dismiss() }
            }
        } message: {
            Text(errorMessage)
        }
    }

    private func cropPreview(image: UIImage, side: CGFloat) -> some View {
        ZStack {
            Color.white
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .scaleEffect(displayedScale)
                .offset(displayedOffset)
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .overlay { Circle().stroke(.white, lineWidth: 2).allowsHitTesting(false) }
        .contentShape(Circle())
        .gesture(cropGesture)
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
        } action: { side in
            cropSide = side
        }
    }

    private var cropGesture: some Gesture {
        MagnifyGesture()
            .updating($magnification) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                scale = min(max(scale * value.magnification, 0.25), 8)
            }
            .simultaneously(with:
                DragGesture()
                    .updating($translation) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        offset = CGSize(width: offset.width + value.translation.width, height: offset.height + value.translation.height)
                    }
            )
    }

    private func savePhoto() {
        guard let image, cropSide > 0, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let outputSide: CGFloat = 1024
            let outputRect = CGRect(x: 0, y: 0, width: outputSide, height: outputSide)
            let fillScale = max(outputSide / image.size.width, outputSide / image.size.height) * displayedScale
            let imageSize = CGSize(width: image.size.width * fillScale, height: image.size.height * fillScale)
            let offsetScale = outputSide / cropSide
            let imageRect = CGRect(
                x: (outputSide - imageSize.width) / 2 + displayedOffset.width * offsetScale,
                y: (outputSide - imageSize.height) / 2 + displayedOffset.height * offsetScale,
                width: imageSize.width,
                height: imageSize.height
            )
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let result = UIGraphicsImageRenderer(size: outputRect.size, format: format).image { context in
                UIColor.black.setFill()
                context.fill(outputRect)
                context.cgContext.saveGState()
                context.cgContext.addEllipse(in: outputRect)
                context.cgContext.clip()
                UIColor.white.setFill()
                context.fill(outputRect)
                image.draw(in: imageRect)
                context.cgContext.restoreGState()
            }
            guard let data = result.jpegData(compressionQuality: 1.0) else {
                throw CocoaError(.fileWriteUnknown)
            }
            let fileURL = URL.documentsDirectory.appending(path: "myphoto.jpg")
            if FileManager.default.fileExists(atPath: fileURL.path), backupFileName != "myphoto.jpg", !backupFileName.isEmpty {
                let backupURL = URL.documentsDirectory.appending(path: backupFileName)
                try Data(contentsOf: fileURL).write(to: backupURL, options: .atomic)
            }
            try data.write(to: fileURL, options: .atomic)
            croppedImage = result
            dismiss()
        } catch {
            errorTitle = "Unable to Save Photo"
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
