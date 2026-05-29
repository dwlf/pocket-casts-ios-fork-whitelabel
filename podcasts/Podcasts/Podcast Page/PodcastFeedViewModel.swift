import Foundation
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils

enum PodcastFeedReloadNotification {
    public static let loading = NSNotification.Name(rawValue: "PodcastFeedReloadNotificationLoading")
    public static let episodesFound = NSNotification.Name(rawValue: "PodcastFeedReloadNotificationEpisodesFound")
    public static let noEpisodesFound = NSNotification.Name(rawValue: "PodcastFeedReloadNotificationNoEpisodesFound")
}

class PodcastFeedViewModel {
    enum LoadingState {
        case idle
        case loading
        case cancelled
    }

    let uuid: String?

    private(set) var loadingState: LoadingState = .idle
    private var podcastFeedReloadTask: Task<Bool, Never>?

    init(uuid: String?) {
        self.uuid = uuid
    }

    func cancelTask() {
        if loadingState == .loading,
           let task = podcastFeedReloadTask,
           !task.isCancelled {
            loadingState = .cancelled
            task.cancel()
        }
    }

    func checkIfNewEpisodesAreAvailable(from source: PodcastFeedReloadSource) async -> Bool {
        guard let uuid, let podcast = DataManager.sharedManager.findPodcast(uuid: uuid, includeUnsubscribed: true) else {
            return false
        }

        FileLog.shared.console("Reload podcast feed for podcast \(uuid) - last episode \(podcast.latestEpisodeUuid ?? "none")")

        podcastFeedReloadTask = Task { [weak self] in
            guard let self else { return false }
            await MainActor.run {
                self.loadingState = .loading

                Analytics.track(.podcastScreenRefreshEpisodeList, properties: ["action": source.analyticsValue, "podcast_uuid": uuid])

                if source == .refreshControl {
                    NotificationCenter.default.post(name: PodcastFeedReloadNotification.loading, object: nil)
                } else {
                    Toast.show(L10n.podcastFeedReloadLoading, dismissAfter: .never)
                }
            }
            let success = await self.reloadFeed(podcast: podcast, uuid: uuid)

            await MainActor.run {
                if self.loadingState != .cancelled {

                    let event: AnalyticsEvent = success ? .podcastScreenRefreshNewEpisodeFound : .podcastScreenRefreshNoEpisodesFound
                    Analytics.track(event, properties: ["action": source.analyticsValue, "podcast_uuid": uuid])

                    if source == .refreshControl {
                        let notification = success ? PodcastFeedReloadNotification.episodesFound : PodcastFeedReloadNotification.noEpisodesFound
                        NotificationCenter.default.post(name: notification, object: nil)
                    } else {
                        let message = success ? L10n.podcastFeedReloadNewEpisodesFound : L10n.podcastFeedReloadNoEpisodesFound
                        Toast.show(message)
                    }
                }
                self.loadingState = .idle
            }
            return success
        }
        return await podcastFeedReloadTask?.value ?? false
    }

    /// Pulls new episodes for a single podcast. No-backend builds re-parse the
    /// locally-ingested RSS feed on-device and post `podcastUpdated` so the
    /// detail screen reloads its episode list; backend builds ask the cache
    /// host and let `RefreshManager` apply the delta. Returns whether any new
    /// episodes were found.
    private func reloadFeed(podcast: Podcast, uuid: String) async -> Bool {
        if !WhitelabelConfig.hasBackend {
            let newEpisodes = (try? await FeedIngestion.refresh(podcast: podcast)) ?? 0
            FileLog.shared.console("Local feed reload for podcast \(uuid) found \(newEpisodes) new episodes")
            if newEpisodes > 0 {
                NotificationCenter.postOnMainThread(notification: Constants.Notifications.podcastUpdated, object: uuid)
            }
            return newEpisodes > 0
        }

        do {
            let success = try await MainServerHandler.shared.updatePodcast(uuid: uuid, lastEpisodeUuid: podcast.latestEpisodeUuid)
            if success {
                FileLog.shared.console("Refresh manager update podcast \(uuid)")
                await RefreshManager.shared.refresh(podcast: podcast, from: uuid)
            }
            return success
        } catch {
            FileLog.shared.console("Failed update podcast \(uuid) - \(error.localizedDescription)")
            return false
        }
    }
}
