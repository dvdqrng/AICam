//
//  ImageGalleryViewModel.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import Foundation
import Combine
import SwiftUI

/// View model for the image gallery screen
class ImageGalleryViewModel: ObservableObject {
    /// Published array of images loaded from Supabase
    @Published var images: [ImageModel] = []
    
    /// Current selected image index
    @Published var selectedImageIndex: Int = 0
    
    /// Loading state
    @Published var isLoading: Bool = false
    
    /// Error message if any
    @Published var errorMessage: String?
    
    /// Current page for pagination
    private var currentPage: Int = 1
    
    /// Items per page
    private let pageSize: Int = 20
    
    /// Flag to indicate if there are more images to load
    private var hasMoreImages: Bool = true
    
    /// Cancellables for managing Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Supabase service instance
    private let supabaseService: SupabaseService
    
    /// Initializer with dependency injection
    init(supabaseService: SupabaseService = SupabaseService.shared) {
        self.supabaseService = supabaseService
        loadImages()
    }
    
    /// Loads images from Supabase
    func loadImages() {
        guard !isLoading && hasMoreImages else { return }
        
        isLoading = true
        errorMessage = nil
        
        supabaseService.fetchImages(page: currentPage, pageSize: pageSize)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] newImages in
                guard let self = self else { return }
                
                // If we received fewer images than the page size, there are no more images
                if newImages.count < self.pageSize {
                    self.hasMoreImages = false
                }
                
                // Append new images to the existing array
                self.images.append(contentsOf: newImages)
                
                // Increment current page for next load
                self.currentPage += 1
            })
            .store(in: &cancellables)
    }
    
    /// Loads more images when user reaches near the end of the list
    func loadMoreImagesIfNeeded(currentIndex: Int) {
        // If we're within the last 3 images, load more images
        if currentIndex >= images.count - 3 {
            loadImages()
        }
    }
    
    /// Formats the date for display
    func formattedDate(for index: Int) -> String {
        guard index >= 0 && index < images.count else {
            return "No Date"
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        return dateFormatter.string(from: images[index].photoDate)
    }
} 