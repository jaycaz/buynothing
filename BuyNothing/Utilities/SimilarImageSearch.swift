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

/// Returns CGImages of items visually similar to the given query text.
///
/// Uses Google Custom Search JSON API with image search mode. `fetch` downloads every
/// result before returning; `fetchSegmentedStreaming` yields each item as soon as it
/// finishes downloading + segmenting (completion order), so callers can pack items in
/// live instead of waiting for the whole batch.
enum SimilarImageSearch {

    /// Fetch up to `count` similar images for the given text query, waiting for all of them.
    static func fetch(query: String, count: Int = 10) async throws -> [CGImage] {
        let urls = try await searchImageURLs(query: query, maxResults: count)

        // Download results sequentially, dropping failures
        var images: [CGImage] = []
        for url in urls {
            if let downloaded = try? await downloadImage(from: url) {
                images.append(downloaded)
            }
        }

        return images
    }

    /// Streams similar images in completion order: each result is downloaded, then (when
    /// `segment` is true) cut out of its background on-device and aligned the same way as
    /// the user's own photo, and yielded as soon as it finishes. Whichever item finishes
    /// first arrives first.
    ///
    /// Individual item failures are dropped (a partial collage is fine); a failure of the
    /// search call itself makes the stream throw.
    static func fetchSegmentedStreaming(query: String, maxImages: Int = 10, segment: Bool = true) -> AsyncThrowingStream<CGImage, Error> {
        AsyncThrowingStream(bufferingPolicy: .unbounded) { continuation in
            let producer = Task.detached(priority: .userInitiated) {
                do {
                    let urls = try await Self.searchImageURLs(query: query, maxResults: min(maxImages, 10))
                    await withTaskGroup(of: Void.self) { group in
                        for url in urls {
                            group.addTask {
                                guard !Task.isCancelled else { return }
                                if let image = try? await Self.processSourcedImage(from: url, segment: segment) {
                                    continuation.yield(image)
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                producer.cancel()
            }
        }
    }

    /// Runs the Google Custom Search JSON API (image mode) once and returns the result
    /// image URLs in API order.
    static func searchImageURLs(query: String, maxResults: Int) async throws -> [String] {
        let key = Secrets.googleSearchKey
        let engine = Secrets.googleSearchEngineID
        guard !key.isEmpty, key != "your-google-search-api-key-here",
              !engine.isEmpty, engine != "your-google-customsearch-engine-id-here" else {
            throw SimilarImageSearchError.missingAPIKey
        }

        // Build query string manually to avoid JSON encoding issues
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://www.googleapis.com/customsearch/v1?key=\(key)&cx=\(engine)&q=\(encodedQuery)&searchType=image&num=\(min(maxResults, 10))&safe=active"

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

        var urls: [String] = []
        for itemDict in itemsArray {
            if let link = itemDict["link"] as? String, !link.isEmpty {
                urls.append(link)
            }
        }
        return urls
    }

    /// Downloads a single sourced image and turns it into a collage-ready item via
    /// `processSourcedImageData`. Returns `nil` when the fetch itself is unusable
    /// (bad URL, non-2xx response); callers drop it.
    static func processSourcedImage(from urlString: String, segment: Bool) async throws -> CGImage? {
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else { return nil }

        return processSourcedImageData(data, segment: segment)
    }

    /// Turns downloaded image data into a collage-ready item: sanity filters, then (when
    /// `segment` is true) on-device background removal + PCA alignment — the same treatment
    /// as the user's own photo. Returns `nil` when the item is unusable (too small,
    /// banner-shaped, or no segmentable subject); callers drop it.
    static func processSourcedImageData(_ data: Data, segment: Bool) -> CGImage? {
        guard data.count <= 12_000_000 else { return nil }

        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return nil }
        guard cgImage.width >= 64, cgImage.height >= 64 else { return nil }
        let aspect = max(cgImage.width, cgImage.height) / max(1, min(cgImage.width, cgImage.height))
        guard aspect <= 5 else { return nil }

        guard segment, #available(iOS 17.0, *) else { return cgImage }

        do {
            let cutout = try ForegroundSegmenter.cutoutForegroundObject(from: cgImage)
            return ObjectOrientationAligner.align(cutout)
        } catch {
            // No segmentable subject (text, logos, cluttered photos): drop this item
            // rather than pasting in a backgrounded rectangle.
            return nil
        }
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
