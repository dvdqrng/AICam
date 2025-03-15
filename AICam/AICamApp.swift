//
//  AICamApp.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import SwiftUI

@main
struct AICamApp: App {
    @StateObject private var authService = AuthService.shared
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
            .environmentObject(authService)
        }
    }
}
