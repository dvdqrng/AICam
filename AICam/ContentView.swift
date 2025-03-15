//
//  ContentView.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        Group {
            if authService.currentUser != nil {
                // Show main app content
                ImageGalleryView()
                    .transition(.opacity)
            } else {
                // Show login screen
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.default, value: authService.currentUser != nil)
        // Add a debug button for network troubleshooting (optional)
        .overlay(alignment: .bottomTrailing) {
            #if DEBUG
            Button(action: {
                let networkDebugView = UIHostingController(rootView: NetworkDebugView())
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    rootViewController.present(networkDebugView, animated: true)
                }
            }) {
                HStack {
                    Image(systemName: "network")
                    Text("Debug")
                }
                .padding(8)
                .background(Color.red.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding()
            }
            #endif
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService.shared)
}
