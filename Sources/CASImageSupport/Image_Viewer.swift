/*-------------------------------------------------------------------------------------------------------------------------
     File: Image_Viewer.swift
   Author: Kevin Messina
  Created: 6/21/24
 Modified: 08/21/2026 06:31 PM EDT
  Version: 5
   Source: CODEX: (GPT-5) 🤖AI Code a portion or all of this code.
 
©2026 Creative App Solutions, LLC. - All Rights Reserved.
--------------------------------------------------------------------------------------------------------------------------
NOTES:
-------------------------------------------------------------------------------------------------------------------------*/

import SwiftUI
import UIKit
import PDFKit
import CASExternalFoundations
import CASExternalBasics

public struct ImageDetailView: UIViewRepresentable {
    private let uiImage: UIImage

    public init(uiImage: UIImage) {
        self.uiImage = uiImage
    }
    
    public func makeUIView(context: Context) -> PDFView {
        let imageView = PDFView()
        imageView.document = PDFDocument()

        guard let page = PDFPage(image: uiImage) else {
            return imageView
        }
        
        imageView.document?.insert(page, at: 0)
        imageView.backgroundColor = .clear
        imageView.displayDirection = .vertical
        imageView.autoScales = true

        return imageView
    }
    
    public func updateUIView(_ uiView: PDFView, context: Context) {}
}

public struct ImageViewer<BackgroundView: View>: View {
    @Environment(\.dismiss) private var dismiss

    private let imageURL: URL?
    private let imageName: String
    private let backgroundView: BackgroundView
    private let txtColor: Color

    @State private var showShareSheet = false
    @State private var uiImage: UIImage?
    @State private var showProgress = false
    @State private var progress = 0.0

    public init(
        imageURL: URL,
        imageName: String,
        backgroundView: BackgroundView,
        txtColor: Color
    ) {
        self.imageURL = imageURL
        self.imageName = imageName
        self.backgroundView = backgroundView
        self.txtColor = txtColor
        _uiImage = State(initialValue: nil)
    }

    public init(
        uiImage: UIImage?,
        imageName: String = "(Unsaved Photo)",
        backgroundView: BackgroundView,
        txtColor: Color
    ) {
        self.imageURL = nil
        self.imageName = imageName
        self.backgroundView = backgroundView
        self.txtColor = txtColor
        _uiImage = State(initialValue: uiImage)
    }

    private var shareItems: [Any] {
        if let imageURL {
            return [imageURL]
        }
        if let uiImage {
            return [uiImage]
        }
        return []
    }

    private func loadingView() -> some View {
        VStack {
            Spacer()
            ProgressView(value: progress, total: 1.0, label: {
                Text("Loading...")
                    .font(.headline)
                    .foregroundStyle(.yellow)
            })
            .progressViewStyle(.circular)
            .tint(.yellow)
            .scaleEffect(2)
            Spacer()
        }
    }

    @ViewBuilder
    private func fileInfo(txtColor: Color) -> some View {
        if imageName.count > 15 {
            let dateTxt = imageName
                .substring(fromTo: 0...8)
                .toConvertedDate(from: .yyyyMMdd, to: .MMM_d_yyyy)
            let timeTxt = imageName
                .substring(fromTo: 9...15)
                .toConvertedDate(from: .hhmmss, to: .h_m_a)
            
            VStack(alignment: .center) {
                Spacer()
                
                HStack(spacing: 3) {
                    Image(systemName: "calendar")
                        .font(.title)
                    Text("\(dateTxt) @ \(timeTxt)")
                        .font(.headline)
                }
                .foregroundStyle(txtColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .glassEffect(.regular.tint(.black.opacity(0.6)))
            }
        } else {
            EmptyView()
        }
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                backgroundView
                
                VStack {
                    if let uiImage {
                        ImageDetailView(uiImage: uiImage)
                    } else {
                        Spacer()
                        ContentUnavailableView("Image Not Found", systemImage: "photo")
                            .foregroundStyle(txtColor)
                        Spacer()
                    }
                }
                
                fileInfo(txtColor: txtColor)
                
                loadingView()
                    .opacity(showProgress ? 1 : 0)
            }
            .toolbar {
                TB().title("PHOTO VIEWER")
                TB().subtitle(imageName)

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        TB().buttonImg(.cancel)
                    }
                    .modifier(TB.buttonColor(color: .clear))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if !shareItems.isEmpty {
                            showShareSheet.toggle()
                        }
                    } label: {
                        TB().buttonImg(.share)
                    }
                    .modifier(TB.buttonColor(color: .orange))
                    .disabled(shareItems.isEmpty)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityViewController(itemsToShare: shareItems)
            }
            .onAppear {
                showProgress = true
                progress = 0.0

                if uiImage == nil, let imageURL {
                    uiImage = UIImage(contentsOfFile: imageURL.path)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    showProgress = false
                    progress = 1.0
                }
            }
        }
    }
}

#Preview {
    ImageViewer(
        uiImage: nil,
        imageName: "20250929@122424_789-inv.jpg",
        backgroundView: Color.black,
        txtColor: Color.white
    )
}
