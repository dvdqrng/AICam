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
        // Check if we can import Supabase
        #if canImport(Supabase)
        integrationStatus = "Import successful, testing client creation..."
        
        // Try to create a Supabase client
        do {
            _ = SupabaseConfig.createClient()
            integrationStatus = "✅ Success! Supabase SDK is properly integrated."
        } catch {
            integrationStatus = "❌ Error creating client: \(error.localizedDescription)"
        }
        #else
        integrationStatus = "❌ Failed: Cannot import Supabase. Package is not properly integrated."
        #endif
    }
}

#Preview {
    SupabaseIntegrationTest()
} 