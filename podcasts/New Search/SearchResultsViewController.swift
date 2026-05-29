import Foundation
import SwiftUI
import PocketCastsUtils

protocol SearchResultsDelegate {
    func clearSearch()
    func performLocalSearch(searchTerm: String)
    func performSearch(searchTerm: String, triggeredByTimer: Bool, completion: @escaping (() -> Void))
}

extension SearchResultsDelegate {
    func performRemoteSearch(searchTerm: String, completion: @escaping (() -> Void)) {}
    func performSearch(searchTerm: String, triggeredByTimer: Bool, completion: @escaping (() -> Void)) {}
}

class SearchResultsViewController: UIHostingController<AnyView> {
    private let displaySearch = SearchVisibilityModel()
    private let searchHistoryModel = SearchHistoryModel.shared
    private let searchResults: SearchResultsModel
    private let searchAnalyticsHelper: SearchAnalyticsHelper

    init(source: AnalyticsSource, showLocalResults: Bool = false) {
        searchAnalyticsHelper = SearchAnalyticsHelper(source: source)
        self.searchResults = SearchResultsModel(analyticsHelper: searchAnalyticsHelper, showLocalResults: showLocalResults)
        super.init(rootView: AnyView(
            SearchView()
            .setupDefaultEnvironment()
            .environmentObject(searchAnalyticsHelper)
            .environmentObject(searchResults)
            .environmentObject(searchHistoryModel)
            .environmentObject(displaySearch))
        )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func searchShown() {
        searchAnalyticsHelper.trackShown()
    }

    func searchDismissed() {
        searchAnalyticsHelper.trackDismissed()
    }
}

extension SearchResultsViewController: SearchResultsDelegate {
    func clearSearch() {
        displaySearch.isSearching = false
        searchResults.clearSearch()
    }

    func performLocalSearch(searchTerm: String) {
        displaySearch.isSearching = true
        searchResults.searchLocally(term: searchTerm)
    }

    func performSearch(searchTerm: String, triggeredByTimer: Bool, completion: @escaping (() -> Void)) {
        displaySearch.isSearching = true
        if searchTerm.trim().isEmpty {
            completion()
        }

        // A pasted/typed feed or Apple Podcasts URL is ingested locally; route
        // it straight to search() (which ingests) even on the as-you-type timer
        // so it adds without a separate submit and without flashing "No Results".
        let trimmed = searchTerm.trim().lowercased()
        let isURL = trimmed.startsWith(string: "http://") || trimmed.startsWith(string: "https://")

        if FeatureFlag.searchPredictive.enabled, triggeredByTimer, !isURL {
            searchResults.predictiveSearch(term: searchTerm)
        } else {
            searchResults.search(term: searchTerm)
        }

        if !triggeredByTimer, !searchTerm.trim().isEmpty {
            searchHistoryModel.add(searchTerm: searchTerm)
        }

        completion()
    }
}
