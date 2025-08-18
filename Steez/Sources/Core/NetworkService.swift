import Foundation
import UIKit
// import Alamofire // Temporarily commented out
// import Kingfisher // Temporarily commented out
import CryptoKit

// MARK: - Error Handling Enum
enum NetworkError: Error {
    case invalidURL
    case invalidData
    case requestFailed(Error)
    case decodingFailed(Error)
    case noClothingDetected // This might be less relevant now but kept for structure
    case apiKeyMissing
    case responseError(String)
    case maxRetriesExceeded
    case backendError(Int, String)
    case userCancelled
}

// MARK: - Data Structures for Network Responses

// For your backend's /upload/image endpoint
struct ImageUploadResponse: Decodable {
    let success: Bool
    let message: String
    let data: UploadResponseData
}

struct UploadResponseData: Decodable {
    let userId: String?
    let imageSize: Int? 
    let uploadedAt: String?
    let filename: String?      
    let originalName: String?  
    let size: Int?
    let imageUrl: URL?
    let products: [LensProduct]?
    let segmentedResults: SegmentedResults?
}

// New data structures for segmented clothing analysis
struct SegmentedResults: Decodable {
    let segments: [ClothingSegment]
    let totalItems: Int
}

struct ClothingSegment: Decodable, Identifiable {
    let id = UUID()
    let itemType: String
    let phrase: String
    let confidence: Double
    let category: String
    let ebayResults: [EbayMatch]
    
    enum CodingKeys: String, CodingKey {
        case itemType, phrase, confidence, category, ebayResults
    }
}

// For checking the status of a job from the /jobs/:id endpoint
struct JobStatusResponse: Decodable {
    let job_id: String
    let status: JobStatus
    let selected_frame_urls: [URL]?
    let error_message: String?
}

enum JobStatus: String, Decodable {
    case PENDING
    case PROCESSING
    case SELECTING_FRAMES
    case COMPLETE
    case FAILED
}

struct EbayMatch: Decodable, Identifiable {
    let id = UUID()
    let phrase: String
    let link: URL
    
    enum CodingKeys: String, CodingKey {
        case phrase, link
    }
}

// For results from your backend's /google-lens/analyze endpoint
struct LensProduct: Decodable, Identifiable { // ENSURE THIS IS THE ONLY DEFINITION
    let id = UUID()
    let title: String
    let link: URL 
    let source: String
    let price: String? 
    let extractedPrice: Double? 
    let currency: String?
    let thumbnailUrl: URL?
    let filename: String?
    let imageUrl: URL?
    let category: String?

    enum CodingKeys: String, CodingKey {
        case title, link, source, price, extractedPrice, currency, thumbnailUrl, filename, imageUrl, category
    }
}

// MARK: - Network Service Class
class NetworkService: NSObject {
    static let shared = NetworkService()
    
    private let baseURL: String
    private let apiToken: String?
    
    // Dedicated session to report upload progress via delegate callbacks
    private lazy var uploadSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    // Cache configuration
    private let cache = NSCache<NSString, NSData>()
    private let cacheTTL: TimeInterval = 3600 * 24 // 24 hours
    private let diskCacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("SteezImageCache")
    
    // Retry configuration
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0 // Initial delay in seconds
    
    private override init() {
        guard let baseURLString = ProcessInfo.processInfo.environment["API_BASE_URL"] else {
            fatalError("API_BASE_URL environment variable not set. Please set it in your Xcode scheme.")
        }
        let rawURL = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        self.baseURL = rawURL
        // Load API token (prefer environment for your Scheme-based workflow; fallback to Info.plist)
        if let envToken = ProcessInfo.processInfo.environment["API_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines), !envToken.isEmpty {
            self.apiToken = envToken
        } else if let plistToken = Bundle.main.object(forInfoDictionaryKey: "API_TOKEN") as? String, !plistToken.isEmpty {
            self.apiToken = plistToken
        } else {
            self.apiToken = nil
            print("⚠️ API_TOKEN not found in environment or Info.plist. Guarded endpoints will fail without 'x-api-key'.")
        }
        super.init()
        setupCache()
        
        // Print the base URL for debugging
        print("🔗 Using API base URL: \(baseURL)")
        print("⚠️ Note: localhost only works in simulator or on the same device as the server")
    }
    
    private func setupCache() {
        // Set up cache limits
        cache.countLimit = 100 // Max number of items
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        
        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // Set up image cache (Kingfisher temporarily disabled)
        // let cache = ImageCache.default
        // cache.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024 // 100 MB memory cache
        // cache.diskStorage.config.sizeLimit = 500 * 1024 * 1024 // 500 MB disk cache
    }
    
    // MARK: - Server Availability
    
    /// Checks if the backend server is available
    /// - Parameter completion: Called with true if server is available, false otherwise
    func checkServerAvailability(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/health") else {
            print("❌ Invalid URL for health check")
            completion(false)
            return
        }
        
        print("🔍 Checking server availability from \(baseURL)")
        print("🔗 Connecting to: \(url.absoluteString)")
        
        // Simple ping to check if server is reachable
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("✅ Backend server response: \(responseString)")
                    }
                    print("✅ Backend server is available at \(url.absoluteString)")
                    completion(true)
                } else {
                    print("❌ Backend server is not available: \(error?.localizedDescription ?? "Unknown error")")
                    print("⚠️ Make sure your backend is running with 'npm run start:dev' in the steez-backend directory")
                    print("⚠️ Using localhost (\(self.baseURL)) - this will only work in the simulator")
                    print("⚠️ For physical devices, you'll need to use your actual network IP instead of localhost")
                    
                    if let error = error as? URLError, error.code == .cannotConnectToHost {
                        print("📱 Connection details: Device: \(self.baseURL)")
                    }
                    completion(false)
                }
            }
        }
        task.resume()
    }
    
    // MARK: - Error Handling
    
    /// Provides a user-friendly message for network errors
    /// - Parameter error: The network error
    /// - Returns: A user-friendly error message
    func userFriendlyErrorMessage(for error: NetworkError) -> String {
        switch error {
        case .requestFailed(let underlyingError):
            if let urlError = underlyingError as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    return "You're not connected to the internet. Please check your connection and try again."
                case .timedOut:
                    return "The connection timed out. Please try again later."
                case .cannotConnectToHost:
                    return "Cannot connect to the server. Please make sure the backend server is running."
                default:
                    return "Network error: \(urlError.localizedDescription)"
                }
            }
            return "Failed to connect: \(underlyingError.localizedDescription)"
            
        case .invalidURL:
            return "Invalid URL configuration."
            
        case .invalidData:
            return "The data received was invalid."
            
        case .decodingFailed:
            return "Failed to decode the server response."
            
        case .noClothingDetected:
            return "No clothing items were detected in the image."
            
        case .apiKeyMissing:
            return "API key is missing. Please check your configuration."
            
        case .responseError(let message):
            return "Server error: \(message)"
            
        case .maxRetriesExceeded:
            return "The request failed after multiple attempts."
            
        case .backendError(let code, let message):
            return "Server error (\(code)): \(message)"
            
        case .userCancelled:
            return "Operation cancelled by user."
        }
    }
    
    // MARK: - Request Handling with Retry
    
    private func performRequestWithRetry<T: Codable>(
        urlRequest: URLRequest,
        retryCount: Int = 0,
        completion: @escaping (Result<T, NetworkError>) -> Void
    ) {
        // Check cache first using proper type handling
        if let cachedData: T = getCachedResponse(for: urlRequest) {
            completion(.success(cachedData))
            return
        }
        
        // --- DETAILED LOGGING ---
        print("--- NetworkService Request ---")
        print("URL: \(urlRequest.url?.absoluteString ?? "N/A")")
        print("Method: \(urlRequest.httpMethod ?? "N/A")")
        print("Headers: \(urlRequest.allHTTPHeaderFields ?? [:])")
        if let body = urlRequest.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("Body: \(bodyString)")
        }
        // --- END LOGGING ---
        
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    // --- DETAILED LOGGING ---
                    print("--- NetworkService Error ---")
                    print("Error: \(error.localizedDescription)")
                    // --- END LOGGING ---
                    
                    // Handle error with retry logic
                    if retryCount < self.maxRetries {
                        // Exponential backoff
                        let delay = self.retryDelay * pow(2.0, Double(retryCount))
                        
                        // Check if the error is retriable
                        if self.isRetriableError(error, statusCode: (response as? HTTPURLResponse)?.statusCode) {
                            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                                self.performRequestWithRetry(
                                    urlRequest: urlRequest,
                                    retryCount: retryCount + 1,
                                    completion: completion
                                )
                            }
                            return
                        }
                    }
                    
                    completion(.failure(.requestFailed(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidData))
                    return
                }
                
                // --- DETAILED LOGGING ---
                print("--- NetworkService Response ---")
                print("Status Code: \(httpResponse.statusCode)")
                print("Headers: \(httpResponse.allHeaderFields)")
                if let data = data, let bodyString = String(data: data, encoding: .utf8) {
                    print("Body: \(bodyString)")
                }
                // --- END LOGGING ---
                
                guard 200..<300 ~= httpResponse.statusCode else {
                    let errorMessage = self.parseErrorMessage(from: data) ?? "Unknown server error"
                    completion(.failure(.backendError(httpResponse.statusCode, errorMessage)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.invalidData))
                    return
                }
                
                do {
                    // Explicitly decode to type T
                    let decodedData = try JSONDecoder().decode(T.self, from: data)
                    // Cache successful response
                    self.cacheResponse(decodedData, for: urlRequest)
                    completion(.success(decodedData))
                } catch let decodingError {
                    print("Decoding error: \(decodingError). JSON: \(String(data: data, encoding: .utf8) ?? "unknown")")
                    completion(.failure(.decodingFailed(decodingError)))
                }
            }
        }.resume()
    }
    
    private func isRetriableError(_ error: Error, statusCode: Int?) -> Bool {
        // Network errors are generally retriable
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet:
            return true
            default:
                return false
            }
        }
        
        // Server errors (5xx) are retriable
        if let statusCode = statusCode, statusCode >= 500 {
            return true
        }
        
        // Most 4xx errors are not retriable (client errors)
        // Except for 429 (too many requests)
        if let statusCode = statusCode, statusCode == 429 {
            return true
        }
        
        return false
    }
    
    private func parseErrorMessage(from data: Data?) -> String? {
        guard let data = data else { return nil }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                return message
            }
        } catch {
            print("Error parsing error message: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Cache Management
    
    private func cacheResponse<T: Encodable>(_ response: T, for request: URLRequest) {
        do {
            let data = try JSONEncoder().encode(response)
            
            // Create cache key from request
            let cacheKey = request.url?.absoluteString ?? UUID().uuidString
            
            // Memory cache
            cache.setObject(data as NSData, forKey: cacheKey as NSString)
            
            // Disk cache
            let fileURL = diskCacheURL.appendingPathComponent(cacheKey.sha256Hex)
            try data.write(to: fileURL)
            
            // Store expiration time
            let expirationTime = Date().addingTimeInterval(cacheTTL)
            UserDefaults.standard.set(expirationTime.timeIntervalSince1970, forKey: "cache_expiry_\(cacheKey.sha256Hex)")
        } catch {
            print("Failed to cache response: \(error)")
        }
    }
    
    private func getCachedResponse<T: Decodable>(for request: URLRequest) -> T? {
        // Create cache key from request
        let cacheKey = request.url?.absoluteString ?? ""
        
        // Check memory cache first
        if let cachedData = cache.object(forKey: cacheKey as NSString) {
            do {
                return try JSONDecoder().decode(T.self, from: cachedData as Data)
            } catch {
                print("Failed to decode cached data: \(error)")
            }
        }
        
        // Check disk cache
        let fileURL = diskCacheURL.appendingPathComponent(cacheKey.sha256Hex)
        
        // Check if cached data is expired (fixing the optional binding issue)
        if let expiryTimeDouble = UserDefaults.standard.object(forKey: "cache_expiry_\(cacheKey.sha256Hex)") as? Double,
           Date(timeIntervalSince1970: expiryTimeDouble) > Date() {
            
            do {
                let data = try Data(contentsOf: fileURL)
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                print("Failed to load cached data from disk: \(error)")
            }
        }
        
        return nil
    }
    
    func clearCache() {
        // Clear memory cache
        cache.removeAllObjects()
        
        // Clear disk cache
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // Clear image cache (Kingfisher temporarily disabled)
        // ImageCache.default.clearMemoryCache()
        // ImageCache.default.clearDiskCache()
    }
    
    // MARK: - Backend Image Processing (Upload to Your Backend)
    // MODIFIED to use multipart form-data to get filename back
    func processImage(_ image: UIImage, userId: String, userSize: String? = nil, userCountry: String? = nil, completion: @escaping (Result<ImageUploadResponse, NetworkError>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(.invalidData))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/upload/image") else {
            completion(.failure(.invalidURL))
            return
        }
        
        // Create multipart form data manually
        let boundary = UUID().uuidString
        var body = Data()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add userId
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"userId\"\r\n\r\n".data(using: .utf8)!)
        body.append(Data(userId.utf8))
        body.append("\r\n".data(using: .utf8)!)
        
        // Add user size if provided
        if let userSize = userSize {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"userSize\"\r\n\r\n".data(using: .utf8)!)
            body.append(Data(userSize.utf8))
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Add user country if provided
        if let userCountry = userCountry {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"userCountry\"\r\n\r\n".data(using: .utf8)!)
            body.append(Data(userCountry.utf8))
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = apiToken {
            request.setValue(token, forHTTPHeaderField: "x-api-key")
            // Hint servers to validate headers before body is sent
            request.setValue("100-continue", forHTTPHeaderField: "Expect")
        }
        
        // Use uploadTask so we get progress callbacks via delegate
        let task = uploadSession.uploadTask(with: request, from: body) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.requestFailed(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidData))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.invalidData))
                    return
                }
                
                do {
                    let uploadResponse = try self.createDecoder().decode(ImageUploadResponse.self, from: data)
                    if uploadResponse.success {
                        print("✅ Image uploaded successfully. Message: \(uploadResponse.message)")
                        completion(.success(uploadResponse))
                    } else {
                        print("❌ Image upload reported as not successful by backend: \(uploadResponse.message)")
                        completion(.failure(.responseError(uploadResponse.message)))
                    }
                } catch {
                    print("❌ Error decoding upload response: \(error)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Response: \(responseString)")
                    }
                    completion(.failure(.decodingFailed(error)))
                    }
                }
        }
        task.resume()
    }
    
    // MARK: - Google Lens Image Analysis (via Your Backend)

    func analyzeImageWithLens(filename: String, completion: @escaping (Result<[LensProduct], NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/google-lens/analyze") else {
            completion(Result<[LensProduct], NetworkError>.failure(.invalidURL)); return
        }
        
        print("🔍 Analyzing image with Google Lens: \(filename)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = apiToken {
            request.setValue(token, forHTTPHeaderField: "x-api-key")
        }
        let parameters = ["filename": filename]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        } catch {
            print("❌ Failed to serialize request: \(error)")
            completion(Result<[LensProduct], NetworkError>.failure(.invalidData)); return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                if let error = error {
                    print("❌ Google Lens API request failed: \(error)")
                    completion(.failure(.requestFailed(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidData))
                    return
                }
                
                guard 200..<300 ~= httpResponse.statusCode else {
                    let errorMessage = self.parseErrorMessage(from: data) ?? "Unknown server error"
                    completion(.failure(.backendError(httpResponse.statusCode, errorMessage)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.invalidData))
                    return
                }
                
                    do {
                            // First try to print the raw JSON for debugging
                            if let jsonString = String(data: data, encoding: .utf8) {
                                print("✅ Google Lens response JSON: \(jsonString)")
                            }
                            
                            let products = try self.createDecoder().decode([LensProduct].self, from: data)
                            print("✅ Successfully fetched \(products.count) lens products from backend")
                            completion(.success(products))
                        } catch let error {
                            print("❌ Error decoding lens products: \(error)")
                        completion(.failure(.decodingFailed(error)))
                    }
            }
        }.resume()
    }
    
    // MARK: - Health Check
    
    /// Performs a direct health check to the backend
    /// - Parameter completion: Completion handler with success/failure and a detailed message
    func performHealthCheck(completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: "\(baseURL)/health") else {
            completion(false, "Invalid backend URL configuration")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    let detailedError = """
                    Connection failed: \(error.localizedDescription)
                    - URL attempted: \(url)
                    - Make sure:
                      1. Backend server is running
                      2. You're using the simulator (localhost only works in simulator)
                    """
                    completion(false, detailedError)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      200..<300 ~= httpResponse.statusCode else {
                    completion(false, "Server responded with error status")
                    return
                }
                
                guard let data = data else {
                    completion(false, "No data received from server")
                    return
                }
                
                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let status = json["status"] as? String,
                       status == "ok" {
                        
                        // Get additional info for debugging
                        let timestamp = json["timestamp"] as? String ?? "unknown"
                        let service = json["service"] as? String ?? "unknown"
                        
                        let message = "Connected successfully to \(service) at \(timestamp)"
                        completion(true, message)
                    } else {
                        completion(false, "Server responded but with unexpected format")
                    }
            }
        }.resume()
    }
    
    // MARK: - Network Diagnostics
    
    /// Get detailed network diagnostic information
    /// - Returns: A diagnostic string with network information
    func getNetworkDiagnostics() -> String {
        let backendUrl = baseURL
        
        var diagnostics = """
        Network Diagnostics:
        - Backend URL: \(backendUrl)
        """
        
        return diagnostics
    }
    
    // MARK: - Job Status Polling
    
    func getJobStatus(jobId: String, completion: @escaping (Result<JobStatusResponse, NetworkError>) -> Void) {
        let urlString = "\(baseURL)/jobs/\(jobId)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = apiToken, !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "x-api-key")
        } else {
            print("⚠️ API_TOKEN missing; GET /jobs/:id will fail auth")
        }
        
        // This task does not need retry logic, as it will be called repeatedly by the poller.
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.requestFailed(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                    let errorMessage = self.parseErrorMessage(from: data) ?? "Failed to get job status"
                    completion(.failure(.backendError((response as? HTTPURLResponse)?.statusCode ?? 500, errorMessage)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.invalidData))
                    return
                }
                
                do {
                    let jobStatus = try self.createDecoder().decode(JobStatusResponse.self, from: data)
                    completion(.success(jobStatus))
                } catch {
                    completion(.failure(.decodingFailed(error)))
                }
            }
        }.resume()
    }
    
    // MARK: - Image & Video Processing

    // Helper for error processing (replaced AFError handling)
    private func handleNetworkError(_ error: Error, from data: Data?, response httpResponse: HTTPURLResponse?) -> NetworkError {
        if let data = data,
           let jsonError = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = jsonError["message"] as? String {
            return .responseError(message)
        } else if let statusCode = httpResponse?.statusCode {
            return .backendError(statusCode, error.localizedDescription)
        } else {
            return .requestFailed(error)
        }
    }
    
    private func createDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }
}

// MARK: - String extension for SHA256 hash (for cache keys)

extension String {
    var sha256Hex: String {
        let data = Data(utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// Helper model for backend responses
struct BackendResponse<T: Decodable>: Decodable {
    let status: String
    let data: T?
    let message: String?
}

// MARK: - NetworkService Extensions

extension NetworkService {
    // Helper method to broadcast upload progress
    private func notifyUploadProgress(_ progress: Float) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .uploadProgressNotification,
                object: nil,
                userInfo: ["progress": progress]
            )
        }
    }
}

extension Notification.Name {
    static let uploadProgressNotification = Notification.Name("uploadProgressNotification")
} 
 
 // MARK: - URLSessionTaskDelegate for upload progress
 extension NetworkService: URLSessionTaskDelegate {
     func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
         guard session == uploadSession, totalBytesExpectedToSend > 0 else { return }
         let progress = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
         notifyUploadProgress(min(max(progress, 0), 1))
     }
 }
