//
//  NetworkMonitor.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import Foundation
import Network
import Combine

/// A class that monitors network connectivity and publishes status changes
class NetworkMonitor: ObservableObject {
    /// Shared instance of the network monitor
    static let shared = NetworkMonitor()
    
    /// Whether the device is connected to the internet
    @Published var isConnected = true
    
    /// Whether the server is reachable
    @Published var isServerReachable = true
    
    /// The current connection type
    @Published var connectionType = ConnectionType.unknown
    
    /// The current error message if any
    @Published var errorMessage: String?
    
    /// Types of network connections
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    /// The path monitor that detects network changes
    private let pathMonitor = NWPathMonitor()
    
    /// Reachability check timer
    private var reachabilityTimer: Timer?
    
    private init() {
        // Set up the path monitor
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.updateConnectionType(path)
                
                if path.status == .satisfied {
                    // Check server reachability when connected
                    self?.checkServerReachability()
                } else {
                    self?.isServerReachable = false
                    self?.errorMessage = "No internet connection. Please check your network settings."
                }
            }
        }
        
        // Start monitoring on a background queue
        let queue = DispatchQueue(label: "NetworkMonitor")
        pathMonitor.start(queue: queue)
        
        // Start the reachability timer
        startReachabilityTimer()
    }
    
    deinit {
        pathMonitor.cancel()
        stopReachabilityTimer()
    }
    
    /// Updates the connection type based on the path
    /// - Parameter path: The network path
    private func updateConnectionType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
    }
    
    /// Starts the timer that periodically checks server reachability
    private func startReachabilityTimer() {
        reachabilityTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkServerReachability()
        }
    }
    
    /// Stops the reachability timer
    private func stopReachabilityTimer() {
        reachabilityTimer?.invalidate()
        reachabilityTimer = nil
    }
    
    /// Checks whether the Supabase server is reachable
    func checkServerReachability() {
        guard isConnected else {
            DispatchQueue.main.async {
                self.isServerReachable = false
                self.errorMessage = "No internet connection. Please check your network settings."
            }
            return
        }
        
        SupabaseService.shared.checkServerReachability { [weak self] isReachable, errorMessage in
            DispatchQueue.main.async {
                self?.isServerReachable = isReachable
                self?.errorMessage = errorMessage
            }
        }
    }
    
    /// Manually triggers a network check
    func checkConnectivity() {
        checkServerReachability()
    }
} 