//
//  NetworkErrorView.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import SwiftUI

/// A view modifier that displays network error alerts
struct NetworkErrorAlert: ViewModifier {
    /// The error message to display
    @Binding var errorMessage: String?
    
    /// Retry action to be performed when the user taps the retry button
    var retryAction: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .alert("Connection Error", isPresented: .init(get: {
                errorMessage != nil
            }, set: { newValue in
                if !newValue {
                    errorMessage = nil
                }
            })) {
                Button("OK", role: .cancel) {}
                
                if let retryAction = retryAction {
                    Button("Retry") {
                        retryAction()
                    }
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
    }
}

/// A view that displays a network connection error banner
struct NetworkConnectionBanner: View {
    /// Whether the network is connected
    @Binding var isConnected: Bool
    
    /// Retry action to be performed when the user taps the banner
    var retryAction: (() -> Void)?
    
    var body: some View {
        VStack {
            if !isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.white)
                    
                    Text("No Internet Connection")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if let retryAction = retryAction {
                        Button(action: retryAction) {
                            Text("Retry")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding()
                .background(Color.red)
                .cornerRadius(8)
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Spacer()
        }
    }
}

/// Extension to add convenience methods for network error handling
extension View {
    /// Adds an alert that displays network error messages
    /// - Parameters:
    ///   - errorMessage: Binding to the error message to display
    ///   - retryAction: Optional action to perform when the user taps the retry button
    /// - Returns: A view with the network error alert modifier applied
    func networkErrorAlert(errorMessage: Binding<String?>, retryAction: (() -> Void)? = nil) -> some View {
        self.modifier(NetworkErrorAlert(errorMessage: errorMessage, retryAction: retryAction))
    }
    
    /// Adds a banner that displays when the network is disconnected
    /// - Parameters:
    ///   - isConnected: Binding to whether the network is connected
    ///   - retryAction: Optional action to perform when the user taps the retry button
    /// - Returns: A view with the network connection banner added
    func networkConnectionBanner(isConnected: Binding<Bool>, retryAction: (() -> Void)? = nil) -> some View {
        ZStack(alignment: .top) {
            self
            NetworkConnectionBanner(isConnected: isConnected, retryAction: retryAction)
        }
    }
} 