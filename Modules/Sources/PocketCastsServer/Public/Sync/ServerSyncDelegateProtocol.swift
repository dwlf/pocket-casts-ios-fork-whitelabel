import Foundation
import PocketCastsDataModel

public protocol ServerSyncDelegate {
    // functions called by Server module during sync
    func podcastUpdated(podcastUuid: String)
    func podcastAdded(podcastUuid: String)
    func checkForUnusedPodcasts()
    func applyAutoArchivingToAllPodcasts()

    /// Re-parses locally-ingested RSS feeds on-device and adds any new
    /// episodes. Used by no-backend builds, where the cache host has no record
    /// of locally-parsed feeds. `completion` receives the number of new
    /// episodes added across all podcasts.
    func refreshLocalFeeds(podcasts: [Podcast], completion: @escaping (Int) -> Void)

    func subscribedToPodcast()

    func playlistChanged()

    func episodeStarredChanged(episode: Episode)
    func archiveEpisodeExternal(episode: Episode)
    func markEpisodeAsPlayedExternal(episode: Episode)
    func deselectedChaptersChanged()
    func episodeCanBeCleanedUp(episode: Episode) -> Bool
    func autoDownloadLatestEpisodes(uuids: [String])
    func cleanupAllUnusedEpisodeBuffers()

    func deleteFromDevice(userEpisode: UserEpisode)
    func autoDownloadUserEpisodes(episodes: [UserEpisode])
    func userEpisodeFileProtocol() -> FilePathProtocol
    func cleanupCloudOnlyFiles()
    func performActionsAfterSync()

    // Data required from App during sync
    func isPushEnabled() -> Bool

    func defaultPodcastGrouping() -> Int32
    func defaultShowArchived() -> Bool

    func uniqueAppId() -> String
    func appVersion() -> String
    func privateUserAgent() -> String
    func minTimeBetweenProgressSaves() -> Double
    func production() -> Bool
}

public extension ServerSyncDelegate {
    // Default no-op for conformers that don't ingest local feeds (e.g. watchOS,
    // which has no on-device feed parser).
    func refreshLocalFeeds(podcasts: [Podcast], completion: @escaping (Int) -> Void) {
        completion(0)
    }
}
