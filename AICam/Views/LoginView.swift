//
//  LoginView.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        VStack(spacing: 30) {
            // Logo and app name
            VStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                
                Text("AICam")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .padding(.top, 60)
            
            Spacer()
            
            // Instructions
            Text("Sign in to view your images")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Error message if any
            if let errorMessage = authService.errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            // Sign in with Apple button
            SignInWithAppleButton()
                .frame(height: 50)
                .padding(.horizontal, 40)
                .disabled(authService.isLoading)
            
            // Loading indicator
            if authService.isLoading {
                ProgressView("Signing in...")
                    .padding()
            }
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}

/// Custom SwiftUI component for Sign in with Apple button
struct SignInWithAppleButton: UIViewRepresentable {
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleButtonPress), for: .touchUpInside)
        return button
    }
    
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        @objc func handleButtonPress() {
            AuthService.shared.signInWithApple()
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService.shared)
} 