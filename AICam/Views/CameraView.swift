//
//  CameraView.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import SwiftUI
import AVFoundation
import Combine

/// View that handles camera capture and image upload
struct CameraView: View {
    /// Environment dismiss action to dismiss the view
    @Environment(\.dismiss) private var dismiss
    
    /// View model for controlling camera operations
    @StateObject private var viewModel = CameraViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview or captured image
                ZStack {
                    if let image = viewModel.capturedImage {
                        // Show captured image
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Show camera preview
                        CameraPreviewView(session: viewModel.session)
                            .ignoresSafeArea()
                            .onAppear {
                                viewModel.checkCameraPermission()
                            }
                    }
                }
                
                // Overlay for buttons and UI elements
                VStack {
                    Spacer()
                    
                    // Control buttons
                    if viewModel.capturedImage != nil {
                        HStack(spacing: 60) {
                            // Retake button
                            Button(action: {
                                viewModel.retakePhoto()
                            }) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.title)
                                    .padding()
                                    .background(Color.black.opacity(0.6))
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                            }
                            
                            // Upload button
                            Button(action: {
                                viewModel.uploadPhoto()
                            }) {
                                Image(systemName: "arrow.up.circle")
                                    .font(.title)
                                    .padding()
                                    .background(Color.black.opacity(0.6))
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                            }
                            .disabled(viewModel.isUploading)
                        }
                    } else {
                        // Capture button
                        Button(action: {
                            viewModel.capturePhoto()
                        }) {
                            Image(systemName: "circle")
                                .font(.system(size: 72))
                                .foregroundColor(.white)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                        .frame(width: 80, height: 80)
                                )
                        }
                    }
                }
                .padding(.bottom, 40)
                
                // Loading overlay during upload
                if viewModel.isUploading {
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .ignoresSafeArea()
                    
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2)
                        
                        Text("Uploading...")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top, 20)
                    }
                }
            }
            .navigationTitle("Take Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text(viewModel.alertTitle),
                    message: Text(viewModel.alertMessage),
                    dismissButton: .default(Text("OK")) {
                        if viewModel.uploadSuccess {
                            dismiss()
                        }
                    }
                )
            }
        }
    }
}

/// View model for camera operations
class CameraViewModel: ObservableObject {
    /// Capture session
    @Published var session = AVCaptureSession()
    
    /// Captured image
    @Published var capturedImage: UIImage?
    
    /// Loading state during upload
    @Published var isUploading = false
    
    /// Flag to show alert
    @Published var showAlert = false
    
    /// Alert title
    @Published var alertTitle = ""
    
    /// Alert message
    @Published var alertMessage = ""
    
    /// Flag indicating if upload was successful
    @Published var uploadSuccess = false
    
    /// Output for capturing photos
    private let output = AVCapturePhotoOutput()
    
    /// Cancellables for managing Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Supabase service
    private let supabaseService = SupabaseService.shared
    
    /// Initializer
    init() {
        setupCaptureSession()
    }
    
    /// Sets up the camera capture session
    private func setupCaptureSession() {
        // Run session setup on a background thread to avoid blocking the UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // Add video input
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                return
            }
            
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            
            // Add photo output
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            
            self.session.commitConfiguration()
        }
    }
    
    /// Checks camera permission and starts session if authorized
    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.startSession()
                }
            }
        default:
            self.alertTitle = "Camera Access"
            self.alertMessage = "Please enable camera access in Settings to take photos."
            self.showAlert = true
        }
    }
    
    /// Starts the capture session
    private func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    /// Captures a photo
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
    
    /// Retakes the photo (clears the current image)
    func retakePhoto() {
        capturedImage = nil
        startSession()
    }
    
    /// Uploads the captured photo to Supabase
    func uploadPhoto() {
        guard let image = capturedImage else { return }
        
        isUploading = true
        
        supabaseService.uploadImage(image: image, photoDate: Date())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isUploading = false
                
                if case .failure(let error) = completion {
                    self.alertTitle = "Upload Failed"
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                    self.uploadSuccess = false
                }
            }, receiveValue: { [weak self] _ in
                guard let self = self else { return }
                self.alertTitle = "Success"
                self.alertMessage = "Your photo has been uploaded successfully."
                self.showAlert = true
                self.uploadSuccess = true
            })
            .store(in: &cancellables)
    }
}

/// Extension to handle photo capture delegate methods
extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
        
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.capturedImage = image
        }
    }
}

/// SwiftUI wrapper for AVCaptureVideoPreviewLayer
struct CameraPreviewView: UIViewRepresentable {
    /// Capture session to display
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect.zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

#Preview {
    CameraView()
} 