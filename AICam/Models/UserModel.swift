//
//  UserModel.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import Foundation

/// Model representing a user account
final class UserModel: Codable {
    /// Unique identifier for the user
    var id: String
    
    /// Apple ID used for authentication
    var appleId: String
    
    /// User's email address
    var email: String?
    
    /// User's display name
    var name: String?
    
    /// URL to user's avatar image
    var avatarUrl: String?
    
    /// Date when the user account was created
    var createdAt: Date
    
    /// Date of last login
    var lastLogin: Date
    
    init(id: String, appleId: String, email: String? = nil, name: String? = nil, avatarUrl: String? = nil, createdAt: Date = Date(), lastLogin: Date = Date()) {
        self.id = id
        self.appleId = appleId
        self.email = email
        self.name = name
        self.avatarUrl = avatarUrl
        self.createdAt = createdAt
        self.lastLogin = lastLogin
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id
        case appleId = "apple_id"
        case email
        case name
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case lastLogin = "last_login"
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        appleId = try container.decode(String.self, forKey: .appleId)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastLogin = try container.decode(Date.self, forKey: .lastLogin)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(appleId, forKey: .appleId)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastLogin, forKey: .lastLogin)
    }
} 