import UIKit
import UniformTypeIdentifiers

// MARK: - String Helper
extension String {
    /// Returns a copy of the string with leading and trailing whitespace and newline characters removed.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

class ShareViewController: UIViewController {

    // MARK: - Constants

    // Read the API URL, preferring Scheme environment, then Info.plist.
    private var apiBaseURLString: String {
        if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"], !envURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return envURL
        }
        guard let url = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String, !url.isEmpty else {
            fatalError("API_BASE_URL key not found or is empty for the Share Extension. Set it in the Run Scheme environment or Info.plist.")
        }
        return url
    }

    // Read the API Token, preferring Scheme environment, then Info.plist.
    private var apiTokenString: String {
        if let envToken = ProcessInfo.processInfo.environment["API_TOKEN"], !envToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return envToken
        }
        guard let token = Bundle.main.object(forInfoDictionaryKey: "API_TOKEN") as? String, !token.isEmpty else {
            fatalError("API_TOKEN not found or is empty for the Share Extension. Set it in the Run Scheme environment or Info.plist.")
        }
        return token
    }

    private let appGroupId = "group.com.steez.app"
    private let latestJobIdKey = "latest_job_id"

    // MARK: - UI Elements
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()

    // MARK: - Initializers
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        print("--- Share Extension Log: init(coder:) ---")
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        print("--- Share Extension Log: init(nibName:bundle:) ---")
    }

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        print("--- Share Extension Log: viewDidLoad() - START ---")
        super.viewDidLoad()
        setupUI()
        print("--- Share Extension Log: viewDidLoad() - setupUI() FINISHED ---")
        handleSharedItem()
        print("--- Share Extension Log: viewDidLoad() - handleSharedItem() CALLED ---")
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Configure activity indicator
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)

        // Configure status label
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 16)
        statusLabel.textColor = .label
        statusLabel.text = "Processing Video..."
        view.addSubview(statusLabel)

        // Layout constraints
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),

            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        activityIndicator.startAnimating()
    }

    // MARK: - Core Logic
    private func handleSharedItem() {
        print("--- Share Extension: handleSharedItem called ---")
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = extensionItem.attachments?.first else {
            print("Error: No item found in extension context.")
            completeRequest(errorMessage: "No item found.")
            return
        }
        
        print("Item Provider: \(provider)")
        print("Registered Type Identifiers: \(provider.registeredTypeIdentifiers)")

        // 1️⃣ Try for an explicit URL
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            print("Item conforms to URL type. Loading item...")
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
                print("Loaded item for URL type: \(String(describing: item))")
                self?.guardAndProcess(item)
            }
            return
        }

        // 2️⃣ Fallback: plain text that might contain a URL
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            print("Item conforms to Plain Text type. Loading item...")
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, _ in
                print("Loaded item for Plain Text type: \(String(describing: item))")
                self?.guardAndProcess(item)
            }
            return
        }

        print("Error: Unsupported share type. Identifiers: \(provider.registeredTypeIdentifiers)")
        completeRequest(errorMessage: "Unsupported share type.")
    }

    private func guardAndProcess(_ item: NSSecureCoding?) {
        print("--- Share Extension: guardAndProcess called with item: \(String(describing: item)) ---")
        if let url = item as? URL {
            print("Successfully processed as URL: \(url.absoluteString)")
            processVideo(with: url)
        } else if let text = item as? String, let url = URL(string: text.trimmed) {
            print("Successfully processed as String and converted to URL: \(url.absoluteString)")
            processVideo(with: url)
        } else {
            print("Error: Could not extract URL from item.")
            completeRequest(errorMessage: "Could not extract URL.")
        }
    }

    private func processVideo(with url: URL) {
        // 1. Construct the correct URL for our backend endpoint.
        guard let requestURL = URL(string: "\(apiBaseURLString)/video-processing/process-video") else {
            completeRequest(errorMessage: "Invalid backend URL.")
            return
        }

        // 2. Prepare the HTTP request.
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiTokenString, forHTTPHeaderField: "x-api-key")

        // 3. Create the payload with all required fields.
        let payload: [String: Any] = [
            "user_id": getCurrentUserId(), // Placeholder for the actual user ID
            "video_url": url.absoluteString,
            "frame_rate": 2 // Default frame rate
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completeRequest(errorMessage: "Failed to create request body.")
            return
        }

        // 4. Send the request to the backend.
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Ensure we can handle the response.
            guard let self = self else { return }
            
            // --- DETAILED LOGGING ---
            print("--- Share Extension Request ---")
            print("URL: \(request.url?.absoluteString ?? "N/A")")
            print("Method: \(request.httpMethod ?? "N/A")")
            print("Headers: \(request.allHTTPHeaderFields ?? [:])")
            if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
                print("Body: \(bodyString)")
            }
            
            if let error = error {
                print("Error: \(error.localizedDescription)")
                self.completeRequest(errorMessage: "Network request failed: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Response is not an HTTPURLResponse.")
                self.completeRequest(errorMessage: "Invalid response from server.")
                return
            }

            print("--- Share Extension Response ---")
            print("Status Code: \(httpResponse.statusCode)")
            print("Headers: \(httpResponse.allHeaderFields)")

            guard (200...299).contains(httpResponse.statusCode) else {
                if let data = data, let errorBody = String(data: data, encoding: .utf8) {
                    print("Error Body: \(errorBody)")
                }
                self.completeRequest(errorMessage: "Backend returned an error.")
                return
            }

            guard let data = data else {
                self.completeRequest(errorMessage: "No data received from backend.")
                return
            }
            
            if let responseBody = String(data: data, encoding: .utf8) {
                print("Response Body: \(responseBody)")
            }

            // 5. Decode the response and save the job_id.
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let jobId = json["job_id"] as? String {
                    print("Successfully received job_id: \(jobId)")
                    self.saveJobIdForMainApp(jobId)
                    self.completeRequest(successMessage: "Sent to Steez!")
                } else {
                    self.completeRequest(errorMessage: "Invalid response format.")
                }
            } catch {
                self.completeRequest(errorMessage: "Failed to parse response.")
            }
        }
        task.resume()
    }

    // MARK: - Helper Functions
    
    /// This is a placeholder. In a real app, you would retrieve the logged-in user's ID
    /// from your shared authentication state (e.g., Keychain or shared UserDefaults).
    private func getCurrentUserId() -> String {
        // FOR NOW: We use a hardcoded UUID.
        // TODO: Replace this with actual user ID retrieval logic.
        return "123e4567-e89b-12d3-a456-426614174000"
    }

    // Removed auto-open logic per UX decision

    /// Saves the received job ID into the shared App Group UserDefaults.
    private func saveJobIdForMainApp(_ jobId: String) {
        guard let userDefaults = UserDefaults(suiteName: appGroupId) else {
            print("Error: Could not access shared UserDefaults. Is the App Group configured correctly?")
            return
        }
        userDefaults.set(jobId, forKey: latestJobIdKey)
        print("Saved job ID \(jobId) to shared UserDefaults with key: \(latestJobIdKey)")
        
        // Also log what's currently in UserDefaults for debugging
        print("Current UserDefaults contents: \(userDefaults.dictionaryRepresentation())")
    }

    /// Completes the share request and closes the extension, showing a message first.
    private func completeRequest(successMessage: String? = nil, errorMessage: String? = nil) {
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            
            if let successMessage = successMessage {
                self.statusLabel.text = successMessage
                
                // Dismiss after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                }
            } else if let errorMessage = errorMessage {
                print("Share Extension Error: \(errorMessage)")
                self.statusLabel.text = "Error: Please try again." // User-friendly message
                self.statusLabel.textColor = .systemRed

                // Dismiss after a delay so the user can see the error.
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    let error = NSError(domain: "com.steez.app.share", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                    self.extensionContext?.cancelRequest(withError: error)
                }
            } else {
                // Should not happen, but as a fallback, just dismiss.
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
    }
} 
