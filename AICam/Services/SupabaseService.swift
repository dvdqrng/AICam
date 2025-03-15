//
//  SupabaseService.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import Foundation
import Combine
import UIKit

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
        // Supabase credentials from configuration
        self.supabaseUrl = "https://bidgqmzbwzoeifenmixm.supabase.co"
        self.supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpZGdxbXpid3pvZWlmZW5taXhtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIwMzc1NzUsImV4cCI6MjA1NzYxMzU3NX0.1xXs_3JX9AiEYbxZT3y_1lURONv6AEyKqls_XmLLyV0"
        
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
    
    /// Uploads an image to Supabase Storage and creates a record in the images table
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - photoDate: The date the photo was taken
    ///   - metadata: Additional metadata for the image
    /// - Returns: A publisher that emits the uploaded ImageModel or an error
    func uploadImage(image: UIImage, photoDate: Date, metadata: [String: String]? = nil) -> AnyPublisher<ImageModel, Error> {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return Fail(error: NSError(domain: "SupabaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"]))
                .eraseToAnyPublisher()
        }
        
        // Generate a unique filename
        let filename = UUID().uuidString + ".jpg"
        let storageUrl = "\(supabaseUrl)/storage/v1/object/images/\(filename)"
        
        // Create upload request
        guard let uploadUrl = URL(string: storageUrl) else {
            return Fail(error: NSError(domain: "SupabaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid storage URL"]))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: uploadUrl)
        request.httpMethod = "POST"
        request.addValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.addValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        
        // Upload the image to Supabase Storage
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> URL in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw NSError(domain: "SupabaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to upload image to storage"])
                }
                
                // Return the public URL for the image
                return URL(string: "\(self.supabaseUrl)/storage/v1/object/public/images/\(filename)")!
            }
            .flatMap { imageUrl -> AnyPublisher<ImageModel, Error> in
                // Now create a record in the images table
                let imageRecord = [
                    "url": imageUrl.absoluteString,
                    "photo_date": ISO8601DateFormatter().string(from: photoDate),
                    "metadata": metadata ?? [:]
                ] as [String: Any]
                
                // Convert the record to JSON data
                guard let jsonData = try? JSONSerialization.data(withJSONObject: imageRecord) else {
                    return Fail(error: NSError(domain: "SupabaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize image record"]))
                        .eraseToAnyPublisher()
                }
                
                // Create the database insert request
                guard let dbUrl = URL(string: "\(self.supabaseUrl)/rest/v1/images") else {
                    return Fail(error: NSError(domain: "SupabaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid database URL"]))
                        .eraseToAnyPublisher()
                }
                
                var dbRequest = URLRequest(url: dbUrl)
                dbRequest.httpMethod = "POST"
                dbRequest.addValue(self.supabaseKey, forHTTPHeaderField: "apikey")
                dbRequest.addValue("Bearer \(self.supabaseKey)", forHTTPHeaderField: "Authorization")
                dbRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
                dbRequest.addValue("return=representation", forHTTPHeaderField: "Prefer")
                dbRequest.httpBody = jsonData
                
                // Insert the record into the database
                return self.session.dataTaskPublisher(for: dbRequest)
                    .tryMap { data, response -> Data in
                        guard let httpResponse = response as? HTTPURLResponse,
                              (200...299).contains(httpResponse.statusCode) else {
                            throw NSError(domain: "SupabaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to insert image record into database"])
                        }
                        return data
                    }
                    .decode(type: [SupabaseImageResponse].self, decoder: JSONDecoder())
                    .map { responses -> ImageModel in
                        let response = responses[0]
                        let photoDate = ISO8601DateFormatter().date(from: response.photo_date ?? "") ?? Date()
                        let createdAt = ISO8601DateFormatter().date(from: response.created_at ?? "") ?? Date()
                        
                        return ImageModel(
                            id: response.id,
                            imageUrl: response.url,
                            photoDate: photoDate,
                            createdAt: createdAt,
                            metadata: response.metadata
                        )
                    }
                    .eraseToAnyPublisher()
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