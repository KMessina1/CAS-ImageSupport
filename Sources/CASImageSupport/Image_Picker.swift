/*-------------------------------------------------------------------------------------------------------------------------
     File: Image_Picker.swift
   Author: Kevin Messina
  Created: 6/21/24
 Modified: 08/21/2026 06:31 PM EDT
  Version: 4
   Source: CODEX: (GPT-5) 🤖AI Code a portion or all of this code.
 
©2026 Creative App Solutions, LLC. - All Rights Reserved.
--------------------------------------------------------------------------------------------------------------------------
NOTES:
-------------------------------------------------------------------------------------------------------------------------*/

import SwiftUI
import PhotosUI
import CASExternalFoundations

public extension View {
    @ViewBuilder
    func cropImagePicker(
        options: [Crop],
        show: Binding<Bool>,
        croppedImage: Binding<UIImage?>,
        directory: Files.directories,
        fileName: String,
        backupFileName: String
    ) -> some View {
        ImagePicker(
            options: options,
            show: show,
            croppedImage: croppedImage,
            directory: directory,
            fileName: fileName,
            backupFileName: backupFileName
        ) {
            self
        }
    }
}

private struct ImagePicker<Content: View>: View {
    let content: Content
    let options: [Crop]
    @Binding var show: Bool
    @Binding var croppedImage: UIImage?
    let directory: Files.directories
    let fileName: String
    let backupFileName: String

    @State private var photosItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showCropView = false
    @State private var selectedCropType: Crop = .circle

    init(
        options: [Crop],
        show: Binding<Bool>,
        croppedImage: Binding<UIImage?>,
        directory: Files.directories,
        fileName: String,
        backupFileName: String,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.options = options
        _show = show
        _croppedImage = croppedImage
        self.directory = directory
        self.fileName = fileName
        self.backupFileName = backupFileName
    }

    var body: some View {
        content
            .photosPicker(isPresented: $show, selection: $photosItem, matching: .images)
            .onChange(of: photosItem) { _, newValue in
                guard let newValue else { return }

                Task {
                    guard let imageData = try? await newValue.loadTransferable(type: Data.self),
                          let image = UIImage(data: imageData) else { return }

                    await MainActor.run {
                        selectedImage = image
                        selectedCropType = options.first ?? .circle
                        showCropView = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showCropView, onDismiss: {
                selectedImage = nil
                photosItem = nil
            }) {
                CropView(crop: selectedCropType, image: selectedImage) { image, _ in
                    guard let image else { return }
                    croppedImage = image
                    save(image)
                }
            }
    }

    private func save(_ image: UIImage) {
        let fileURL = Files().getPathForFilename(fileName, in: directory).url

        if Files().exists(filename: fileName, in: directory) {
            Files().moveOrRename(
                fromName: fileName,
                fromDir: directory,
                toName: backupFileName,
                in: directory
            )
        }

        try? image.jpegData(compressionQuality: 1)?.write(to: fileURL, options: .atomic)
    }
}

private struct CropView: View {
    @Environment(\.dismiss) private var dismiss

    let crop: Crop
    let image: UIImage?
    let onCrop: (UIImage?, Bool) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                cropArea
            }
            .navigationTitle("Resize Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let renderer = ImageRenderer(content: cropArea.overlay(Color.clear))
                        renderer.proposedSize = ProposedViewSize(crop.size())
                        let result = renderer.uiImage
                        onCrop(result, result != nil)
                        dismiss()
                    }
                }
            }
        }
    }

    private var cropArea: some View {
        GeometryReader { geometry in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                }

                grid
            }
            .clipped()
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .simultaneousGesture(magnificationGesture)
        }
        .frame(width: crop.size().width, height: crop.size().height)
        .clipShape(crop == .circle ? AnyShape(Circle()) : AnyShape(Rectangle()))
    }

    private var grid: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { _ in
                    Rectangle()
                        .fill(.white.opacity(0.55))
                        .frame(width: 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { _ in
                    Rectangle()
                        .fill(.white.opacity(0.55))
                        .frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in lastOffset = offset }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in scale = max(1, lastScale * value) }
            .onEnded { _ in lastScale = scale }
    }
}
