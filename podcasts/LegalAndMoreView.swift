import PocketCastsUtils
import SwiftUI

struct LegalAndMore: View {
    @EnvironmentObject var theme: Theme

    @State private var showTermsOfService = false
    @State private var showPrivacyPolicy = false
    @State private var showAcknowledgements = false

    var body: some View {
        ZStack {
            ThemeColor.primaryUi04(for: theme.activeTheme).color
                .ignoresSafeArea()
            List {
                Section {
                    if Constants.termsOfUseURL != nil {
                        AboutRow(mainText: L10n.aboutTermsOfService, showChevronIcon: true) {
                            track(row: "terms_of_service")
                            showTermsOfService = true
                        }
                    }
                    if Constants.privacyPolicyURL != nil {
                        AboutRow(mainText: L10n.aboutPrivacyPolicy, showChevronIcon: true) {
                            track(row: "privacy_policy")
                            showPrivacyPolicy = true
                        }
                    }
                    AboutRow(mainText: L10n.aboutAcknowledgements, showChevronIcon: true) {
                        track(row: "acknowledgements")
                        showAcknowledgements = true
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationBarTitle(L10n.aboutLegalAndMore, displayMode: .inline)
        // Terms of Service
        if let termsURL = Constants.termsOfUseURL {
            NavigationLink(
                destination: WebView(url: termsURL).navigationTitle(L10n.aboutTermsOfService),
                isActive: $showTermsOfService
            ) {}
        }
        // Privacy Policy
        if let privacyURL = Constants.privacyPolicyURL {
            NavigationLink(
                destination: WebView(url: privacyURL).navigationTitle(L10n.aboutPrivacyPolicy),
                isActive: $showPrivacyPolicy
            ) {}
        }
        // Acknowledgements
        NavigationLink(
            destination: WebView(url: Constants.acknowledgementsURL).navigationTitle(L10n.aboutAcknowledgements),
            isActive: $showAcknowledgements
        ) {}
    }

    private func track(row: String) {
        Analytics.track(.settingsAboutLegalAndMoreTapped, properties: ["row": row])
    }

    private enum Constants {
        // White-label default has empty ToS/Privacy URLs; URL(string:) returns
        // nil for empty input, which the body uses to hide the corresponding
        // rows. Branded forks supply real URLs via WhitelabelConfig.
        static let termsOfUseURL = URL(string: WhitelabelConfig.termsOfUseURL)
        static let privacyPolicyURL = URL(string: WhitelabelConfig.privacyPolicyURL)
        static let acknowledgementsURL = Bundle.main.url(forResource: "acknowledgements", withExtension: "html")!
    }
}

private struct WebView: UIViewControllerRepresentable {
    var url: URL

    func makeUIViewController(context: Context) -> OnlineSupportController {
        OnlineSupportController(url: url, source: .about)
    }

    func updateUIViewController(_ uiViewController: OnlineSupportController, context: Context) {}
}
