//
//  SupabaseService.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import Foundation
import Combine

/// Service for interacting with Supabase
class SupabaseService {
    /// Shared instance of the Supabase service
    static let shared = SupabaseService()
    
    /// URL of the Supabase API
    let supabaseUrl = "https://qwsqavazpqofzedspnhc.supabase.co/rest/v1"
    
    /// API key for accessing Supabase
    let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3c3FhdmF6cHFvZnplZHNwbmhjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTA1MzI1OTgsImV4cCI6MjAyNjEwODU5OH0.TDpSGiRQ78sDcmz0qoLLbCIUP-_4cMKq7N5-PpnXncs"
    
    /// URL session for making network requests
    var session: URLSession
    
    /// Headers for Supabase API requests
    var headers: [String: String] {
        [
            "apikey": supabaseKey,
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        ]
    }
    
    /// Private initializer for the singleton
    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "apikey": supabaseKey,
            "Content-Type": "application/json"
        ]
        session = URLSession(configuration: config)
    }
    
    /// Fetches images from Supabase
    /// - Parameters:
    ///   - startIndex: The starting index for pagination
    ///   - limit: The maximum number of images to fetch
    /// - Returns: A publisher that emits the fetched images or an error
    func fetchImages(startIndex: Int = 0, limit: Int = 10) -> AnyPublisher<[ImageModel], Error> {
        guard var components = URLComponents(string: "\(supabaseUrl)/images") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "offset", value: "\(startIndex)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        guard let url = components.url else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: [ImageModel].self, decoder: JSONDecoder())
            .mapError { error -> Error in
                print("Error fetching images: \(error)")
                return error
            }
            .eraseToAnyPublisher()
    }
    
    /// Creates or updates a user in the Supabase database
    /// - Parameter user: The user model to create or update
    /// - Returns: A publisher that emits the saved user or an error
    func createOrUpdateUser(user: UserModel) -> AnyPublisher<UserModel, Error> {
        guard let url = URL(string: "\(supabaseUrl)/users") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        
        // Create the user data
        let userData: [String: Any] = [
            "apple_id": user.appleId,
            "email": user.email ?? "",
            "name": user.name ?? "",
            "avatar_url": user.avatarUrl ?? "",
            "last_login": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Add the Prefer header for upsert
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: userData)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: [UserModel].self, decoder: JSONDecoder())
            .map { users -> UserModel in
                // Return the first user from the array (Supabase returns an array)
                guard let user = users.first else {
                    throw URLError(.cannotParseResponse)
                }
                return user
            }
            .mapError { error -> Error in
                print("Error creating/updating user: \(error)")
                return error
            }
            .eraseToAnyPublisher()
    }
    
    /// Fetches a user by their Apple ID
    /// - Parameter appleId: The Apple ID to search for
    /// - Returns: A publisher that emits the user if found or an error
    func fetchUserByAppleId(appleId: String) -> AnyPublisher<UserModel?, Error> {
        guard var components = URLComponents(string: "\(supabaseUrl)/users") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        components.queryItems = [
            URLQueryItem(name: "apple_id", value: "eq.\(appleId)"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "limit", value: "1")
        ]
        
        guard let url = components.url else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: [UserModel].self, decoder: JSONDecoder())
            .map { users -> UserModel? in
                return users.first
            }
            .mapError { error -> Error in
                print("Error fetching user: \(error)")
                return error
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