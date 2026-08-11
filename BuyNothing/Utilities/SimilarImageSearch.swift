//
//  SimilarImageSearch.swift
//  BuyNothing
//
//  Prototype-only service for fetching similar images via Google Custom Search API.
//
//  ⚠️ This is DEBUG-only. Requires `Secrets.googleSearchKey` and `Secrets.googleSearchEngineID`.
//

import Foundation
import UIKit

/// Returns up to `count` CGImages of items visually similar to the given query text.
///
/// Uses Google Custom Search JSON API with image search mode. Downloads results
/// concurrently, dropping any failures (404s, auth errors, junk results) rather
/// than failing the whole call. Returns however many images successfully fetch.
enum SimilarImageSearch {

    /// Fetch up to `count` similar images for the given text query.
    static func fetch(query: String, count: Int = 10) async throws -> [CGImage] {
        let key = Secrets.googleSearchKey
        let engine = Secrets.googleSearchEngineID
        guard !key.isEmpty, key != "your-google-search-api-key-here",
              !engine.isEmpty, engine != "your-google-customsearch-engine-id-here" else {
            throw SimilarImageSearchError.missingAPIKey
        }

        // Build query string manually to avoid JSON encoding issues
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://www.googleapis.com/customsearch/v1?key=\(key)&cx=\(engine)&q=\(encodedQuery)&searchType=image&num=\(min(count, 10))&safe=active"

        guard let url = URL(string: urlString) else {
            throw SimilarImageSearchError.requestSerializationFailed
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SimilarImageSearchError.httpError(code: (response as? HTTPURLResponse)?.statusCode ?? 0, body: String(data: data, encoding: .utf8))
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let itemsArray = json["items"] as? [[String: Any]] else {
            throw SimilarImageSearchError.invalidResponseFormat
        }

        // Download results sequentially, dropping failures
        var images: [CGImage] = []
        for itemDict in itemsArray {
            guard let link = itemDict["link"] as? String, !link.isEmpty else { continue }

            do {
                if let downloaded = try await downloadImage(from: link) {
                    images.append(downloaded)
                }
            } catch {
                // Drop individual failures — partial collage is fine
                continue
            }
        }

        return images
    }

    /// Downloads a single image from the given URL.
    private static func downloadImage(from urlString: String) async throws -> CGImage? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            guard let image = UIImage(data: data),
                  let cgImage = image.cgImage else {
                return nil
            }

            return cgImage
        } catch {
            return nil
        }
    }

    enum SimilarImageSearchError: Error, LocalizedError {
        case missingAPIKey
        case requestSerializationFailed
        case httpError(code: Int, body: String?)
        case invalidResponseFormat

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "Google Search API key is not configured. Add your key to Secrets.swift."
            case .requestSerializationFailed: return "Failed to build search request."
            case .httpError(let code, let body): return "HTTP error \(code): \(body ?? "no body")"
            case .invalidResponseFormat: return "Unexpected response format from Google."
            }
        }
    }
}
