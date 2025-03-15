//
//  ImageGalleryView.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import SwiftUI

struct ImageGalleryView: View {
    /// View model for the gallery
    @StateObject private var viewModel = ImageGalleryViewModel()
    
    var body: some View {
        VStack {
            // Title with date
            if !viewModel.images.isEmpty {
                Text(viewModel.formattedDate(for: viewModel.selectedImageIndex))
                    .font(.headline)
                    .padding()
            } else {
                Text("No Images")
                    .font(.headline)
                    .padding()
            }
            
            // Image display area
            ZStack {
                if viewModel.images.isEmpty {
                    if viewModel.isLoading {
                        ProgressView("Loading images...")
                    } else if let error = viewModel.errorMessage {
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                                .padding()
                            
                            Text(error)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding()
                            
                            Button("Try Again") {
                                viewModel.loadImages()
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .padding()
                    } else {
                        Text("No images found")
                            .foregroundColor(.secondary)
                    }
                } else {
                    if viewModel.selectedImageIndex < viewModel.images.count {
                        // Display the selected image
                        if let url = URL(string: viewModel.images[viewModel.selectedImageIndex].imageUrl) {
                            RemoteImage(url: url)
                                .aspectRatio(contentMode: .fit)
                                .transition(.opacity)
                                .animation(.easeInOut, value: viewModel.selectedImageIndex)
                        } else {
                            Image(systemName: "photo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Slider for navigating through images
            if viewModel.images.count > 1 {
                VStack {
                    Slider(value: Binding(
                        get: { Double(viewModel.selectedImageIndex) },
                        set: { newValue in
                            viewModel.selectedImageIndex = Int(newValue.rounded())
                            viewModel.loadMoreImagesIfNeeded(currentIndex: viewModel.selectedImageIndex)
                        }
                    ), in: 0...Double(max(0, viewModel.images.count - 1)), step: 1)
                    .padding(.horizontal)
                    
                    HStack {
                        Button(action: {
                            withAnimation {
                                viewModel.selectedImageIndex = max(0, viewModel.selectedImageIndex - 1)
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .padding()
                        }
                        .disabled(viewModel.selectedImageIndex <= 0)
                        
                        Spacer()
                        
                        Text("\(viewModel.selectedImageIndex + 1) of \(viewModel.images.count)")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                viewModel.selectedImageIndex = min(viewModel.images.count - 1, viewModel.selectedImageIndex + 1)
                                viewModel.loadMoreImagesIfNeeded(currentIndex: viewModel.selectedImageIndex)
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                                .padding()
                        }
                        .disabled(viewModel.selectedImageIndex >= viewModel.images.count - 1)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            
            // Loading indicator for pagination
            if viewModel.isLoading && !viewModel.images.isEmpty {
                ProgressView("Loading more images...")
                    .padding()
            }
        }
        .navigationTitle("My Images")
        .onAppear {
            // Load images when the view appears
            if viewModel.images.isEmpty {
                viewModel.loadImages()
            }
        }
    }
}

#Preview {
    NavigationView {
        ImageGalleryView()
    }
} 