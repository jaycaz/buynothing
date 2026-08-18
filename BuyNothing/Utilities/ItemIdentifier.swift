//
//  ItemIdentifier.swift
//  BuyNothing
//
//  Prototype-only service for identifying items from a photo using external AI vision APIs.
//
//  ⚠️ This is a DEBUG-only prototype. Requires external API keys.
//

import Foundation
import UIKit

/// Encapsulates the result of identifying an item from a photo.
enum ItemIdentifier {

    /// A structured identification result containing a display name and a search query.
    struct Identification {
        /// A human-friendly name for the item (e.g. "white ceramic mug", "USB-C cable").
        let name: String
        /// A broad product category for image search (e.g. "screwdriver"), so results
        /// show many different looks of the item rather than one specific variant.
        let searchQuery: String
    }

    /// Calls Claude via the Messages API with a vision call to identify the item.
    ///
    /// - Parameter cgImage: The cutout image (transparent background already removed).
    /// - Returns: An `Identification` result containing the identified name and search query.
    /// - Throws: If the API call fails or the response is invalid.
    static func identify(_ cgImage: CGImage) async throws -> Identification {
        let apiKey = Secrets.claudeAPIKey
        guard !apiKey.isEmpty, apiKey != "your-claude-api-key-here" else {
            throw ItemIdentifierError.missingAPIKey
        }

        guard let jpegData = cgImage.jpegData(compressionQuality: 0.7) else {
            throw ItemIdentifierError.imageEncodingFailed
        }

        let base64Data = jpegData.base64EncodedString(options: [.endLineWithLineFeed])

        let requestBody: [String: Any] = [
            "model": "claude-haiku-4-5",
            "max_tokens": 256,
            "temperature": 0.7,
            "json_mode": true,
            "input": [
                [
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": base64Data
                    ]
                ],
                [
                    "type": "text",
                    "text": "Identify this item. Return a JSON object with two fields: name and searchQuery. name is a descriptive display name (e.g. \"blue cordless screwdriver\"). searchQuery is the broad product category for this item type (e.g. \"screwdriver\", \"ceramic mug\", \"sneakers\") — keywords only, and do NOT include colors, brands, models, or other specifics, so that image search returns many different looks of the same kind of object."
                ]
            ]
        ]

        guard let bodyJSON = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw ItemIdentifierError.requestSerializationFailed
        }

        guard let apiURL = URL(string: Secrets.claudeAPIURL) else {
            throw ItemIdentifierError.invalidAPIURL
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = bodyJSON

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ItemIdentifierError.invalidResponseFormat
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ItemIdentifierError.httpError(code: httpResponse.statusCode, body: String(data: data, encoding: .utf8))
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ItemIdentifierError.invalidResponseFormat
        }

        // Claude structured output may wrap in content array
        if let content = json["content"] as? [[String: Any]], let first = content.first {
            if let name = first["name"] as? String,
               let searchQuery = first["searchQuery"] as? String {
                return Identification(name: name, searchQuery: searchQuery)
            }
            // Try text field with JSON inside
            if let text = first["text"] as? String,
               let textData = text.data(using: .utf8),
               let textJson = try? JSONSerialization.jsonObject(with: textData) as? [String: Any],
               let name = textJson["name"] as? String,
               let searchQuery = textJson["searchQuery"] as? String {
                return Identification(name: name, searchQuery: searchQuery)
            }
        }

        // Direct JSON response
        if let name = json["name"] as? String,
           let searchQuery = json["searchQuery"] as? String {
            return Identification(name: name, searchQuery: searchQuery)
        }

        throw ItemIdentifierError.invalidResponseFormat
    }

    enum ItemIdentifierError: Error, LocalizedError {
        case missingAPIKey
        case imageEncodingFailed
        case requestSerializationFailed
        case invalidAPIURL
        case httpError(code: Int, body: String?)
        case invalidResponseFormat
        case suspectOutput
        case genericError(error: Error)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "Claude API key is not configured. Add your key to Secrets.swift."
            case .imageEncodingFailed: return "Failed to encode image for API request."
            case .requestSerializationFailed: return "Failed to serialize API request."
            case .invalidAPIURL: return "Invalid Claude API URL configured."
            case .httpError(let code, let body): return "HTTP error \(code): \(body ?? "no body")"
            case .invalidResponseFormat: return "Unexpected response format from Claude API."
            case .suspectOutput: return "API returned suspicious output."
            case .genericError(let error): return "API error: \(error.localizedDescription)"
            }
        }
    }
}

private extension CGImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        let image = UIImage(cgImage: self)
        return image.jpegData(compressionQuality: compressionQuality)
    }
}
