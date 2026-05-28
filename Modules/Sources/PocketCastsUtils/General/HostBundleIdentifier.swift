import Foundation

/// The host iOS app's bundle identifier, derived at runtime so it returns
/// the same value whether this code runs in the main app target or in an
/// extension / watch / app-clip target. Used wherever the host app's
/// bundle ID is the canonical namespace — keychain prefix, shared session
/// IDs, NSUserActivity types, BGTask identifiers — so all processes
/// compute the same string.
///
/// Implementation: take `Bundle.main.bundleIdentifier` and strip any
/// known extension suffix. Adding a new extension target requires
/// appending its suffix to `extensionSuffixes` below.
public enum HostBundleIdentifier {
    public static var value: String {
        let id = Bundle.main.bundleIdentifier ?? "podcasts"
        for suffix in extensionSuffixes where id.hasSuffix(suffix) {
            return String(id.dropLast(suffix.count))
        }
        return id
    }

    private static let extensionSuffixes = [
        ".PodcastsIntents",
        ".PodcastsIntentsUI",
        ".NotificationExtension",
        ".NotificationContent",
        ".Share-Extension",
        ".watchkitapp",
        ".watchkitextension",
        ".Clip",
    ]
}
