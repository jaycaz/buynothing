//
//  SimilarImageSearch.swift
//  BuyNothing
//
//  Prototype-only service for fetching similar images via Google Custom Search API.
//
//  ⚠️ This is DEBUG-only. Requires `Secrets.googleSearchKey` and `Secrets.googleSearchEngineID`.
//

import Foundation

/// Returns up to `count` CGImages of items visually similar to the given query text.
///
/// Uses Google Custom Search JSON API with image search mode. Downloads results
/// concurrently, dropping any failures (404s, auth errors, junk results) rather
/// than failing the whole call. Returns however many images successfully fetch.
enum SimilarImageSearch {

    /// Fetch up to `count` similar images for the given text query.
    static func fetch(query: String, count: Int = 10) async throws -> [CGImage] {
        guard let key = Secrets.googleSearchKey,
              let engine = Secrets.googleSearchEngineID,
              !key.isEmpty,
              !engine.isEmpty else {
            throw SimilarImageSearchError.missingAPIKey
        }

        let url = URL(string: "https://www.googleapis.com/customsearch/v2")!

        let params: [String: Any] = [
            "key": key,
            "cx": engine,
            "q": query,
            "searchType": "image",
            "num": min(count, 10),  // Google has a 10-image limit per query
            "safe": "active"
        ]

        guard let queryParam = try? JSONSerialization.data(withJSONObject: params),
              let queryString = String(data: queryParam, encoding: .utf8) else {
            throw SimilarImageSearchError.requestSerializationFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("UTF-8", forHTTPHeaderField: "Accept-Charset")
        request.httpBody = queryString as NSData?

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...204).contains(httpResponse.statusCode) else {
            throw SimilarImageSearchError.httpError(code: httpResponse.statusCode, body: String(data: data, encoding: .utf8))
        }

        guard let json = try JSONSerialization.jsonObject(with: data),
              let itemsArray = json["items"] as? [[String: Any]],
              let items = itemsArray as? [SimilarImageSearch.Hit] else {
            throw SimilarImageSearchError.invalidResponseFormat
        }

        // Download results concurrently, dropping failures
        let results = items.filter { $0.width > 0 && $0.height > 0 }  // filter out invalid hits
        var images: [CGImage] = []
        for item in results {
            do {
                if let downloaded = try await downloadImage(from: item) {
                    images.append(downloaded)
                }
            } catch {
                // Drop individual failures — partial collage is fine
                continue
            }
        }

        return images
    }

    /// Downloads a single image from the hit's image_url.
    private static func downloadImage(from hit: Hit) async throws -> CGImage? {
        guard let urlString = hit.imageURL,
              let url = URL(string: urlString),
              let httpUrl = url as NSURL else {
            return nil
        }

        // Check if we already have this URL cached (unlikely in prototype)
        if let cached = DownloadCache.shared[cachedKey: urlString],
           let cg = cached.cgImage {
            return cg
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: URLRequest(url: httpUrl))

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...204).contains(httpResponse.statusCode) else {
                // 404s and network errors get dropped
                return nil
            }

            guard let image = UIImage(data: data),
                  let cgImage = image.cgImage else {
                return nil
            }

            // Cache the result
            DownloadCache.shared[cachedKey: urlString] = cgImage

            return cgImage
        } catch {
            // Network or decode failures get dropped
            return nil
        }
    }

    /// Cache for already-downloaded image URLs → CGImage mapping.
    private enum DownloadCache {
        static let shared = DownloadCache()

        private var cache: [String: CGImage] = [:]

        subscript(cachedKey key: String) -> CGImage? {
            get { cache[key] }
            set { cache[key] = newValue }
        }
    }

    /// A single Google Custom Search hit for images.
    private struct Hit: Codable {
        let title: String
        let link: String
        let width: Int
        let height: Int
        let thumbnailLink: String?

        var imageURL: String {
            thumbnailLink ?? link
        }
    }

    enum SimilarImageSearchError: Error {
        case missingAPIKey
        case requestSerializationFailed
        case httpError(code: Int, body: String?)
        case invalidResponseFormat
        case downloadFailed(reason: String)
        case genericError(error: Error)
    }
}
