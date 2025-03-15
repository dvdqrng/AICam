//
//  NetworkDebugger.swift
//  AICam
//
//  Created by David Quiring on 15.03.25.
//

import Foundation
import Network
import Combine
import SystemConfiguration
#if os(macOS)
import Foundation
#endif

/// A utility class to debug network connectivity issues
class NetworkDebugger {
    static let shared = NetworkDebugger()
    
    private init() {}
    
    /// Runs a complete diagnosis of network connectivity issues
    /// - Parameter completion: Closure that will be called with the diagnosis results
    func diagnoseNetworkIssues(completion: @escaping ([String]) -> Void) {
        var results = [String]()
        let group = DispatchGroup()
        
        // Basic connectivity test
        group.enter()
        checkInternetConnection { isConnected, description in
            results.append("Internet Connection: \(isConnected ? "Connected" : "Disconnected")")
            if let description = description {
                results.append("  - \(description)")
            }
            group.leave()
        }
        
        // DNS resolution test
        group.enter()
        checkDNSResolution(host: "bidgqmzbwzoeifenmjxm.supabase.co") { isResolvable, ip in
            if isResolvable {
                results.append("DNS Resolution: Success")
                if let ip = ip {
                    results.append("  - Resolved IP: \(ip)")
                }
            } else {
                results.append("DNS Resolution: Failed")
                results.append("  - Could not resolve hostname to IP address")
            }
            group.leave()
        }
        
        // Ping test
        group.enter()
        pingHost(host: "bidgqmzbwzoeifenmjxm.supabase.co") { success, time, error in
            if success {
                results.append("Ping Test: Success")
                if let time = time {
                    results.append("  - Response time: \(time) ms")
                }
            } else {
                results.append("Ping Test: Failed")
                if let error = error {
                    results.append("  - Error: \(error)")
                }
            }
            group.leave()
        }
        
        // HTTP test
        group.enter()
        testHTTPConnection(urlString: "https://bidgqmzbwzoeifenmjxm.supabase.co") { success, statusCode, error in
            if success {
                results.append("HTTP Connection: Success")
                if let statusCode = statusCode {
                    results.append("  - Status code: \(statusCode)")
                }
            } else {
                results.append("HTTP Connection: Failed")
                if let error = error {
                    results.append("  - Error: \(error)")
                }
            }
            group.leave()
        }
        
        // Fallback test
        group.enter()
        testFallbackConnection(urlString: "https://supabase.com") { success, statusCode, error in
            if success {
                results.append("Fallback Connection: Success")
                results.append("  - Able to connect to supabase.com")
            } else {
                results.append("Fallback Connection: Failed")
                results.append("  - Unable to connect to supabase.com either")
                if let error = error {
                    results.append("  - Error: \(error)")
                }
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(results)
        }
    }
    
    /// Checks if the device has an internet connection
    /// - Parameter completion: Closure that will be called with the result
    private func checkInternetConnection(completion: @escaping (Bool, String?) -> Void) {
        // Using NWPathMonitor instead of deprecated SCNetworkReachability APIs
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkDebuggerQueue")
        
        monitor.pathUpdateHandler = { path in
            var isConnected = path.status == .satisfied
            var description: String? = nil
            
            if isConnected {
                if path.usesInterfaceType(.cellular) {
                    description = "Connected via cellular data"
                } else if path.usesInterfaceType(.wifi) {
                    description = "Connected via WiFi"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    description = "Connected via Ethernet"
                } else {
                    description = "Connected via other interface"
                }
            } else {
                switch path.status {
                case .unsatisfied:
                    description = "Network is unsatisfied"
                case .requiresConnection:
                    description = "Network requires connection"
                default:
                    description = "Unknown network status"
                }
            }
            
            monitor.cancel()
            completion(isConnected, description)
        }
        
        monitor.start(queue: queue)
        
        // Set a timeout to prevent hanging
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            monitor.cancel()
            completion(false, "Connection check timed out")
        }
    }
    
    /// Checks if a hostname can be resolved to an IP address
    /// - Parameters:
    ///   - host: The hostname to resolve
    ///   - completion: Closure that will be called with the result
    private func checkDNSResolution(host: String, completion: @escaping (Bool, String?) -> Void) {
        let hostnameLookup = host
        
        DispatchQueue.global().async {
            let host = CFHostCreateWithName(nil, hostnameLookup as CFString).takeRetainedValue()
            CFHostStartInfoResolution(host, .addresses, nil)
            
            var success: DarwinBoolean = false
            if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray? {
                if success.boolValue && addresses.count > 0 {
                    if let address = addresses.firstObject as? NSData {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        let data = address as NSData
                        if getnameinfo(data.bytes.assumingMemoryBound(to: sockaddr.self), socklen_t(data.length),
                                       &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                            let ipAddress = String(cString: hostname)
                            completion(true, ipAddress)
                            return
                        }
                    }
                }
            }
            
            completion(false, nil)
        }
    }
    
    /// Tests if a host can be pinged
    /// - Parameters:
    ///   - host: The hostname to ping
    ///   - completion: Closure that will be called with the result
    private func pingHost(host: String, completion: @escaping (Bool, Double?, String?) -> Void) {
        #if os(macOS)
        let process = Foundation.Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "1", "-t", "5", host]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                if process.isRunning {
                    process.terminate()
                    completion(false, nil, "Ping timed out")
                    return
                }
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                if process.terminationStatus == 0 {
                    // Extract ping time
                    let pattern = "time=([0-9.]+) ms"
                    if let range = output.range(of: pattern, options: .regularExpression) {
                        let timeString = output[range].replacingOccurrences(of: "time=", with: "").replacingOccurrences(of: " ms", with: "")
                        if let pingTime = Double(timeString) {
                            completion(true, pingTime, nil)
                            return
                        }
                    }
                    completion(true, nil, nil)
                } else {
                    completion(false, nil, output)
                }
            }
        } catch {
            completion(false, nil, error.localizedDescription)
        }
        #else
        // For iOS, we can't directly ping, so use an HTTP request as a substitute
        testHTTPConnection(urlString: "https://\(host)") { success, statusCode, error in
            if success {
                completion(true, nil, "HTTP connection successful (ping not available on iOS)")
            } else {
                completion(false, nil, error ?? "Failed to connect (ping not available on iOS)")
            }
        }
        #endif
    }
    
    /// Tests if an HTTP connection can be made to a URL
    /// - Parameters:
    ///   - urlString: The URL to test
    ///   - completion: Closure that will be called with the result
    private func testHTTPConnection(urlString: String, completion: @escaping (Bool, Int?, String?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(false, nil, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(false, nil, error.localizedDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, nil, "Response is not HTTPURLResponse")
                return
            }
            
            completion(true, httpResponse.statusCode, nil)
        }.resume()
    }
    
    /// Tests if a connection can be made to a fallback URL
    /// - Parameters:
    ///   - urlString: The URL to test
    ///   - completion: Closure that will be called with the result
    private func testFallbackConnection(urlString: String, completion: @escaping (Bool, Int?, String?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(false, nil, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(false, nil, error.localizedDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, nil, "Response is not HTTPURLResponse")
                return
            }
            
            completion(true, httpResponse.statusCode, nil)
        }.resume()
    }
    
    /// Test connection using curl command
    /// - Parameters:
    ///   - url: The URL to test
    ///   - completion: Closure that will be called with the result
    func testConnectionWithCurl(url: String, completion: @escaping (Bool, String) -> Void) {
        #if os(macOS)
        let process = Foundation.Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = ["-I", url]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                if process.isRunning {
                    process.terminate()
                    completion(false, "Curl request timed out")
                    return
                }
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                if process.terminationStatus == 0 {
                    completion(true, output)
                } else {
                    completion(false, output)
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
        #else
        // For iOS, use a URLSession request instead
        guard let url = URL(string: url) else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(false, "Error: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Response is not HTTPURLResponse")
                return
            }
            
            var output = "HTTP/1.1 \(httpResponse.statusCode)\n"
            httpResponse.allHeaderFields.forEach { key, value in
                output += "\(key): \(value)\n"
            }
            
            completion(true, output)
        }.resume()
        #endif
    }
    
    /// Test connection with nslookup
    /// - Parameters:
    ///   - host: The hostname to lookup
    ///   - completion: Closure that will be called with the result
    func testWithNSLookup(host: String, completion: @escaping (Bool, String) -> Void) {
        #if os(macOS)
        let process = Foundation.Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nslookup")
        process.arguments = [host]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                if process.isRunning {
                    process.terminate()
                    completion(false, "NSLookup timed out")
                    return
                }
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                if process.terminationStatus == 0 && !output.contains("can't find") {
                    completion(true, output)
                } else {
                    completion(false, output)
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
        #else
        // For iOS, use CFHost for DNS lookup
        DispatchQueue.global().async {
            let host = CFHostCreateWithName(nil, host as CFString).takeRetainedValue()
            CFHostStartInfoResolution(host, .addresses, nil)
            
            var success: DarwinBoolean = false
            if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray? {
                if success.boolValue && addresses.count > 0 {
                    var output = "Name:    \(host)\n"
                    output += "Addresses: \n"
                    
                    for case let address as NSData in addresses {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(address.bytes.assumingMemoryBound(to: sockaddr.self), socklen_t(address.length),
                                   &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                            let ipAddress = String(cString: hostname)
                            output += "\(ipAddress)\n"
                        }
                    }
                    
                    completion(true, output)
                    return
                }
            }
            
            completion(false, "Could not resolve hostname")
        }
        #endif
    }
    
    /// Validates a JWT token format
    /// - Parameter token: The token to validate
    /// - Returns: A boolean indicating if the token is valid and a description of any issues
    func validateJWTToken(token: String) -> (isValid: Bool, description: String) {
        let components = token.components(separatedBy: ".")
        
        // Check if the token has three parts: header, payload, signature
        guard components.count == 3 else {
            return (false, "Invalid JWT format: should have 3 components separated by dots")
        }
        
        // Check if each part can be base64 decoded
        for (index, component) in components.enumerated() {
            let paddedComponent = component.padding(toLength: ((component.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
            let name = index == 0 ? "Header" : (index == 1 ? "Payload" : "Signature")
            
            guard let _ = Data(base64Encoded: paddedComponent) else {
                return (false, "\(name) is not valid base64")
            }
        }
        
        return (true, "JWT format appears valid")
    }
    
    /// Validates the Supabase API key
    /// - Returns: A dictionary with validation results
    func validateSupabaseAPIKey() -> [String: String] {
        var results = [String: String]()
        
        let apiKey = SupabaseService.shared.supabaseKey
        let (isValid, description) = validateJWTToken(token: apiKey)
        
        results["Format Valid"] = isValid ? "Yes" : "No"
        results["Format Details"] = description
        
        // Check if the key contains expected Supabase project ref
        if let data = Data(base64Encoded: apiKey.components(separatedBy: ".")[1].padding(toLength: ((apiKey.components(separatedBy: ".")[1].count + 3) / 4) * 4, withPad: "=", startingAt: 0)),
           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let ref = json["ref"] as? String {
            
            results["Project Ref"] = ref
            
            let expectedRef = "bidgqmzbwzoeifenmjxm"
            if ref == expectedRef {
                results["Project Match"] = "Yes - Matches expected project reference"
            } else {
                results["Project Match"] = "No - Expected '\(expectedRef)' but found '\(ref)'"
            }
        } else {
            results["Project Ref"] = "Unable to extract project reference from token"
        }
        
        // Check token expiration
        if let data = Data(base64Encoded: apiKey.components(separatedBy: ".")[1].padding(toLength: ((apiKey.components(separatedBy: ".")[1].count + 3) / 4) * 4, withPad: "=", startingAt: 0)),
           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let exp = json["exp"] as? TimeInterval {
            
            let expirationDate = Date(timeIntervalSince1970: exp)
            let now = Date()
            
            if expirationDate > now {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                let relativeDate = formatter.localizedString(for: expirationDate, relativeTo: now)
                results["Expiration"] = "Valid - Expires \(relativeDate)"
            } else {
                results["Expiration"] = "Invalid - Token expired on \(expirationDate)"
            }
        } else {
            results["Expiration"] = "Unable to extract expiration from token"
        }
        
        return results
    }
} 