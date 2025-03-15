//
//  ImageModel.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import Foundation
import SwiftData

/// Model representing an image stored in Supabase
@Model
final class ImageModel {
    /// Unique identifier for the image
    var id: String
    
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
    
    init(id: String, imageUrl: String, photoDate: Date, createdAt: Date, metadata: [String: String]? = nil) {
        self.id = id
        self.imageUrl = imageUrl
        self.photoDate = photoDate
        self.createdAt = createdAt
        self.metadata = metadata
    }
} 