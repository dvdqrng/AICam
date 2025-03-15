import SwiftUI
import Combine

/// A utility view to test Supabase configuration
struct SupabaseConfigTest: View {
    @State private var testResults: String = "Ready to test..."
    @State private var isLoading: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Supabase Configuration Test")
                .font(.title)
                .padding()
            
            if isLoading {
                ProgressView("Testing connection...")
            } else {
                ScrollView {
                    Text(testResults)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
                .frame(maxHeight: 300)
            }
            
            HStack(spacing: 16) {
                Button("Test Connection") {
                    testConnection()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Test User Fetch") {
                    testUserFetch()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Test Images Fetch") {
                    testImagesFetch()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    private func testConnection() {
        isLoading = true
        testResults = "Testing connection...\n"
        
        let testUrl = "https://bidgqmzbwzoeifenmixm.supabase.co/rest/v1/users?select=count&limit=0"
        let apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpZGdxbXpid3pvZWlmZW5taXhtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIwMzc1NzUsImV4cCI6MjA1NzYxMzU3NX0.1xXs_3JX9AiEYbxZT3y_1lURONv6AEyKqls_XmLLyV0"
        
        guard let url = URL(string: testUrl) else {
            testResults += "❌ Error: Invalid URL\n"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        testResults += "URL: \(testUrl)\n"
        testResults += "API Key: \(apiKey.prefix(20))...\n\n"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    testResults += "❌ Connection error: \(error.localizedDescription)\n"
                    isLoading = false
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    testResults += "❌ Invalid response type\n"
                    isLoading = false
                    return
                }
                
                testResults += "HTTP Status: \(httpResponse.statusCode)\n"
                
                if (200...299).contains(httpResponse.statusCode) {
                    testResults += "✅ Connection successful!\n"
                    
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        testResults += "Response: \(responseString)\n"
                    }
                } else {
                    testResults += "❌ Server error with status code: \(httpResponse.statusCode)\n"
                    
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        testResults += "Error details: \(responseString)\n"
                    }
                }
                
                isLoading = false
            }
        }.resume()
    }
    
    private func testUserFetch() {
        isLoading = true
        testResults = "Testing user fetch...\n"
        
        let testUrl = "https://bidgqmzbwzoeifenmixm.supabase.co/rest/v1/users?select=*&limit=5"
        let apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpZGdxbXpid3pvZWlmZW5taXhtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIwMzc1NzUsImV4cCI6MjA1NzYxMzU3NX0.1xXs_3JX9AiEYbxZT3y_1lURONv6AEyKqls_XmLLyV0"
        
        guard let url = URL(string: testUrl) else {
            testResults += "❌ Error: Invalid URL\n"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    testResults += "❌ Connection error: \(error.localizedDescription)\n"
                    isLoading = false
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    testResults += "❌ Invalid response type\n"
                    isLoading = false
                    return
                }
                
                testResults += "HTTP Status: \(httpResponse.statusCode)\n"
                
                if (200...299).contains(httpResponse.statusCode) {
                    testResults += "✅ User fetch successful!\n"
                    
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        testResults += "Response: \(responseString.prefix(500))...\n"
                    }
                } else {
                    testResults += "❌ User fetch failed with status code: \(httpResponse.statusCode)\n"
                    
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        testResults += "Error details: \(responseString)\n"
                    }
                }
                
                isLoading = false
            }
        }.resume()
    }
    
    private func testImagesFetch() {
        isLoading = true
        testResults = "Testing images fetch...\n"
        
        let testUrl = "https://bidgqmzbwzoeifenmixm.supabase.co/rest/v1/images?select=*&limit=5"
        let apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpZGdxbXpid3pvZWlmZW5taXhtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIwMzc1NzUsImV4cCI6MjA1NzYxMzU3NX0.1xXs_3JX9AiEYbxZT3y_1lURONv6AEyKqls_XmLLyV0"
        
        guard let url = URL(string: testUrl) else {
            testResults += "❌ Error: Invalid URL\n"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    testResults += "❌ Connection error: \(error.localizedDescription)\n"
                    isLoading = false
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    testResults += "❌ Invalid response type\n"
                    isLoading = false
                    return
                }
                
                testResults += "HTTP Status: \(httpResponse.statusCode)\n"
                
                if (200...299).contains(httpResponse.statusCode) {
                    testResults += "✅ Images fetch successful!\n"
                    
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        testResults += "Response: \(responseString.prefix(500))...\n"
                    }
                } else {
                    testResults += "❌ Images fetch failed with status code: \(httpResponse.statusCode)\n"
                    
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        testResults += "Error details: \(responseString)\n"
                    }
                }
                
                isLoading = false
            }
        }.resume()
    }
}

#Preview {
    SupabaseConfigTest()
} 