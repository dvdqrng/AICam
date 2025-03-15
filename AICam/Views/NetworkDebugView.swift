//
//  NetworkDebugView.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import SwiftUI

/// A view for debugging network issues
struct NetworkDebugView: View {
    @State private var diagnosticResults: [String] = []
    @State private var isRunningDiagnostics = false
    @State private var apiKeyDetails: [String: String] = [:]
    @State private var isAnalyzingKey = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Network Diagnostics")) {
                    if isRunningDiagnostics {
                        ProgressView("Running diagnostics...")
                            .padding()
                    } else if !diagnosticResults.isEmpty {
                        ForEach(diagnosticResults, id: \.self) { result in
                            Text(result)
                                .font(.system(.body, design: .monospaced))
                                .padding(.vertical, 2)
                        }
                    } else {
                        Text("Run diagnostics to check network connectivity")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: runDiagnostics) {
                        Label("Run Diagnostics", systemImage: "network")
                    }
                    .disabled(isRunningDiagnostics)
                }
                
                Section(header: Text("API Key Analysis")) {
                    if isAnalyzingKey {
                        ProgressView("Analyzing API key...")
                            .padding()
                    } else if !apiKeyDetails.isEmpty {
                        ForEach(apiKeyDetails.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            VStack(alignment: .leading) {
                                Text(key)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Text(value)
                                    .font(.body)
                            }
                            .padding(.vertical, 2)
                        }
                    } else {
                        Text("Analyze API key to check its validity")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: analyzeApiKey) {
                        Label("Analyze API Key", systemImage: "key")
                    }
                    .disabled(isAnalyzingKey)
                }
            }
            .navigationTitle("Network Debug")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func runDiagnostics() {
        isRunningDiagnostics = true
        diagnosticResults = ["Starting network diagnostics..."]
        
        NetworkDebugger.shared.diagnoseNetworkIssues { results in
            self.diagnosticResults = results
            self.isRunningDiagnostics = false
        }
    }
    
    private func analyzeApiKey() {
        isAnalyzingKey = true
        apiKeyDetails = ["Analyzing": "Checking API key format and validity..."]
        
        DispatchQueue.global().async {
            let results = NetworkDebugger.shared.validateSupabaseAPIKey()
            
            DispatchQueue.main.async {
                self.apiKeyDetails = results
                self.isAnalyzingKey = false
            }
        }
    }
}

/// A view for displaying a troubleshooting item
struct TroubleshootingItem: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .fontWeight(.semibold)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 5)
    }
}

#Preview {
    NetworkDebugView()
} 