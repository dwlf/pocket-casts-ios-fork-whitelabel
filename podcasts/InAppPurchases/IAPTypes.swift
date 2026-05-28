import Foundation
import PocketCastsUtils

enum IAPProductID: CaseIterable {
    case yearly
    case monthly
    case patronYearly
    case patronMonthly
    case yearlyReferral

    /// App Store product identifier, sourced from the white-label config.
    /// An empty (unconfigured) id makes `init(productId:)` reject every
    /// lookup, disabling subscription flows — matching the config's
    /// empty-default "IAP disabled" contract.
    var productId: String {
        switch self {
        case .yearly: return WhitelabelConfig.iapPlusYearly
        case .monthly: return WhitelabelConfig.iapPlusMonthly
        case .patronYearly: return WhitelabelConfig.iapPatronYearly
        case .patronMonthly: return WhitelabelConfig.iapPatronMonthly
        case .yearlyReferral: return WhitelabelConfig.iapPlusYearlyReferral
        }
    }

    /// Reverse lookup from a store product identifier. Returns nil for an
    /// empty or unrecognised id (e.g. when IAP is unconfigured).
    init?(productId: String) {
        guard !productId.isEmpty,
              let match = Self.allCases.first(where: { $0.productId == productId }) else {
            return nil
        }
        self = match
    }

    var renewalPrompt: String {
        switch self {
        case .yearly, .patronYearly, .yearlyReferral:
            return L10n.accountPaymentRenewsYearly
        case .monthly, .patronMonthly:
            return L10n.accountPaymentRenewsMonthly
        }
    }

    var isYearlyProduct: Bool {
        switch self {
        case .yearly, .yearlyReferral, .patronYearly:
            return true
        default:
            return false
        }
    }
}

enum IAPPromotionID {
    case referall

    /// App Store promotional-offer identifier, sourced from the
    /// white-label config (empty when IAP is unconfigured).
    var productId: String {
        WhitelabelConfig.iapReferralPromo
    }
}

enum IAPOfferType: String {
    case freeTrial = "free_trial"
    case introOffer = "intro_offer"
    case referral = "referral"
    case winback = "winback"
}

enum Plan {
    case plus, patron

    var products: [IAPProductID] {
        return [yearly, monthly]
    }

    var yearly: IAPProductID {
        switch self {
        case .plus:
            return .yearly
        case .patron:
            return .patronYearly
        }
    }

    var monthly: IAPProductID {
        switch self {
        case .plus:
            return .monthly
        case .patron:
            return .patronMonthly
        }
    }
}

enum PlanFrequency: String {
    case yearly, monthly

    var description: String {
        switch self {
        case .yearly: return L10n.year
        case .monthly: return L10n.month
        }
    }
}

struct ProductInfo {
    let plan: Plan
    let frequency: PlanFrequency
}

struct IAPDiscountInfo {
    let identifier: String
    let uuid: UUID
    let timestamp: Int
    let key: String
    let signature: String
}
