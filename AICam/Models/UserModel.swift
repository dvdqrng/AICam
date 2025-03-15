//
//  UserModel.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import Foundation
import SwiftData

/// Model representing a user account
@Model
final class UserModel {
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
} 