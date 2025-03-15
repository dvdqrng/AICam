//
//  ImageLoaderService.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import Foundation
import SwiftUI
import Combine

/// Service for loading and caching images from remote URLs
class ImageLoaderService: ObservableObject {
    /// The loaded image
    @Published var image: UIImage?
    
    /// Loading state
    @Published var isLoading = false
    
    /// Error state
    @Published var loadingError: Error?
    
    /// URL of the image
    private let url: URL
    
    /// Image cache
    private static let imageCache = NSCache<NSString, UIImage>()
    
    /// Cancellables for managing Combine subscriptions
    private var cancellable: AnyCancellable?
    
    /// Initializer
    /// - Parameter url: URL of the image to load
    init(url: URL) {
        self.url = url
        loadImage()
    }
    
    /// Convenience initializer with string URL
    /// - Parameter urlString: String URL of the image to load
    convenience init?(urlString: String) {
        // Clean up URL: fix double slashes and remove trailing question marks
        let cleanUrlString = urlString
            .replacingOccurrences(of: "//storage", with: "/storage") // Fix double slashes
            .trimmingCharacters(in: CharacterSet(charactersIn: "?")) // Remove trailing ?
        
        print("Original URL: \(urlString)")
        print("Cleaned URL: \(cleanUrlString)")
        
        guard let url = URL(string: cleanUrlString) else { return nil }
        self.init(url: url)
    }
    
    /// Loads the image from the URL or cache
    private func loadImage() {
        // Check if the image is already in the cache
        if let cachedImage = Self.imageCache.object(forKey: url.absoluteString as NSString) {
            self.image = cachedImage
            return
        }
        
        isLoading = true
        loadingError = nil
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { UIImage(data: $0.data) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.loadingError = error
                }
            } receiveValue: { [weak self] loadedImage in
                guard let self = self, let image = loadedImage else { return }
                
                // Cache the image
                Self.imageCache.setObject(image, forKey: self.url.absoluteString as NSString)
                self.image = image
            }
    }
    
    /// Cancels the loading task
    func cancel() {
        cancellable?.cancel()
    }
}

/// SwiftUI view extension for async image loading with caching
struct RemoteImage: View {
    @StateObject private var imageLoader: ImageLoaderService
    private let placeholder: Image
    
    /// Initializer
    /// - Parameters:
    ///   - url: URL of the image to load
    ///   - placeholder: Placeholder image to show while loading
    init(url: URL, placeholder: Image = Image(systemName: "photo")) {
        self._imageLoader = StateObject(wrappedValue: ImageLoaderService(url: url))
        self.placeholder = placeholder
    }
    
    /// Convenience initializer with string URL
    /// - Parameters:
    ///   - urlString: String URL of the image to load
    ///   - placeholder: Placeholder image to show while loading
    init?(urlString: String, placeholder: Image = Image(systemName: "photo")) {
        // Clean up URL: fix double slashes and remove trailing question marks
        let cleanUrlString = urlString
            .replacingOccurrences(of: "//storage", with: "/storage") // Fix double slashes
            .trimmingCharacters(in: CharacterSet(charactersIn: "?")) // Remove trailing ?
            
        guard let url = URL(string: cleanUrlString) else { return nil }
        self.init(url: url, placeholder: placeholder)
    }
    
    var body: some View {
        if let image = imageLoader.image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            placeholder
                .resizable()
                .aspectRatio(contentMode: .fit)
                .overlay {
                    if imageLoader.isLoading {
                        ProgressView()
                    } else if imageLoader.loadingError != nil {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                    }
                }
        }
    }
} 