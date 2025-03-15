//
//  SupabaseService.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import Foundation
import Combine

/// Service responsible for handling all Supabase API interactions
class SupabaseService {
    /// Singleton instance of the service
    static let shared = SupabaseService()
    
    /// Supabase API URL
    private let supabaseUrl: String
    
    /// Supabase API Key
    private let supabaseKey: String
    
    /// URL session for network requests
    private let session: URLSession
    
    /// Private initializer for singleton pattern
    private init() {
        // TODO: Move these to environment variables or secure storage
        self.supabaseUrl = "YOUR_SUPABASE_URL"
        self.supabaseKey = "YOUR_SUPABASE_API_KEY"
        
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = [
            "apikey": supabaseKey,
            "Authorization": "Bearer \(supabaseKey)",
            "Content-Type": "application/json"
        ]
        self.session = URLSession(configuration: configuration)
    }
    
    /// Fetches images from Supabase
    /// - Parameters:
    ///   - page: The page number for pagination
    ///   - pageSize: Number of items per page
    /// - Returns: A publisher that emits an array of ImageModel objects or an error
    func fetchImages(page: Int = 1, pageSize: Int = 10) -> AnyPublisher<[ImageModel], Error> {
        let offset = (page - 1) * pageSize
        
        // Construct the API URL with pagination
        guard let url = URL(string: "\(supabaseUrl)/rest/v1/images?select=*&order=photo_date.desc&offset=\(offset)&limit=\(pageSize)") else {
            return Fail(error: NSError(domain: "SupabaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
                .eraseToAnyPublisher()
        }
        
        // Create the request
        return session.dataTaskPublisher(for: url)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw NSError(domain: "SupabaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Server error"])
                }
                return data
            }
            .decode(type: [SupabaseImageResponse].self, decoder: JSONDecoder())
            .map { responses -> [ImageModel] in
                return responses.compactMap { response in
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
            }
            .eraseToAnyPublisher()
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