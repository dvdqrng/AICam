//
//  SupabaseIntegrationTest.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import SwiftUI

/// View that displays Supabase integration status
struct SupabaseIntegrationTest: View {
    @State private var integrationStatus: String = "Testing..."
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Supabase Integration Test")
                .font(.title)
            
            Text(integrationStatus)
                .font(.body)
                .padding()
                .background(integrationStatus.contains("Success") ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                .cornerRadius(8)
            
            Button("Test Integration") {
                testSupabaseIntegration()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .onAppear {
            testSupabaseIntegration()
        }
    }
    
    private func testSupabaseIntegration() {
        // Test with direct REST API call
        let supabaseUrl = "https://bidgqmzbwzoeifenmixm.supabase.co"
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpZGdxbXpid3pvZWlmZW5taXhtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIwMzc1NzUsImV4cCI6MjA1NzYxMzU3NX0.1xXs_3JX9AiEYbxZT3y_1lURONv6AEyKqls_XmLLyV0"
        
        guard let url = URL(string: "\(supabaseUrl)/rest/v1/images?select=id&limit=1") else {
            integrationStatus = "❌ Failed: Invalid URL construction"
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.integrationStatus = "❌ Connection error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.integrationStatus = "❌ Invalid response type"
                    return
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    self.integrationStatus = "✅ Success! Connection to Supabase API working."
                } else {
                    self.integrationStatus = "❌ Server error: HTTP \(httpResponse.statusCode)"
                }
            }
        }
        
        task.resume()
    }
}

#Preview {
    SupabaseIntegrationTest()
} 