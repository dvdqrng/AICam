//
//  AICamApp.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import SwiftUI
import SwiftData

@main
struct AICamApp: App {
    @StateObject private var authService = AuthService.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            ImageModel.self,
            UserModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if authService.currentUser != nil {
                // User is logged in, show the main app
                NavigationView {
                    ImageGalleryView()
                }
                .environmentObject(authService)
            } else {
                // User is not logged in, show login screen
                LoginView()
                    .environmentObject(authService)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
