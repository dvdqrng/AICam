//
//  ImageModel.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import Foundation

/// Model representing an image stored in Supabase
/// 
/// IMPORTANT: The id field in the Supabase images table is an Integer (SERIAL),
/// not a UUID like in the users table. This model has been updated to reflect
/// this difference in data types between tables.
final class ImageModel: Codable {
    /// Unique identifier for the image
    var id: Int
    
    /// User ID who owns this image
    var userId: String?
    
    /// URL of the image in Supabase storage
    var imageUrl: String
    
    /// Date when the photo was taken
    var photoDate: Date
    
    /// Date when the image was added to the database
    var createdAt: Date
    
    /// Additional metadata for the image (optional)
    var metadata: [String: String]?
    
    /// Local cached image path if available
    var localCachePath: String?
    
    init(id: Int, imageUrl: String, photoDate: Date, createdAt: Date, userId: String? = nil, metadata: [String: String]? = nil) {
        self.id = id
        self.imageUrl = imageUrl
        self.photoDate = photoDate
        self.createdAt = createdAt
        self.userId = userId
        self.metadata = metadata
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id" // Map from snake_case in JSON to camelCase in Swift
        case imageUrl = "image_url"
        case photoDate = "photo_date"
        case createdAt = "created_at"
        case metadata
        case localCachePath = "local_cache_path"
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        imageUrl = try container.decode(String.self, forKey: .imageUrl)
        
        // Handle potential missing photo_date field
        if container.contains(.photoDate) {
            photoDate = try container.decode(Date.self, forKey: .photoDate)
        } else {
            // Use created_at as fallback if photo_date is missing
            photoDate = try container.decode(Date.self, forKey: .createdAt)
        }
        
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
        localCachePath = try container.decodeIfPresent(String.self, forKey: .localCachePath)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(imageUrl, forKey: .imageUrl)
        try container.encode(photoDate, forKey: .photoDate)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(localCachePath, forKey: .localCachePath)
        try container.encodeIfPresent(userId, forKey: .userId)
    }
} 