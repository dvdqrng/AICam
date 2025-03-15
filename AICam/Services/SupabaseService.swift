//
//  SupabaseService.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import Foundation
import Combine
import Supabase

/// Service responsible for handling all Supabase API interactions
class SupabaseService {
    /// Singleton instance of the service
    static let shared = SupabaseService()
    
    /// Supabase client
    private let supabase: SupabaseClient
    
    /// Private initializer for singleton pattern
    private init() {
        // Initialize Supabase client from configuration
        self.supabase = SupabaseConfig.createClient()
    }
    
    /// Fetches images from Supabase
    /// - Parameters:
    ///   - page: The page number for pagination
    ///   - pageSize: Number of items per page
    /// - Returns: A publisher that emits an array of ImageModel objects or an error
    func fetchImages(page: Int = 1, pageSize: Int = 10) -> AnyPublisher<[ImageModel], Error> {
        let offset = (page - 1) * pageSize
        
        // Create a Future publisher that wraps the async Supabase query
        return Future<[ImageModel], Error> { promise in
            // Use async/await with Task since Supabase SDK uses async/await
            Task {
                do {
                    // Query the images table with pagination
                    let response: [SupabaseImageResponse] = try await self.supabase.database
                        .from("images")
                        .select()
                        .order("photo_date", ascending: false)
                        .range(offset, offset + pageSize - 1)
                        .execute()
                        .value
                    
                    // Convert the response to ImageModel objects
                    let imageModels = response.compactMap { response -> ImageModel? in
                        guard let photoDateString = response.photo_date,
                              let createdAtString = response.created_at,
                              let photoDate = ISO8601DateFormatter().date(from: photoDateString),
                              let createdAt = ISO8601DateFormatter().date(from: createdAtString) else {
                            return nil
                        }
                        
                        return ImageModel(
                            id: response.id,
                            imageUrl: response.url,
                            photoDate: photoDate,
                            createdAt: createdAt,
                            metadata: response.metadata
                        )
                    }
                    
                    // Fulfill the promise with the image models
                    promise(.success(imageModels))
                } catch {
                    // Handle any errors
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
}

/// Response model for Supabase image data
struct SupabaseImageResponse: Codable {
    let id: String
    let url: String
    let photo_date: String?
    let created_at: String?
    let metadata: [String: String]?
} 