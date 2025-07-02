import UIKit
import UniformTypeIdentifiers

/// A minimal Share Extension view controller that immediately forwards the first shared
/// URL or movie file to the Steez backend and then dismisses itself.
///
/// NOTE: This is boiler-plate. You will flesh out network logic later.
class ShareViewController: UIViewController {
    private let apiBaseURL: String = {
        guard let url = ProcessInfo.processInfo.environment["API_BASE_URL"] else {
            fatalError("API_BASE_URL not set for Share Extension")
        }
        return url
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        handleFirstAttachment()
    }

    private func handleFirstAttachment() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = extensionItem.attachments?.first else {
            complete()
            return
        }

        // Prefer a web URL (TikTok/Instagram) else a movie file
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
                if let url = item as? URL {
                    self?.upload(url: url)
                } else {
                    self?.complete()
                }
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { [weak self] item, _ in
                if let fileURL = item as? URL {
                    self?.upload(fileURL: fileURL)
                } else {
                    self?.complete()
                }
            }
        } else {
            complete()
        }
    }

    private func upload(url: URL) {
        guard let requestURL = URL(string: "\(apiBaseURL)/video/process") else { complete(); return }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ["source_url": url.absoluteString]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

        URLSession.shared.dataTask(with: request) { [weak self] _, _, _ in
            self?.complete()
        }.resume()
    }

    private func upload(fileURL: URL) {
        // For brevity we just read the file data into memory; in production stream it.
        guard let data = try? Data(contentsOf: fileURL),
              let requestURL = URL(string: "\(apiBaseURL)/video/process") else { complete(); return }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        URLSession.shared.uploadTask(with: request, from: data) { [weak self] _, _, _ in
            self?.complete()
        }.resume()
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
} 