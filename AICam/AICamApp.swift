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
            NavigationView {
                ImageGalleryView()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
