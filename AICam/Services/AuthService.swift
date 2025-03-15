//
//  AuthService.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import Foundation
import AuthenticationServices
import Combine
import SwiftData

/// Service for handling user authentication
class AuthService: NSObject, ObservableObject {
    /// Shared instance of the authentication service
    static let shared = AuthService()
    
    /// Current logged in user
    @Published var currentUser: UserModel?
    
    /// Loading state for authentication operations
    @Published var isLoading = false
    
    /// Error message if authentication fails
    @Published var errorMessage: String?
    
    /// Service for interacting with Supabase
    private let supabaseService: SupabaseService
    
    /// Cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// User defaults key for storing user data
    private let userDefaultsKey = "com.aicam.currentUser"
    
    /// Initializes the authentication service with dependencies
    /// - Parameter supabaseService: The service for accessing Supabase
    private override init() {
        self.supabaseService = SupabaseService.shared
        super.init()
        
        // Load saved user from UserDefaults if available
        loadSavedUser()
    }
    
    /// Signs in with Apple
    func signInWithApple() {
        isLoading = true
        errorMessage = nil
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    /// Signs out the current user
    func signOut() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        
        // Clear any auth-related caches or tokens if needed
    }
    
    /// Creates or updates a user in Supabase and stores it locally
    /// - Parameter appleIDCredential: The Apple ID credentials
    private func createOrUpdateUser(with appleIDCredential: ASAuthorizationAppleIDCredential) {
        // Extract user info from Apple ID credential
        let appleUserID = appleIDCredential.user
        let email = appleIDCredential.email
        
        // Combine first and last name if available
        var name: String?
        if let firstName = appleIDCredential.fullName?.givenName,
           let lastName = appleIDCredential.fullName?.familyName {
            name = "\(firstName) \(lastName)"
        } else if let firstName = appleIDCredential.fullName?.givenName {
            name = firstName
        } else if let lastName = appleIDCredential.fullName?.familyName {
            name = lastName
        }
        
        // Check if user already exists
        supabaseService.fetchUserByAppleId(appleId: appleUserID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.isLoading = false
                    self?.errorMessage = "Error fetching user: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] existingUser in
                guard let self = self else { return }
                
                if let user = existingUser {
                    // User exists, update and use it
                    var updatedUser = user
                    // Only update email and name if they are new
                    if user.email == nil, let email = email {
                        updatedUser.email = email
                    }
                    if user.name == nil, let name = name {
                        updatedUser.name = name
                    }
                    updatedUser.lastLogin = Date()
                    
                    self.saveAndSetCurrentUser(updatedUser)
                } else {
                    // Create new user
                    let newUser = UserModel(
                        id: UUID().uuidString,
                        appleId: appleUserID,
                        email: email,
                        name: name,
                        createdAt: Date(),
                        lastLogin: Date()
                    )
                    
                    self.saveUserToSupabase(newUser)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Saves a user to Supabase
    /// - Parameter user: The user to save
    private func saveUserToSupabase(_ user: UserModel) {
        supabaseService.createOrUpdateUser(user: user)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = "Error saving user: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] savedUser in
                self?.saveAndSetCurrentUser(savedUser)
            }
            .store(in: &cancellables)
    }
    
    /// Saves the current user to UserDefaults and sets it as the current user
    /// - Parameter user: The user to save and set
    private func saveAndSetCurrentUser(_ user: UserModel) {
        // Set as current user
        self.currentUser = user
        self.isLoading = false
        
        // Save to UserDefaults
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userDefaultsKey)
        }
    }
    
    /// Loads the saved user from UserDefaults
    private func loadSavedUser() {
        if let userData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(UserModel.self, from: userData) {
            self.currentUser = user
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthService: ASAuthorizationControllerDelegate {
    /// Called when authorization succeeds
    /// - Parameters:
    ///   - controller: The authorization controller
    ///   - authorization: The authorization object
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            createOrUpdateUser(with: appleIDCredential)
        } else {
            isLoading = false
            errorMessage = "Unsupported credential type"
        }
    }
    
    /// Called when authorization fails
    /// - Parameters:
    ///   - controller: The authorization controller
    ///   - error: The error that occurred
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isLoading = false
        errorMessage = "Sign in failed: \(error.localizedDescription)"
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    /// Provides the presentation context for the authorization controller
    /// - Parameter controller: The authorization controller
    /// - Returns: The presentation window
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let window = UIApplication.shared.windows.first { $0.isKeyWindow }
        return window ?? UIWindow()
    }
}

/// Response model for user data from Supabase
struct UserResponse: Codable {
    let id: String
    let apple_id: String
    let email: String?
    let name: String?
    let avatar_url: String?
    let created_at: String
    let last_login: String
}

/// Codable version of UserModel for UserDefaults storage
struct UserModelCodable: Codable {
    let id: String
    let appleId: String
    let email: String?
    let name: String?
    let avatarUrl: String?
    let createdAt: Date
    let lastLogin: Date
} 