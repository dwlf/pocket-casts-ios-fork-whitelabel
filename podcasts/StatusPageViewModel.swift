import SwiftUI
import PocketCastsUtils

class StatusPageViewModel: ObservableObject {
    @Published var running = false

    @Published var hasRun = false

    class Service: Identifiable {
        let title: String
        let description: String
        let failureMessage: String
        let urls: [String]
        let customTest: (() -> Bool)?
        var status: Result = .idle

        init(title: String, description: String, failureMessage: String, urls: [String] = [], customTest: (() -> Bool)? = nil) {
            self.title = title
            self.description = description
            self.failureMessage = failureMessage
            self.urls = urls
            self.customTest = customTest
        }

        enum Result {
            case success, failure, running, idle
        }
    }

    /// Builds the service-check list from WhitelabelConfig. Internet and
    /// ExpensiveNetwork are always included (local checks). The four
    /// URL-backed services (refresh, account, discover, host) are omitted
    /// when their WhitelabelConfig URL is empty — the white-label default
    /// shows just the two local checks; branded forks see the full list
    /// once they configure their server URLs.
    lazy var checks: [Service] = {
        var list: [Service] = [
            Service(
                title: L10n.settingsStatusInternet,
                description: L10n.settingsStatusInternetDescription,
                failureMessage: L10n.settingsStatusInternetFailureMessage
            ),
            Service(
                title: L10n.settingsStatusExpensiveNetwork,
                description: L10n.settingsStatusExpensiveNetworkDescription,
                failureMessage: L10n.settingsStatusExpensiveNetworkFailureMessage,
                customTest: {
                    NetworkUtils.shared.isConnectedToUnexpensiveConnection()
                }
            ),
        ]

        if !WhitelabelConfig.refreshProductionURL.isEmpty,
           let refreshHost = URL(string: WhitelabelConfig.refreshProductionURL)?.host {
            let healthURL = WhitelabelConfig.refreshProductionURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/health.html"
            list.append(Service(
                title: L10n.settingsStatusRefreshService,
                description: L10n.settingsStatusRefreshServiceDescription,
                failureMessage: L10n.settingsStatusServiceAdBlockerHelpSingular(refreshHost),
                urls: [healthURL]
            ))
        }

        if !WhitelabelConfig.apiProductionURL.isEmpty,
           let apiHost = URL(string: WhitelabelConfig.apiProductionURL)?.host {
            let healthURL = WhitelabelConfig.apiProductionURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/health"
            list.append(Service(
                title: L10n.settingsStatusAccountService,
                description: L10n.settingsStatusAccountServiceDescription,
                failureMessage: L10n.settingsStatusServiceAdBlockerHelpSingular(apiHost),
                urls: [healthURL]
            ))
        }

        if !WhitelabelConfig.discoverProductionURL.isEmpty,
           let discoverHost = URL(string: WhitelabelConfig.discoverProductionURL)?.host {
            let discoverURL = WhitelabelConfig.discoverProductionURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/ios/content.json"
            list.append(Service(
                title: L10n.settingsStatusDiscover,
                description: L10n.settingsStatusDiscoverDescription,
                failureMessage: L10n.settingsStatusServiceAdBlockerHelpSingular(discoverHost),
                urls: [discoverURL]
            ))
        }

        // The "host" check tests podtrac MP3 redirection against a known
        // sample asset on the operator's CDN. Skip when the image/CDN URL
        // isn't configured — a branded fork can supply its own status
        // asset by setting imageProductionURL.
        if !WhitelabelConfig.imageProductionURL.isEmpty {
            let imageBase = WhitelabelConfig.imageProductionURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            list.append(Service(
                title: L10n.settingsStatusHost,
                description: L10n.settingsStatusHostDescription,
                failureMessage: L10n.settingsStatusHostFailureMessage,
                urls: ["https://dts.podtrac.com/redirect.mp3/\(imageBase.replacingOccurrences(of: "https://", with: ""))/assets/feeds/status/episode1.mp3"]
            ))
        }

        return list
    }()

    private lazy var networkUtils = NetworkUtils.shared

    @MainActor
    func run() {
        running = true

        Task {
            for service in checks {
                service.status = .running

                if networkUtils.isConnected() {
                    await test(service: service)
                } else {
                    service.status = .failure
                }

                // Force UI to update after a service is checked
                objectWillChange.send()
            }

            running = false
            hasRun = true
        }
    }

    @MainActor
    private func test(service: Service) async {
        if let customTest = service.customTest {
            service.status = customTest() ? .success : .failure
        } else if service.urls.isEmpty {
            service.status = .success
        } else {
            var responseCodes = [Int?]()

            for url in service.urls {
                if let url = URL(string: url) {
                    let status = await url.requestHTTPStatus()
                    responseCodes.append(status)
                }
            }

            // If any response code is different from 200, it's a failure
            service.status = responseCodes.contains(where: { $0 != 200 }) ? .failure : .success
        }
    }
}

private extension URL {
    func requestHTTPStatus() async -> Int? {
        let response = try? await URLSession.shared.data(from: self).1 as? HTTPURLResponse
        return response?.statusCode
    }
}
