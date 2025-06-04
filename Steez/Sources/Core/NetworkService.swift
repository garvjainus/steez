import Foundation
import UIKit
import Alamofire
import Kingfisher
import CommonCrypto

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
class NetworkService {
    static let shared = NetworkService()
    
    // Backend server configuration
    #if targetEnvironment(simulator)
    // Use localhost for simulator
    private let baseURL = "http://localhost:3000"
    #else   
    // Use Mac's actual IP address when testing on a physical device
    private let baseURL = "http://10.10.11.201:3000"
    #endif
    
    // Cache configuration
    private let cache = NSCache<NSString, NSData>()
    private let cacheTTL: TimeInterval = 3600 * 24 // 24 hours
    private let diskCacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("SteezImageCache")
    
    // Retry configuration
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0 // Initial delay in seconds
    
    private init() {
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
        
        // Set up Kingfisher cache for images
        let cache = ImageCache.default
        cache.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024 // 100 MB memory cache
        cache.diskStorage.config.sizeLimit = 500 * 1024 * 1024 // 500 MB disk cache
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
        
        AF.request(urlRequest)
            .validate(statusCode: 200..<300)
            .responseData { response in
                switch response.result {
                case .success(let data):
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
                    
                case .failure(let error):
                    // Handle error with retry logic
                    if retryCount < self.maxRetries {
                        // Exponential backoff
                        let delay = self.retryDelay * pow(2.0, Double(retryCount))
                        
                        // Check if the error is retriable
                        if self.isRetriableError(error, statusCode: response.response?.statusCode) {
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
                    
                    // Parse error type
                    if let statusCode = response.response?.statusCode, statusCode >= 400 {
                        let errorMessage = self.parseErrorMessage(from: response.data) ?? "Unknown server error"
                        completion(.failure(.backendError(statusCode, errorMessage)))
                    } else {
                        completion(.failure(.requestFailed(error)))
                    }
                }
            }
    }
    
    private func isRetriableError(_ error: AFError, statusCode: Int?) -> Bool {
        // Network errors are generally retriable
        if case .sessionTaskFailed = error {
            // NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, etc.
            return true
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
            let fileURL = diskCacheURL.appendingPathComponent(cacheKey.md5Hash)
            try data.write(to: fileURL)
            
            // Store expiration time
            let expirationTime = Date().addingTimeInterval(cacheTTL)
            UserDefaults.standard.set(expirationTime.timeIntervalSince1970, forKey: "cache_expiry_\(cacheKey.md5Hash)")
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
        let fileURL = diskCacheURL.appendingPathComponent(cacheKey.md5Hash)
        
        // Check if cached data is expired (fixing the optional binding issue)
        if let expiryTimeDouble = UserDefaults.standard.object(forKey: "cache_expiry_\(cacheKey.md5Hash)") as? Double,
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
        
        // Clear image cache
        ImageCache.default.clearMemoryCache()
        ImageCache.default.clearDiskCache()
    }
    
    // MARK: - Backend Image Processing (Upload to Your Backend)
    // MODIFIED to use multipart form-data to get filename back
    func processImage(_ image: UIImage, userId: String, completion: @escaping (Result<ImageUploadResponse, NetworkError>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(.invalidData))
            return
        }

        guard let url = URL(string: "\(baseURL)/upload/image") else { // MODIFIED Endpoint
            completion(.failure(.invalidURL))
            return
        }

        AF.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(imageData, withName: "image", fileName: "photo.jpg", mimeType: "image/jpeg")
                multipartFormData.append(Data(userId.utf8), withName: "userId")
            },
            to: url,
            method: .post
        )
        .uploadProgress { progress in
            self.notifyUploadProgress(Float(progress.fractionCompleted))
        }
        .validate() // Basic validation for 2xx status codes
        .responseDecodable(of: ImageUploadResponse.self, decoder: createDecoder()) { response in
            DispatchQueue.main.async {
                print("ION عمليه Image submission response (multipart): \(response.debugDescription)")
                switch response.result {
                case .success(let uploadResponse):
                    if uploadResponse.success {
                        print("✅ Image uploaded successfully (multipart). Message: \(uploadResponse.message)")
                        completion(.success(uploadResponse))
                    } else {
                        print("❌ Image upload (multipart) reported as not successful by backend: \(uploadResponse.message)")
                        completion(.failure(.responseError(uploadResponse.message)))
                    }
                case .failure(let afError):
                    let backendError = self.handleAfError(afError, from: response.data, response: response.response)
                    completion(.failure(backendError))
                }
            }
        }
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
        let parameters = ["filename": filename]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        } catch {
            print("❌ Failed to serialize request: \(error)")
            completion(Result<[LensProduct], NetworkError>.failure(.invalidData)); return
        }

        AF.request(request)
            .validate() // Basic validation for 2xx status codes
            .responseData { response in
                DispatchQueue.main.async {
                    switch response.result {
                    case .success(let data):
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
                    case .failure(let afError):
                        print("❌ Google Lens API request failed: \(afError)")
                        if let data = response.data, let errorStr = String(data: data, encoding: .utf8) {
                            print("❌ Error response: \(errorStr)")
                        }
                        let backendError = self.handleAfError(afError, from: response.data, response: response.response)
                        completion(.failure(backendError))
                    }
                }
            }
    }
    
    // MARK: - Health Check
    
    /// Performs a direct health check to the backend
    /// - Parameter completion: Completion handler with success/failure and a detailed message
    func performHealthCheck(completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: "\(baseURL)/health") else {
            completion(false, "Invalid backend URL configuration")
            return
        }
        
        AF.request(url)
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
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
                    
                case .failure(let error):
                    let detailedError = """
                    Connection failed: \(error.localizedDescription)
                    - URL attempted: \(url)
                    - Make sure:
                      1. Backend server is running
                      2. You're using the simulator (localhost only works in simulator)
                    """
                    completion(false, detailedError)
                }
            }
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
    
    // Helper for AFError processing
    private func handleAfError(_ afError: AFError, from data: Data?, response httpResponse: HTTPURLResponse?) -> NetworkError {
        if let data = data,
           let jsonError = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = jsonError["message"] as? String {
            return .responseError(message)
        } else if let statusCode = httpResponse?.statusCode {
            return .backendError(statusCode, afError.localizedDescription)
        } else {
            return .requestFailed(afError)
        }
    }
    
    private func createDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }
}

// MARK: - String extension for MD5 hash

extension String {
    var md5Hash: String {
        let data = Data(self.utf8)
        let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &hash)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
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
