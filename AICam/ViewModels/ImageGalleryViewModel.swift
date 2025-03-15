//
//  ImageGalleryViewModel.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import Foundation
import Combine

/// View model for the image gallery screen
class ImageGalleryViewModel: ObservableObject {
    /// Array of images to display
    @Published var images: [ImageModel] = []
    
    /// Currently selected image index
    @Published var selectedImageIndex: Int = 0
    
    /// Loading state
    @Published var isLoading: Bool = false
    
    /// Error message if image loading fails
    @Published var errorMessage: String? = nil
    
    /// Current page for pagination
    private var currentOffset: Int = 0
    
    /// Flag to determine if more images can be loaded
    private var canLoadMore: Bool = true
    
    /// Page size for pagination
    private let pageSize: Int = 10
    
    /// Cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Service for interacting with Supabase
    private let supabaseService: SupabaseService
    
    /// Initializes the view model with dependencies
    /// - Parameter supabaseService: The service for accessing Supabase
    init(supabaseService: SupabaseService = SupabaseService.shared) {
        self.supabaseService = supabaseService
    }
    
    /// Loads images from Supabase
    func loadImages() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        currentOffset = 0
        canLoadMore = true
        
        supabaseService.fetchImages(startIndex: currentOffset, limit: pageSize)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to load images: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] images in
                self?.images = images
                self?.canLoadMore = images.count == self?.pageSize
                self?.currentOffset += images.count
            })
            .store(in: &cancellables)
    }
    
    /// Loads more images for pagination
    /// - Parameter currentIndex: Current index being viewed
    func loadMoreImagesIfNeeded(currentIndex: Int) {
        // Load more images when we're close to the end of the currently loaded set
        let thresholdIndex = images.count - 3
        if currentIndex >= thresholdIndex, !isLoading, canLoadMore {
            loadMoreImages()
        }
    }
    
    /// Loads the next page of images
    private func loadMoreImages() {
        guard !isLoading, canLoadMore else { return }
        
        isLoading = true
        
        supabaseService.fetchImages(startIndex: currentOffset, limit: pageSize)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to load more images: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] newImages in
                guard let self = self else { return }
                
                self.images.append(contentsOf: newImages)
                self.canLoadMore = newImages.count == self.pageSize
                self.currentOffset += newImages.count
            })
            .store(in: &cancellables)
    }
    
    /// Formats the date for display
    /// - Parameter index: Index of the image
    /// - Returns: Formatted date string
    func formattedDate(for index: Int) -> String {
        guard index < images.count else { return "" }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        if let date = images[index].photoDate ?? images[index].createdAt {
            return dateFormatter.string(from: date)
        }
        
        return "No date available"
    }
} 