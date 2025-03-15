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
    @State private var showTestView = true
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            ImageModel.self,
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
            if showTestView {
                // Show the integration test view first to check Supabase SDK integration
                SupabaseIntegrationTest()
                    .onDisappear {
                        showTestView = false
                    }
                    .overlay(
                        VStack {
                            Spacer()
                            Button("Continue to Main App") {
                                showTestView = false
                            }
                            .padding()
                            .background(Color.secondary)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.bottom, 40)
                        }
                    )
            } else {
                // Show the main app view
                NavigationView {
                    ImageGalleryView()
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
