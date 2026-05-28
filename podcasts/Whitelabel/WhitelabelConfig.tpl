/// White-label configuration. Generated on %{timestamp}
///
/// Source of truth: config/whitelabel/whitelabel.json (or the JSON pointed to
/// by the active xcconfig's WHITELABEL_CONFIG_JSON variable).
/// Generation:     scripts/generate_whitelabel_config.sh (Xcode build phase).
///
/// Empty values cause server-dependent features (sync, discover, search,
/// sharing, account, subscription) to no-op gracefully — consumer code
/// checks for empty values and degrades to an empty-state UI rather than
/// making network calls to a missing host.
///
import Foundation

public enum WhitelabelConfig {
    // MARK: Brand

    public static let brandName = "%{brand_name}"
    public static let brandNameShort = "%{brand_name_short}"
    public static let socialHandle = "%{social_handle}"
    public static let websiteShort = "%{website_short}"
    public static let supportEmail = "%{support_email}"
    public static let appUserAgent = "%{app_user_agent}"

    // MARK: Server URLs (production / staging pairs)

    public static let apiProductionURL = "%{api_production_url}"
    public static let apiStagingURL = "%{api_staging_url}"
    public static let refreshProductionURL = "%{refresh_production_url}"
    public static let refreshStagingURL = "%{refresh_staging_url}"
    public static let cacheProductionURL = "%{cache_production_url}"
    public static let cacheStagingURL = "%{cache_staging_url}"
    public static let sharingProductionURL = "%{sharing_production_url}"
    public static let sharingStagingURL = "%{sharing_staging_url}"
    public static let discoverProductionURL = "%{discover_production_url}"
    public static let discoverStagingURL = "%{discover_staging_url}"
    public static let imageProductionURL = "%{image_production_url}"
    public static let imageStagingURL = "%{image_staging_url}"
    public static let filesProductionURL = "%{files_production_url}"
    public static let filesStagingURL = "%{files_staging_url}"
    public static let shareProductionURL = "%{share_production_url}"
    public static let shareStagingURL = "%{share_staging_url}"
    public static let listsProductionURL = "%{lists_production_url}"
    public static let listsStagingURL = "%{lists_staging_url}"
    public static let searchProductionURL = "%{search_production_url}"
    public static let searchStagingURL = "%{search_staging_url}"
    public static let generatedTranscriptsProductionURL = "%{generated_transcripts_production_url}"
    public static let generatedTranscriptsStagingURL = "%{generated_transcripts_staging_url}"

    // MARK: Server URLs (single value)

    public static let tvPairURL = "%{tv_pair_url}"
    public static let tvCreateURL = "%{tv_create_url}"
    public static let supportURL = "%{support_url}"
    public static let cancelSubscriptionURL = "%{cancel_subscription_url}"
    public static let termsOfUseURL = "%{terms_of_use_url}"
    public static let privacyPolicyURL = "%{privacy_policy_url}"
    public static let plusInfoURL = "%{plus_info_url}"
    public static let websiteURL = "%{website_url}"
    public static let appStoreURL = "%{app_store_url}"
    public static let appStoreReviewURL = "%{app_store_review_url}"
    public static let podrollLearnMoreURL = "%{podroll_learn_more_url}"
    public static let supportPlaybackDownloadErrorsURL = "%{support_playback_download_errors_url}"
    public static let supportEpisodeAccessIssuesURL = "%{support_episode_access_issues_url}"
    public static let supportEpisodeNotFoundURL = "%{support_episode_not_found_url}"
    public static let supportEpisodeServerProblemURL = "%{support_episode_server_problem_url}"

    // MARK: In-app purchases

    public static let iapPlusYearly = "%{iap_plus_yearly}"
    public static let iapPlusMonthly = "%{iap_plus_monthly}"
    public static let iapPatronYearly = "%{iap_patron_yearly}"
    public static let iapPatronMonthly = "%{iap_patron_monthly}"
    public static let iapPlusYearlyReferral = "%{iap_plus_yearly_referral}"
    public static let iapReferralPromo = "%{iap_referral_promo}"

    // MARK: Convenience

    /// True when the build has a configured backend URL. Server-dependent
    /// features (sync, discover, sharing, account, subscription) gate on
    /// this. The check uses `apiProductionURL` because every backend-
    /// requiring feature ultimately hits the api host.
    public static var hasBackend: Bool {
        !apiProductionURL.isEmpty
    }
}
