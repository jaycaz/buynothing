//
//  ItemIdentifier.swift
//  BuyNothing
//
//  Prototype-only service for identifying items from a photo using external AI vision APIs.
//
//  ⚠️ This is a DEBUG-only prototype. Requires external API keys.
//

import Foundation
import simd

/// Encapsulates the result of identifying an item from a photo.
enum ItemIdentifier {

    /// A structured identification result containing a display name and a search query.
    struct Identification {
        /// A human-friendly name for the item (e.g. "white ceramic mug", "USB-C cable").
        let name: String
        /// A Google search query optimized for image search (e.g. "white ceramic mug").
        let searchQuery: String
    }

    /// Calls an external vision AI (Claude) to identify the item in `cgImage`,
    /// then generates a Google image-search query optimized for the result.
    ///
    /// Returns a structured JSON response with `name` and `searchQuery` fields.
    ///
    /// - Parameter cgImage: The cutout image (transparent background already removed).
    /// - Returns: An `Identification` result containing the identified name and search query.
    /// - Throws: If the API call fails.
    ///
    /// - Note: This is prototype-only and requires `Secrets.claudeAPIKey` to be set.
    /// - Note: Errors are reported but not fatal (see `handleAPIError(_:)`).
    ///
    static func identify(_ cgImage: CGImage) async throws -> Identification {
        // This would be the main identify call — stubbed for prototype.
        let result = try handleAPIError("stub")
        return result
    }

    /// Calls Claude via `CLAUDE_API_URL` endpoint with a vision call.
    ///
    /// Request:
    /// ```json
    /// {
    ///   "model": "claude-haiku-4-5",
    ///   "max_tokens": 256,
    ///   "temperature": 0.7,
    ///   "json_mode": true,
    ///   "input": {
    ///     "images": [{"source": "base64", "data": "..."}],
    ///     "text": "Identify this item and return a JSON object with two fields: name (e.g. 'red mug'), searchQuery (e.g. 'red mug'). Keep it brief, just enough for Google image search."
    ///   }
    /// }
    /// ```
    ///
    /// Expected response (when json_mode is true):
    /// ```json
    /// {"name": "white ceramic mug", "searchQuery": "white ceramic mug"}
    /// ```
    static func handleAPIError(_ cgImage: CGImage) async throws -> Identification {
        guard let apiKey = Secrets.claudeAPIKey, !apiKey.isEmpty else {
            throw ItemIdentifierError.missingAPIKey
        }

        guard let cgJpeg = cgImage.jpegData(compressionQuality: 0.7) else {
            throw ItemIdentifierError.imageEncodingFailed
        }

        let base64Data = cgJpeg.base64EncodedString(options: [.endLineWithLineFeed])

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
                    "text": "Identify this item. Return a JSON object with two fields: name and searchQuery. name is a descriptive display name. searchQuery is a concise phrase optimized for Google image search (keywords only, no fluff)."
                ]
            ]
        ]

        guard let bodyJSON = try? JSONSerialization.data(withJSONObject: requestBody),
              let bodyString = String(data: bodyJSON, encoding: .utf8) else {
            throw ItemIdentifierError.requestSerializationFailed
        }

        let url = URL(string: CLAUDE_API_URL)
        guard let url = url else {
            throw ItemIdentifierError.invalidAPIURL
        }

        let headers = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.httpBody = bodyJSON

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...204).contains(httpResponse.statusCode) else {
                throw ItemIdentifierError.httpError(code: httpResponse.statusCode, body: String(data: data, encoding: .utf8))
            }

            guard let json = try JSONSerialization.jsonObject(with: data),
                  let result = json as? [String: Any],
                  let name = result["name"] as? String,
                  let searchQuery = result["searchQuery"] as? String else {
                throw ItemIdentifierError.invalidResponseFormat
            }

            // Validate that output looks reasonable (non-empty, not obviously wrong).
            guard name.count >= 2, searchQuery.count >= 2, name.lowercased() != searchQuery.lowercased() else {
                throw ItemIdentifierError.suspectOutput
            }

            return Identification(name: name, searchQuery: searchQuery)

        } catch let decodingError as DecodingError {
            throw ItemIdentifierError.decodingError(error: decodingError, rawResponse: String(data: data, encoding: .utf8))
        } catch {
            throw ItemIdentifierError.genericError(error: error)
        }
    }

    enum ItemIdentifierError: Error {
        case missingAPIKey
        case imageEncodingFailed
        case requestSerializationFailed
        case invalidAPIURL
        case httpError(code: Int, body: String?)
        case invalidResponseFormat
        case suspectOutput
        case decodingError(error: DecodingError, rawResponse: String)
        case genericError(error: Error)
    }
}