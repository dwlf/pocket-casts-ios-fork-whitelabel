import Foundation
import PocketCastsUtils

public enum ServerConstants {
    /// Server URLs and support links. All values are sourced from
    /// `WhitelabelConfig` — the white-label default ships empty strings
    /// so a build with no configured backend produces empty URLs that
    /// callers can detect and gate UI on (Discover empty state, hidden
    /// account flows, etc.). Branded forks fill the values in via the
    /// `config/whitelabel/whitelabel.json` (or their own JSON) consumed
    /// by `scripts/generate_whitelabel_config.sh`.
    public enum Urls {
        public static func main() -> String {
            production() ? WhitelabelConfig.refreshProductionURL : WhitelabelConfig.refreshStagingURL
        }

        public static func api() -> String {
            production() ? WhitelabelConfig.apiProductionURL : WhitelabelConfig.apiStagingURL
        }

        public static func cache() -> String {
            production() ? WhitelabelConfig.cacheProductionURL : WhitelabelConfig.cacheStagingURL
        }

        public static func sharing() -> String {
            production() ? WhitelabelConfig.sharingProductionURL : WhitelabelConfig.sharingStagingURL
        }

        public static func discover() -> String {
            production() ? WhitelabelConfig.discoverProductionURL : WhitelabelConfig.discoverStagingURL
        }

        public static func image() -> String {
            production() ? WhitelabelConfig.imageProductionURL : WhitelabelConfig.imageStagingURL
        }

        public static func files() -> String {
            production() ? WhitelabelConfig.filesProductionURL : WhitelabelConfig.filesStagingURL
        }

        public static func share() -> String {
            production() ? WhitelabelConfig.shareProductionURL : WhitelabelConfig.shareStagingURL
        }

        public static func lists() -> String {
            production() ? WhitelabelConfig.listsProductionURL : WhitelabelConfig.listsStagingURL
        }

        public static var search: String {
            production() ? WhitelabelConfig.searchProductionURL : WhitelabelConfig.searchStagingURL
        }

        public static var generatedTranscripts: String {
            production() ? WhitelabelConfig.generatedTranscriptsProductionURL : WhitelabelConfig.generatedTranscriptsStagingURL
        }

        public static var tvPair: String { WhitelabelConfig.tvPairURL }
        public static var tvCreate: String { WhitelabelConfig.tvCreateURL }

        public static let support = WhitelabelConfig.supportURL
        public static let cancelSubscription = WhitelabelConfig.cancelSubscriptionURL
        public static let termsOfUse = WhitelabelConfig.termsOfUseURL
        public static let privacyPolicy = WhitelabelConfig.privacyPolicyURL
        public static let plusInfo = WhitelabelConfig.plusInfoURL
        public static let pocketcastsDotCom = WhitelabelConfig.websiteURL
        // `automatticDotCom` and `automatticWorkWithUs` stay literal —
        // these point at Automattic the company, not at a Pocket Casts
        // service. White-label callers (AboutView et al.) gate the rows
        // that use them on WhitelabelConfig.brandName presence.
        public static let automatticDotCom = "https://automattic.com/"
        public static let automatticWorkWithUs = "https://automattic.com/work-with-us/"
        public static let appStore = WhitelabelConfig.appStoreURL
        public static let appStoreReview = WhitelabelConfig.appStoreReviewURL
        public static let podrollLearnMore = WhitelabelConfig.podrollLearnMoreURL
        public static let supportPlaybackDownloadErrors = WhitelabelConfig.supportPlaybackDownloadErrorsURL
        public static let supportEpisodeAccessIssues = WhitelabelConfig.supportEpisodeAccessIssuesURL
        public static let supportEpisodeNotFound = WhitelabelConfig.supportEpisodeNotFoundURL
        public static let supportEpisodeServerProblem = WhitelabelConfig.supportEpisodeServerProblemURL
    }

    private static func production() -> Bool {
        guard let delegate = ServerConfig.shared.syncDelegate else {
            return true
        }
        return delegate.production()
    }

    public enum HttpConstants {
        public static let ok = 200
        public static let notModified = 304
        public static let unauthorized = 401
        public static let forbidden = 403
        public static let notFound = 404
        public static let serverError = 500
        public static let badRequest = 400
        public static let conflict = 409
    }

    public enum HttpHeaders {
        public static let lastModified = "Last-Modified"
        public static let ifModifiedSince = "If-Modified-Since"
        public static let ifNoneMatch = "If-None-Match"
        public static let contentType = "Content-Type"
        public static let accept = "Accept"
        public static let userAgent = "User-Agent"
        public static let authorization = "Authorization"
        public static let expires = "Expires"
        public static let cacheControl = "Cache-Control"
        public static let date = "Date"
        public static let etag = "ETag"
        public static let userRegion = "X-User-Region"
        public static let appLanguage = "X-App-Language"
    }

    public enum Timeouts {
        static let sync = 60 as TimeInterval
        static let general = 60 as TimeInterval
        static let cache = 30 as TimeInterval
    }

    public enum Values {
        static let apiScope = "mobile"
        static let deviceTypeiOS: Int32 = 1
        static let syncingEmailKey = "SJSyncingEmail"
        static let syncingPasswordKey = "SJSyncingPwd"
        static let syncingV2TokenKey = "SJSyncV2Token"
        static let refreshTokenKey = "SJRefreshToken"
        static let appleAuthUserIDKey = "SJAppleAuthUserID"
        public static let appUserAgent: String = WhitelabelConfig.appUserAgent.isEmpty
            ? "Podcasts"
            : WhitelabelConfig.appUserAgent
        static let customStorageUsed = "SJCustomStorageUsed"
        static let customStorageNumFiles = "SJCustomStorageNumFiles"
        static let customStorageUserLimit = "SJCustomStorageUserLimit"

        static let oldEpisodeCutoff = 2.weeks
    }

    public enum UserDefaults {
        static let lastModifiedServerDate = "PCLastModifiedServerDate"
        static let lastSyncStartDate = "PCLastSyncStartDate"
        static let lastRefreshStartTime = "LastRefreshStartTime"
        static let lastRefreshEndTime = "SJLastRefreshDate"
        static let lastSyncTime = "SJLastSyncDate"
        static let syncingEmailLegacy = "SJSyncingEmail"
        static let historyServerLastModified = "SJHistoryServerLastModified"
        static let upNextServerLastModified = "SJUpNextServerLastModified"
        static let lastClearHistoryDate = "SJLastClearHistoryDate"
        static let pushToken = "SJPushToken"
        static let subscriptionPaid = "SJSubscriptionPaid"
        static let subscriptionExpiryDate = "SJSubscriptionExpiryDate"
        static let subscriptionAutoRenewing = "SJSubscriptionAutorenewing"
        static let subscriptionPlatform = "SJSubscriptionPlatform"
        static let subscriptionGiftDays = "SJSubscriptionGiftDays"
        public static let subscriptionGiftAcknowledgement = "SJSubscriptionGiftAcknowledgement"
        public static let subscriptionFrequency = "SJSubscriptionFrequency"
        static let subscriptionPodcasts = "SJSubscriptionPodcasts"
        static let subscriptionType = "SJSubscriptionType"
        static let subscriptionTier = "SJSubscriptionTier"
        public static let marketingOptInKey = "SJMarketingOptIn"
        static let marketingOptInNeedsSyncKey = "SJMarketingOptInNeedsSync"
        static let subscriptionGiftAcknowledgementNeedsSyncKey = "SJGiftAcknowledgementNeedsSync"
        static let filesLastModifiedKey = "UserFilesLastModified"
        static let statsStartDate = "StatsStartDate"
        static let statsSyncStatus = "StatsSyncStatus"
        static let statsDynamicSpeedSeconds = "StatsDynamicSpeed"
        static let statsVariableSpeed = "StatsVariableSpeed"
        static let statsListenedTo = "StatsListenedTo"
        static let statsSkipped = "StatsSkipped"
        static let statsAutoSkip = "StatsIntroSKip"
        static let statsDynamicSpeedSecondsServer = "StatsDynamicSpeedServer"
        static let statsVariableSpeedServer = "StatsVariableSpeedServer"
        static let statsListenedToServer = "StatsListenedToServer"
        static let statsSkippedServer = "StatsSkippedServer"
        static let statsAutoSkipServer = "StatsIntroSkipServer"
        static let statsStartedDateServer = "StatsStartedDateServer"
        static let userId = "UserId"
        static let removeBannerAds = "SJSubscriptionRemoveBannerAds"
        static let removeDiscoverAds = "SJSubscriptionRemoveDiscoverAds"
        static let subscriptionCreateDate = "SJSubscriptionCreateDate"
    }

    public enum Limits {
        static let maxHistoryItems = 100
#if watchOS
        static let maxEpisodesToSync = 200
#else
        static let maxEpisodesToSync = 2000
#endif
    }
}
