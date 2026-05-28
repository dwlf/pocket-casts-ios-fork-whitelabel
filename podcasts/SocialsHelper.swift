
import Foundation
import PocketCastsUtils

class SocialsHelper {
    /// Strip any leading "@" from the configured social handle. The
    /// L10n `socialHandle` constant ships with a "@" prefix for display,
    /// but the URL paths below expect the bare handle.
    private static var bareHandle: String {
        WhitelabelConfig.socialHandle.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
    }

    class func openTwitter() {
        let handle = bareHandle
        guard !handle.isEmpty else { return }
        let urls = [
            "tweetbot:///user_profile/\(handle)",
            "twitterrific:///profile?screen_name=\(handle)",
            "twitter://user?screen_name=\(handle)",
            "https://x.com/\(handle)",
        ]

        openUrls(urls: urls)
    }

    class func openInstagram() {
        let handle = bareHandle
        guard !handle.isEmpty else { return }
        let urls = [
            "instagram://user?username=\(handle)",
            "https://www.instagram.com/\(handle)/",
            "",
        ]

        openUrls(urls: urls)
    }

    private class func openUrls(urls: [String]) {
        let application = UIApplication.shared
        for urlString in urls {
            if let url = URL(string: urlString) {
                if application.canOpenURL(url) {
                    application.open(url, options: [:], completionHandler: nil)

                    return
                }
            }
        }
    }
}
