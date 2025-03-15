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
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService.shared)
}
