//
//  SupabaseService.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import Foundation
import Combine
import Network

/// Service for Supabase API integration
/// 
/// For detailed integration guidelines, refer to:
/// - Rules/SupabaseIntegrationRules.md
///
/// Key concepts:
/// - Field Naming: Supabase uses snake_case, Swift uses camelCase (use CodingKeys to map)
/// - Date Handling: Custom decoder handles variable ISO8601 formats
/// - API Headers: Always include apikey, Content-Type, and proper Prefer headers
/// - Sign-in with Apple: Follows fetch-then-create/update pattern

/// Custom error type for network operations
enum NetworkError: Error {
    case noInternet
    case hostNotFound
    case serverError(Int)
    case decodingError(DecodingError)
    case unknown(Error)
    
    var localizedDescription: String {
        switch self {
        case .noInternet:
            return "No internet connection. Please check your network settings."
        case .hostNotFound:
            return "Could not connect to the server. The service might be temporarily unavailable."
        case .serverError(let statusCode):
            return "Server error with status code: \(statusCode)"
        case .decodingError(let error):
            return "Error processing the response: \(error.localizedDescription)"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

/// Service for interacting with Supabase
class SupabaseService {
    /// Shared instance of the Supabase service
    static let shared = SupabaseService()
    
    /// URL of the Supabase API
    let supabaseUrl = "https://bidgqmzbwzoeifenmixm.supabase.co/rest/v1"
    
    /// Fixed URL format that matches the dashboard exactly
    let fixedUrl = "https://bidgqmzbwzoeifenmixm.supabase.co" // Without the /rest/v1 suffix
    
    /// API key for accessing Supabase
    let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpZGdxbXpid3pvZWlmZW5taXhtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIwMzc1NzUsImV4cCI6MjA1NzYxMzU3NX0.1xXs_3JX9AiEYbxZT3y_1lURONv6AEyKqls_XmLLyV0"
    
    /// Alternative API key to try if the first one fails
    let alternativeKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpZGdxbXpid3pvZWlmZW5taXhtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIwMzc1NzUsImV4cCI6MjA1NzYxMzU3NX0.1xXs_3JX9AiEYbxZT3y_1lURONv6AEyKqls_XmLLyV0"
    
    /// Corrected API key format from screenshot 
    let correctedKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpZGdxbXpid3pvZWlmZW5taXhtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIwMzc1NzUsImV4cCI6MjA1NzYxMzU3NX0.1xXs_3JX9AiEYbxZT3y_1lURONv6AEyKqls_XmLLyV0"
    
    /// URL session for making network requests
    var session: URLSession
    
    /// Network monitor to check connectivity
    private let networkMonitor = NWPathMonitor()
    private var isConnected = true
    
    /// Headers for Supabase API requests
    var headers: [String: String] {
        [
            "apikey": supabaseKey,
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        ]
    }
    
    /// Returns a configured JSONDecoder that handles date formats from Supabase
    /// 
    /// This decoder uses a custom date decoding strategy to handle the various date formats
    /// that might be returned by Supabase. The most common issue is that sometimes dates include
    /// milliseconds (.SSS) and sometimes they don't. This flexible approach tries multiple
    /// formats to ensure dates are parsed correctly regardless of the exact format returned.
    private func configuredDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        
        // Create a custom date decoding strategy that supports multiple formats
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 format with milliseconds
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
            
            // Try ISO8601 format without milliseconds
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
            
            // Try one more format with optional milliseconds
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
            
            // If none of the above worked, use ISO8601DateFormatter as a fallback
            if #available(iOS 15.0, *) {
                let iso8601Formatter = ISO8601DateFormatter()
                iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                }
            }
            
            // If we get here, log the problematic date string for debugging
            print("Failed to parse date string: \(dateString)")
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        
        return decoder
    }
    
    /// Private initializer for the singleton
    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "apikey": supabaseKey,
            "Content-Type": "application/json"
        ]
        session = URLSession(configuration: config)
        
        // Set up network monitoring
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
            print("Network connectivity status changed: \(path.status == .satisfied ? "Connected" : "Disconnected")")
        }
        networkMonitor.start(queue: DispatchQueue.global())
    }
    
    /// Converts URLError to a more descriptive NetworkError
    private func handleURLError(_ error: Error) -> NetworkError {
        if !isConnected {
            return .noInternet
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .noInternet
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return .hostNotFound
            default:
                return .unknown(error)
            }
        } else if let decodingError = error as? DecodingError {
            return .decodingError(decodingError)
        }
        
        return .unknown(error)
    }
    
    /// Fetches images from Supabase
    /// - Parameters:
    ///   - startIndex: The starting index for pagination
    ///   - limit: The maximum number of images to fetch
    ///   - userId: The user ID to filter images by
    /// - Returns: A publisher that emits the fetched images or an error
    func fetchImages(startIndex: Int = 0, limit: Int = 10, userId: String? = nil) -> AnyPublisher<[ImageModel], Error> {
        // Check for internet connectivity first
        if !isConnected {
            return Fail(error: NetworkError.noInternet).eraseToAnyPublisher()
        }
        
        guard var components = URLComponents(string: "\(supabaseUrl)/images") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "offset", value: "\(startIndex)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        // Add filter by user_id if provided
        if let userId = userId {
            queryItems.append(URLQueryItem(name: "user_id", value: "eq.\(userId)"))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        print("Fetching images from URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        // Add a header to prevent duplicates in the response
        request.addValue("id", forHTTPHeaderField: "Prefer")
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Response is not HTTPURLResponse")
                    throw URLError(.badServerResponse)
                }
                
                print("HTTP Status Code: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response Body: \(responseString)")
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    print("Error: HTTP Status \(httpResponse.statusCode)")
                    print("Response Headers: \(httpResponse.allHeaderFields)")
                    throw NetworkError.serverError(httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: [ImageModel].self, decoder: configuredDecoder())
            .map { images -> [ImageModel] in
                // Fix the URLs to ensure they don't have double slashes or trailing question marks
                return images.map { image in
                    let cleanUrl = image.imageUrl
                        .replacingOccurrences(of: "//storage", with: "/storage")
                        .trimmingCharacters(in: CharacterSet(charactersIn: "?"))
                    
                    // Create a new image model with the clean URL
                    return ImageModel(
                        id: image.id,
                        imageUrl: cleanUrl,
                        photoDate: image.photoDate,
                        createdAt: image.createdAt,
                        userId: image.userId,
                        metadata: image.metadata
                    )
                }
            }
            .mapError { [weak self] error -> Error in
                guard let self = self else { 
                    // If self is nil, just return the original error instead of trying to process it
                    print("Self is nil in mapError - returning original error")
                    return error 
                }
                
                if let decodingError = error as? DecodingError {
                    print("Decoding Error: \(decodingError)")
                    // Log more detailed information about the decoding error
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("Key '\(key)' not found: \(context.debugDescription)")
                        print("CodingPath: \(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("Value of type '\(type)' not found: \(context.debugDescription)")
                        print("CodingPath: \(context.codingPath)")
                    case .typeMismatch(let type, let context):
                        print("Type '\(type)' mismatch: \(context.debugDescription)")
                        print("CodingPath: \(context.codingPath)")
                    case .dataCorrupted(let context):
                        print("Data corrupted: \(context.debugDescription)")
                        print("CodingPath: \(context.codingPath)")
                    @unknown default:
                        print("Unknown decoding error: \(decodingError)")
                    }
                    return NetworkError.decodingError(decodingError)
                }
                
                let networkError = self.handleURLError(error)
                print("Error fetching images: \(networkError.localizedDescription)")
                return networkError
            }
            .eraseToAnyPublisher()
    }
    
    /// Creates or updates a user in the Supabase database
    /// - Parameter user: The user model to create or update
    /// - Returns: A publisher that emits the saved user or an error
    func createOrUpdateUser(user: UserModel) -> AnyPublisher<UserModel, Error> {
        // Check for internet connectivity first
        if !isConnected {
            return Fail(error: NetworkError.noInternet).eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "\(supabaseUrl)/users") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        print("Creating/updating user at URL: \(url.absoluteString)")
        
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
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Response is not HTTPURLResponse")
                    throw URLError(.badServerResponse)
                }
                
                print("HTTP Status Code: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response Body: \(responseString)")
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    print("Error: HTTP Status \(httpResponse.statusCode)")
                    print("Response Headers: \(httpResponse.allHeaderFields)")
                    throw NetworkError.serverError(httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: [UserModel].self, decoder: configuredDecoder())
            .tryMap { users -> UserModel in
                // Return the first user from the array (Supabase returns an array)
                guard let user = users.first else {
                    throw URLError(.cannotParseResponse)
                }
                return user
            }
            .mapError { [weak self] error -> Error in
                guard let self = self else { 
                    // If self is nil, just return the original error instead of trying to process it
                    print("Self is nil in mapError - returning original error")
                    return error 
                }
                
                if let decodingError = error as? DecodingError {
                    print("Decoding Error: \(decodingError)")
                    // Log more detailed information about the decoding error
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("Key '\(key)' not found: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("Value of type '\(type)' not found: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("Type '\(type)' mismatch: \(context.debugDescription)")
                    case .dataCorrupted(let context):
                        print("Data corrupted: \(context.debugDescription)")
                    @unknown default:
                        print("Unknown decoding error: \(decodingError)")
                    }
                    return NetworkError.decodingError(decodingError)
                }
                
                let networkError = self.handleURLError(error)
                print("Error creating/updating user: \(networkError.localizedDescription)")
                return networkError
            }
            .eraseToAnyPublisher()
    }
    
    /// Fetches a user by their Apple ID
    /// - Parameter appleId: The Apple ID to search for
    /// - Returns: A publisher that emits the user if found or an error
    func fetchUserByAppleId(appleId: String) -> AnyPublisher<UserModel?, Error> {
        // Check for internet connectivity first
        if !isConnected {
            return Fail(error: NetworkError.noInternet).eraseToAnyPublisher()
        }
        
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
        
        print("Fetching user from URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Response is not HTTPURLResponse")
                    throw URLError(.badServerResponse)
                }
                
                print("HTTP Status Code: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response Body: \(responseString)")
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    print("Error: HTTP Status \(httpResponse.statusCode)")
                    print("Response Headers: \(httpResponse.allHeaderFields)")
                    throw NetworkError.serverError(httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: [UserModel].self, decoder: configuredDecoder())
            .map { users -> UserModel? in
                return users.first
            }
            .mapError { [weak self] error -> Error in
                guard let self = self else { 
                    // If self is nil, just return the original error instead of trying to process it
                    print("Self is nil in mapError - returning original error")
                    return error 
                }
                
                if let decodingError = error as? DecodingError {
                    print("Decoding Error: \(decodingError)")
                    // Log more detailed information about the decoding error
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("Key '\(key)' not found: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("Value of type '\(type)' not found: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("Type '\(type)' mismatch: \(context.debugDescription)")
                    case .dataCorrupted(let context):
                        print("Data corrupted: \(context.debugDescription)")
                    @unknown default:
                        print("Unknown decoding error: \(decodingError)")
                    }
                    return NetworkError.decodingError(decodingError)
                }
                
                let networkError = self.handleURLError(error)
                print("Error fetching user: \(networkError.localizedDescription)")
                return networkError
            }
            .eraseToAnyPublisher()
    }
}

/// Extension with additional utility methods
extension SupabaseService {
    /// Checks if the Supabase server is reachable
    /// - Parameter completion: Closure that will be called with the result
    func checkServerReachability(completion: @escaping (Bool, String?) -> Void) {
        // First check if we have internet connectivity
        if !isConnected {
            completion(false, "No internet connection. Please check your network settings.")
            return
        }
        
        // Then try to ping the Supabase server with a simple request
        guard let url = URL(string: "\(supabaseUrl)/health") else {
            completion(false, "Invalid server URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        request.timeoutInterval = 10 // 10 seconds timeout
        
        let task = session.dataTask(with: request) { _, response, error in
            if let error = error {
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet, .networkConnectionLost:
                        completion(false, "No internet connection. Please check your network settings.")
                    case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                        // Try alternative approach if hostname cannot be resolved
                        self.tryAlternativeConnection { success, message in
                            completion(success, message)
                        }
                    case .timedOut:
                        completion(false, "Connection timed out. Please try again later.")
                    default:
                        completion(false, "Error connecting to server: \(error.localizedDescription)")
                    }
                } else {
                    completion(false, "Error connecting to server: \(error.localizedDescription)")
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Invalid server response")
                return
            }
            
            let isSuccess = (200...299).contains(httpResponse.statusCode)
            if isSuccess {
                completion(true, nil)
            } else {
                completion(false, "Server returned status code: \(httpResponse.statusCode)")
            }
        }
        
        task.resume()
    }
    
    /// Tries alternative approaches to connect to Supabase
    /// - Parameter completion: Closure that will be called with the result
    private func tryAlternativeConnection(completion: @escaping (Bool, String?) -> Void) {
        print("Trying alternative connection approaches...")
        
        // Try fixed URL without path
        tryWithFixedUrl { success, message in
            if success {
                completion(true, "Connected using fixed URL format")
                return
            }
            
            // Try alternative API key
            self.tryWithAlternativeKey { success, message in
                if success {
                    completion(true, "Connected using alternative API key")
                    return
                }
                
                // Try direct IP address if we have one
                self.tryWithDirectIP { success, message in
                    if success {
                        completion(true, "Connected using direct IP address")
                        return
                    }
                    
                    // Try corrected key
                    self.tryWithCorrectedKey { success, message in
                        if success {
                            completion(true, "Connected using corrected API key")
                            return
                        }
                        
                        // All alternatives failed
                        completion(false, "All connection attempts failed. Please check your Supabase project settings.")
                    }
                }
            }
        }
    }
    
    /// Tries connecting with the fixed URL format
    /// - Parameter completion: Closure that will be called with the result
    private func tryWithFixedUrl(completion: @escaping (Bool, String?) -> Void) {
        print("Trying connection with fixed URL format...")
        
        guard let url = URL(string: "\(fixedUrl)") else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Fixed URL connection failed: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Invalid response")
                return
            }
            
            let isSuccess = (200...299).contains(httpResponse.statusCode)
            completion(isSuccess, isSuccess ? nil : "Server returned status code: \(httpResponse.statusCode)")
        }.resume()
    }
    
    /// Tries connecting with the alternative API key
    /// - Parameter completion: Closure that will be called with the result
    private func tryWithAlternativeKey(completion: @escaping (Bool, String?) -> Void) {
        print("Trying connection with alternative API key...")
        
        guard let url = URL(string: "\(supabaseUrl)") else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = [
            "apikey": alternativeKey,
            "Content-Type": "application/json"
        ]
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Alternative key connection failed: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Invalid response")
                return
            }
            
            let isSuccess = (200...299).contains(httpResponse.statusCode)
            completion(isSuccess, isSuccess ? nil : "Server returned status code: \(httpResponse.statusCode)")
        }.resume()
    }
    
    /// Tries connecting with a direct IP address
    /// - Parameter completion: Closure that will be called with the result
    private func tryWithDirectIP(completion: @escaping (Bool, String?) -> Void) {
        print("Trying connection with direct IP (if available)...")
        
        // This would typically involve a separate lookup to get the IP
        // For now, we'll simulate checking with a fake IP and fall back to hostname
        let directIPUrl = "https://104.18.27.41/rest/v1"
        
        guard let url = URL(string: directIPUrl) else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Direct IP connection failed: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Invalid response")
                return
            }
            
            let isSuccess = (200...299).contains(httpResponse.statusCode)
            completion(isSuccess, isSuccess ? nil : "Server returned status code: \(httpResponse.statusCode)")
        }.resume()
    }
    
    /// Tries connecting with the corrected API key
    /// - Parameter completion: Closure that will be called with the result
    private func tryWithCorrectedKey(completion: @escaping (Bool, String?) -> Void) {
        print("Trying connection with corrected API key...")
        
        guard let url = URL(string: "\(supabaseUrl)") else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = [
            "apikey": correctedKey,
            "Content-Type": "application/json"
        ]
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Corrected key connection failed: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Invalid response")
                return
            }
            
            let isSuccess = (200...299).contains(httpResponse.statusCode)
            completion(isSuccess, isSuccess ? nil : "Server returned status code: \(httpResponse.statusCode)")
        }.resume()
    }
    
    /// Tests the database connection with a simple query
    /// - Returns: A publisher that emits true if the connection is successful, false otherwise
    func testConnection() -> AnyPublisher<Bool, Never> {
        print("Testing connection to Supabase at URL: \(supabaseUrl)")
        
        // First check if we have internet connectivity
        if !isConnected {
            print("No internet connection detected")
            return Just(false).eraseToAnyPublisher()
        }
        
        // Try to fetch the API version or another simple endpoint
        guard let url = URL(string: "\(supabaseUrl)") else {
            print("Invalid server URL")
            return Just(false).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Bool in
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Response is not HTTPURLResponse")
                    return false
                }
                
                print("HTTP Status Code: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response Body: \(responseString)")
                }
                
                return (200...299).contains(httpResponse.statusCode)
            }
            .replaceError(with: false)
            .eraseToAnyPublisher()
    }
    
    /// Validates the Supabase URL and tests connectivity
    /// - Returns: A publisher that emits a boolean indicating if the URL is valid and reachable
    func validateSupabaseUrl() -> AnyPublisher<Bool, Never> {
        // Check if the URL is properly formatted
        guard URL(string: supabaseUrl) != nil else {
            return Just(false).eraseToAnyPublisher()
        }
        
        // Create a subject to handle the completion
        let resultSubject = PassthroughSubject<Bool, Never>()
        
        // Check server reachability
        checkServerReachability { isReachable, _ in
            resultSubject.send(isReachable)
            resultSubject.send(completion: .finished)
        }
        
        return resultSubject.eraseToAnyPublisher()
    }
}

/// Response model for Supabase image data
struct SupabaseImageResponse: Codable {
    let id: Int
    let url: String
    let photoDate: String?
    let createdAt: String?
    let metadata: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case url
        case photoDate = "photo_date"
        case createdAt = "created_at"
        case metadata
    }
} 