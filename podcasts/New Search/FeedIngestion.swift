import CryptoKit
import Foundation
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils

/// Backend-free podcast ingestion from an RSS feed URL or an Apple Podcasts
/// link. Pocket Casts normally resolves feeds server-side via its cache host;
/// this path fetches and parses the publisher's RSS on-device so the
/// white-label build can add and play podcasts with no backend configured.
///
/// An Apple Podcasts URL is resolved to its RSS feed via the public iTunes
/// Lookup API (no authentication). The parsed channel/items are mapped into
/// the same `[String: Any]` shape `Podcast.from` / `Episode.from` already
/// consume, then handed to `ServerPodcastManager.addPodcastFromFeed`, reusing
/// the existing save pipeline.
enum FeedIngestion {
    enum IngestionError: LocalizedError {
        case unsupportedInput
        case appleLookupFailed
        case feedFetchFailed
        case feedParseFailed
        case noEpisodes

        var errorDescription: String? {
            switch self {
            case .unsupportedInput: return "That doesn't look like a podcast feed or Apple Podcasts link."
            case .appleLookupFailed: return "Couldn't find a feed for that Apple Podcasts link."
            case .feedFetchFailed: return "Couldn't download the podcast feed."
            case .feedParseFailed: return "Couldn't read the podcast feed."
            case .noEpisodes: return "That feed has no episodes."
            }
        }
    }

    /// Resolves, fetches, parses, and adds the podcast. Returns the UUID of the
    /// added (and optionally subscribed) podcast.
    @discardableResult
    static func ingest(from input: String, subscribe: Bool) async throws -> String {
        let feedURL = try await resolveFeedURL(from: input)
        let (data, response) = try await URLSession.shared.data(from: feedURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw IngestionError.feedFetchFailed
        }
        return try add(feedData: data, feedURL: feedURL, subscribe: subscribe)
    }

    /// Re-fetches and re-parses an already-added podcast's feed, adding any
    /// episodes not already stored. The deterministic episode UUIDs make this
    /// idempotent: existing episodes are matched and skipped, only new ones are
    /// inserted. Returns the number of new episodes added.
    @discardableResult
    static func refresh(podcast: Podcast) async throws -> Int {
        guard let feedString = podcast.podcastUrl, let feedURL = URL(string: feedString) else { return 0 }

        let (data, response) = try await URLSession.shared.data(from: feedURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw IngestionError.feedFetchFailed
        }

        let document: AEXMLDocument
        do {
            document = try AEXMLDocument(xmlData: data)
        } catch {
            throw IngestionError.feedParseFailed
        }

        let episodeJson = episodes(from: document.root["channel"])
        guard !episodeJson.isEmpty else { return 0 }

        let podcastInfo: [String: Any] = ["podcast": ["uuid": podcast.uuid, "episodes": episodeJson]]
        return ServerPodcastManager.shared.addMissingEpisodesFromFeed(podcastInfo: podcastInfo)
    }

    // MARK: - Resolve

    private static func resolveFeedURL(from input: String) async throws -> URL {
        let trimmed = input.trim()
        guard let url = URL(string: trimmed), let scheme = url.scheme, scheme.hasPrefix("http") else {
            throw IngestionError.unsupportedInput
        }
        guard url.host?.contains("podcasts.apple.com") == true else {
            return url
        }
        guard let id = applePodcastID(from: url) else {
            throw IngestionError.appleLookupFailed
        }
        return try await lookupAppleFeedURL(id: id)
    }

    /// Extracts the numeric collection id from an Apple Podcasts URL path
    /// component like `/id1454097755`. Tolerant of trailing characters.
    private static func applePodcastID(from url: URL) -> String? {
        for component in url.pathComponents where component.hasPrefix("id") {
            let digits = String(component.dropFirst(2).prefix { $0.isNumber })
            if !digits.isEmpty {
                return digits
            }
        }
        return nil
    }

    private struct LookupEnvelope: Decodable {
        let results: [LookupResult]
        struct LookupResult: Decodable { let feedUrl: String? }
    }

    private static func lookupAppleFeedURL(id: String) async throws -> URL {
        guard let lookupURL = URL(string: "https://itunes.apple.com/lookup?id=\(id)&entity=podcast") else {
            throw IngestionError.appleLookupFailed
        }
        let (data, _) = try await URLSession.shared.data(from: lookupURL)
        let envelope = try JSONDecoder().decode(LookupEnvelope.self, from: data)
        guard let feed = envelope.results.compactMap(\.feedUrl).first, let url = URL(string: feed) else {
            throw IngestionError.appleLookupFailed
        }
        return url
    }

    // MARK: - Parse + add

    private static func add(feedData: Data, feedURL: URL, subscribe: Bool) throws -> String {
        let document: AEXMLDocument
        do {
            document = try AEXMLDocument(xmlData: feedData)
        } catch {
            throw IngestionError.feedParseFailed
        }

        let channel = document.root["channel"]
        let feedString = feedURL.absoluteString
        let podcastUUID = Self.deterministicUUID(from: feedString)

        let episodeJson = episodes(from: channel)
        guard !episodeJson.isEmpty else { throw IngestionError.noEpisodes }

        var podcastJson: [String: Any] = ["uuid": podcastUUID, "url": feedString, "episodes": episodeJson]
        if let title = channel["title"].value { podcastJson["title"] = title }
        if let author = channel["itunes:author"].value ?? channel["managingEditor"].value { podcastJson["author"] = author }
        if let description = channel["description"].value ?? channel["itunes:summary"].value {
            podcastJson["description"] = description
        }
        if let category = channel["itunes:category"].attributes["text"] { podcastJson["category"] = category }

        let podcastInfo: [String: Any] = ["podcast": podcastJson]
        ServerPodcastManager.shared.addPodcastFromFeed(podcastInfo: podcastInfo, subscribe: subscribe)

        // Podcast.from does not read artwork from the feed JSON (upstream
        // derives it from the cache host by UUID), so set it explicitly from
        // the feed's <itunes:image> / <image><url>.
        if let imageURL = channel["itunes:image"].attributes["href"] ?? channel["image"]["url"].value,
           let podcast = DataManager.sharedManager.findPodcast(uuid: podcastUUID, includeUnsubscribed: true) {
            podcast.imageURL = imageURL
            DataManager.sharedManager.save(podcast: podcast)
        }

        return podcastUUID
    }

    private static func episodes(from channel: AEXMLElement) -> [[String: Any]] {
        guard let items = channel["item"].all else { return [] }
        let isoFormatter = ISO8601DateFormatter()
        var result: [[String: Any]] = []
        for item in items {
            let enclosure = item["enclosure"].attributes
            guard let audioURL = enclosure["url"] else { continue }

            let guid = item["guid"].value ?? audioURL
            var episode: [String: Any] = [
                "uuid": Self.deterministicUUID(from: guid),
                "url": audioURL
            ]
            if let title = item["title"].value { episode["title"] = title }
            if let type = enclosure["type"] { episode["file_type"] = type }
            if let length = enclosure["length"], let size = Int64(length) { episode["file_size"] = size }
            if let duration = Self.parseDuration(item["itunes:duration"].value) { episode["duration"] = duration }
            if let published = item["pubDate"].value, let date = Self.parseRFC822(published) {
                episode["published"] = isoFormatter.string(from: date)
            }
            if let number = item["itunes:episode"].value, let n = Int64(number) { episode["number"] = n }
            if let season = item["itunes:season"].value, let s = Int64(season) { episode["season"] = s }
            if let episodeType = item["itunes:episodeType"].value { episode["type"] = episodeType }
            result.append(episode)
        }
        return result
    }

    // MARK: - Helpers

    /// Stable, namespaced UUID derived from a string (feed URL or episode
    /// guid). Deterministic so re-adding or refreshing the same feed maps onto
    /// the same records instead of duplicating them.
    private static func deterministicUUID(from string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50 // version 5
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // RFC 4122 variant
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        let s = Array(hex)
        return String(s[0..<8]) + "-" + String(s[8..<12]) + "-" + String(s[12..<16]) + "-" + String(s[16..<20]) + "-" + String(s[20..<32])
    }

    /// Parses an iTunes duration: plain seconds ("879") or "HH:MM:SS" / "MM:SS".
    private static func parseDuration(_ value: String?) -> Double? {
        guard let value = value?.trim(), !value.isEmpty else { return nil }
        if !value.contains(":") { return Double(value) }
        let parts = value.split(separator: ":").map { Double($0) ?? 0 }
        return parts.reduce(0) { $0 * 60 + $1 }
    }

    private static func parseRFC822(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz", "dd MMM yyyy HH:mm:ss Z"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value.trim()) { return date }
        }
        return nil
    }
}
