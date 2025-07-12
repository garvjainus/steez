import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    // MARK: - Constants
    private let apiBaseURLString = "https://steez-backend.onrender.com" // TODO: Move to a config file
    private let appGroupId = "group.com.steez.app"
    private let latestJobIdKey = "latest_job_id"

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        handleSharedItem()
    }

    // MARK: - Core Logic
    private func handleSharedItem() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = extensionItem.attachments?.first else {
            completeRequest(withError: "No item found.")
            return
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
                guard let url = item as? URL else {
                    self?.completeRequest(withError: "Invalid URL shared.")
                    return
                }
                self?.processVideo(with: url)
            }
        } else {
            completeRequest(withError: "Please share a video URL.")
        }
    }

    private func processVideo(with url: URL) {
        // 1. Construct the correct URL for our backend endpoint.
        guard let requestURL = URL(string: "\(apiBaseURLString)/video-processing/process-video") else {
            completeRequest(withError: "Invalid backend URL.")
            return
        }

        // 2. Prepare the HTTP request.
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 3. Create the payload with all required fields.
        let payload: [String: Any] = [
            "user_id": getCurrentUserId(), // Placeholder for the actual user ID
            "video_url": url.absoluteString,
            "frame_rate": 2 // Default frame rate
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completeRequest(withError: "Failed to create request body.")
            return
        }

        // 4. Send the request to the backend.
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Ensure we can handle the response.
            guard let self = self else { return }

            if let error = error {
                self.completeRequest(withError: "Network request failed: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                self.completeRequest(withError: "Backend returned an error.")
                return
            }

            guard let data = data else {
                self.completeRequest(withError: "No data received from backend.")
                return
            }

            // 5. Decode the response and save the job_id.
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let jobId = json["job_id"] as? String {
                    print("Successfully received job_id: \(jobId)")
                    self.saveJobIdForMainApp(jobId)
                    self.completeRequest()
                } else {
                    self.completeRequest(withError: "Invalid response format.")
                }
            } catch {
                self.completeRequest(withError: "Failed to parse response.")
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

    /// Saves the received job ID into the shared App Group UserDefaults.
    private func saveJobIdForMainApp(_ jobId: String) {
        guard let userDefaults = UserDefaults(suiteName: appGroupId) else {
            print("Error: Could not access shared UserDefaults. Is the App Group configured correctly?")
            return
        }
        userDefaults.set(jobId, forKey: latestJobIdKey)
        print("Saved job ID \(jobId) to shared UserDefaults.")
    }

    /// Completes the share request and closes the extension.
    private func completeRequest(withError errorMessage: String? = nil) {
        if let errorMessage = errorMessage {
            print("Share Extension Error: \(errorMessage)")
            // Optionally, you can show an error to the user here.
            // For now, we just cancel.
            extensionContext?.cancelRequest(withError: NSError(domain: "com.steez.app.share", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
            return
        }
        
        // Signal success and dismiss.
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
} 