//
//  SimilarImageSearch.swift
//  BuyNothing
//
//  Prototype-only service for fetching similar images via DuckDuckGo's keyless
//  image search (two-step flow: token from the search page, then the i.js JSON
//  endpoint). No API key required.
//
//  ⚠️ This is DEBUG-only.
//

import Foundation
import UIKit

/// Returns CGImages of items visually similar to the given query text.
///
/// Uses DuckDuckGo's keyless image search. `fetch` downloads every result before
/// returning; `fetchSegmentedStreaming` yields each item as soon as it finishes
/// downloading + segmenting (completion order), so callers can pack items in live
/// instead of waiting for the whole batch.
enum SimilarImageSearch {

    enum SimilarImageSearchError: LocalizedError {
        case requestSerializationFailed
        case vqdRetrievalFailed
        case httpError(code: Int, body: String)
        case invalidResponseFormat

        var errorDescription: String? {
            switch self {
            case .requestSerializationFailed:
                return "Failed to build the image search request."
            case .vqdRetrievalFailed:
                return "DuckDuckGo did not return a search token (vqd)."
            case let .httpError(code, body):
                return "Image search HTTP error (\(code)): \(body)"
            case .invalidResponseFormat:
                return "Image search returned an unexpected response format."
            }
        }
    }

    // The i.js endpoint expects a browser-like client; a plain app User-Agent gets 403'd.
    private static let browserUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"

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

    /// Runs the DuckDuckGo image search for the query and returns the result image URLs.
    static func searchImageURLs(query: String, maxResults: Int) async throws -> [String] {
        let vqd = try await fetchVqdToken(for: query)
        return try await fetchResultURLs(query: query, vqd: vqd, maxResults: maxResults)
    }

    /// Step 1: load the image search page and extract the one-time `vqd` token.
    private static func fetchVqdToken(for query: String) async throws -> String {
        guard var components = URLComponents(string: "https://duckduckgo.com/") else {
            throw SimilarImageSearchError.requestSerializationFailed
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "ia", value: "images"),
        ]
        guard let url = components.url else {
            throw SimilarImageSearchError.requestSerializationFailed
        }

        var request = URLRequest(url: url)
        request.setValue(browserUserAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw SimilarImageSearchError.httpError(code: (response as? HTTPURLResponse)?.statusCode ?? 0, body: "")
        }

        // The page embeds the token, e.g. `vqd=4-1234567890123456789`.
        guard let regex = try? NSRegularExpression(pattern: "vqd[=:\"\"]*([0-9]-[0-9]+)"),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            throw SimilarImageSearchError.vqdRetrievalFailed
        }
        return String(html[range])
    }

    /// Step 2: query the i.js JSON endpoint with the token and collect the image URLs.
    private static func fetchResultURLs(query: String, vqd: String, maxResults: Int) async throws -> [String] {
        guard var components = URLComponents(string: "https://duckduckgo.com/i.js") else {
            throw SimilarImageSearchError.requestSerializationFailed
        }
        components.queryItems = [
            URLQueryItem(name: "l", value: "us-en"),
            URLQueryItem(name: "o", value: "json"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "vqd", value: vqd),
            URLQueryItem(name: "f", value: ",,,"),
            URLQueryItem(name: "p", value: "1"),
            URLQueryItem(name: "v7exp", value: "a"),
        ]
        guard let url = components.url else {
            throw SimilarImageSearchError.requestSerializationFailed
        }

        var request = URLRequest(url: url)
        request.setValue(browserUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json, text/javascript, */* q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("https://duckduckgo.com/", forHTTPHeaderField: "Referer")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SimilarImageSearchError.httpError(code: (response as? HTTPURLResponse)?.statusCode ?? 0, body: String(data: data, encoding: .utf8) ?? "")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            throw SimilarImageSearchError.invalidResponseFormat
        }

        var urls: [String] = []
        for result in results {
            if let image = result["image"] as? String, !image.isEmpty {
                urls.append(image)
            }
        }
        return Array(urls.prefix(maxResults))
    }

    private static func downloadImage(from urlString: String) async throws -> CGImage? {
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else { return nil }

        guard let image = UIImage(data: data), let cgImage = image.cgImage else {
            return nil
        }
        return cgImage
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
}
