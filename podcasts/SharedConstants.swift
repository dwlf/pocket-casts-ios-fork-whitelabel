import Foundation

enum SharedConstants {
    enum GroupUserDefaults {
        /// App-group container identifier, read from the target's Info.plist
        /// `APP_GROUP_ID` key (substituted from `$(APP_GROUP_ID)` at build
        /// time). Single source of truth for all targets sharing the
        /// container; fails fast if the build setting was not wired in.
        public static let groupContainerId: String = {
            guard let id = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_ID") as? String,
                  !id.isEmpty else {
                fatalError("APP_GROUP_ID missing from Info.plist — app-group container cannot be resolved. Check $(APP_GROUP_ID) is set in the active xcconfig.")
            }
            return id
        }()
        public static let upNextItems = "upNextItems"
        public static let upNextItemsCount = "upNextItemsCount"
        public static let siriSearchItems = "siriSearchItems"
        public static let topFilterName = "topFilterTitle"
        public static let topFilterItems = "topFilterItems"
        public static let isPlaying = "isPlaying"
        public static let appIcon = "appIcon"
    }

    enum PlaybackEffects {
        public static let maximumPlaybackSpeed = 3.0
        public static let minimumPlaybackSpeed = 0.5
    }
}
