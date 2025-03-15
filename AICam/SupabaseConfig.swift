//
//  SupabaseConfig.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import Foundation
import Supabase

/// Helper struct to ensure the Supabase SDK is properly integrated
struct SupabaseConfig {
    /// Supabase URL for the project
    static let supabaseUrl = "https://bidgqmzbwzoeifenmixm.supabase.co"
    
    /// Supabase API key
    static let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpZGdxbXpid3pvZWlmZW5taXhtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIwMzc1NzUsImV4cCI6MjA1NzYxMzU3NX0.1xXs_3JX9AiEYbxZT3y_1lURONv6AEyKqls_XmLLyV0"
    
    /// Creates a configured Supabase client
    static func createClient() -> SupabaseClient {
        return SupabaseClient(
            supabaseURL: URL(string: supabaseUrl)!,
            supabaseKey: supabaseKey
        )
    }
} 