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
    
    /// Authentication service for getting current user
    private let authService: AuthService
    
    /// Initializes the view model with dependencies
    /// - Parameters:
    ///   - supabaseService: The service for accessing Supabase
    ///   - authService: The authentication service
    init(supabaseService: SupabaseService = SupabaseService.shared,
         authService: AuthService = AuthService.shared) {
        self.supabaseService = supabaseService
        self.authService = authService
    }
    
    /// Loads images from Supabase for the current user
    func loadImages() {
        guard !isLoading else { return }
        
        // Get current user's ID
        guard let userId = authService.currentUser?.id else {
            errorMessage = "User not logged in"
            return
        }
        
        isLoading = true
        errorMessage = nil
        currentOffset = 0
        canLoadMore = true
        
        supabaseService.fetchImages(startIndex: currentOffset, limit: pageSize, userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to load images: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] images in
                guard let self = self else { return }
                
                print("Loaded \(images.count) images")
                for (index, image) in images.enumerated() {
                    print("Image \(index): ID=\(image.id), URL=\(image.imageUrl)")
                }
                
                // Make sure we have unique images
                let uniqueImages = Array(Dictionary(grouping: images) { $0.id }.values.map { $0.first! })
                if uniqueImages.count != images.count {
                    print("WARNING: Received \(images.count) images but only \(uniqueImages.count) are unique")
                }
                
                self.images = uniqueImages
                self.canLoadMore = images.count == self.pageSize
                self.currentOffset += images.count
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
        guard let userId = authService.currentUser?.id else { return }
        
        isLoading = true
        
        supabaseService.fetchImages(startIndex: currentOffset, limit: pageSize, userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to load more images: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] newImages in
                guard let self = self else { return }
                
                // Filter out duplicates based on image ID
                let existingIds = Set(self.images.map { $0.id })
                let uniqueNewImages = newImages.filter { !existingIds.contains($0.id) }
                
                self.images.append(contentsOf: uniqueNewImages)
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
        
        let displayDate = images[index].photoDate ?? images[index].createdAt
        return dateFormatter.string(from: displayDate)
    }
} 