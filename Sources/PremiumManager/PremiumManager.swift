import Foundation
import StoreKit
import ApphudSDK
import RxSwift
import RxCocoa

// MARK: - PaywallType
public enum PaymentScreenType: Int {
    case first = 1
    case second = 2

    public init(rawValue: Int?) {
        self = PaymentScreenType(rawValue: rawValue ?? 1) ?? .second
    }
}

// MARK: - PremiumManager
public final class PremiumManager {

    // MARK: - Shared Instance
    public static let shared = PremiumManager()

    // MARK: - Public Observables
    public let isPremium: BehaviorRelay<Bool> = BehaviorRelay(value: false)
    public let products: BehaviorRelay<[ApphudProduct]> = BehaviorRelay(value: [])
    public let paywallType: BehaviorRelay<PaymentScreenType> = BehaviorRelay(value: .second)
    public let defaultProduct: BehaviorRelay<ApphudProduct?> = BehaviorRelay(value: nil)

    // MARK: - Private Properties
    private let disposeBag = DisposeBag()
    public var config: PremiumManagerConfig?

    // MARK: - Initializer
    private init() {}

    // MARK: - Configuration
    @MainActor public func configure(with config: PremiumManagerConfig) {
        self.config = config
        Apphud.start(apiKey: config.apiKey)
        checkPremiumStatus()
    }

    // MARK: - Public Methods
    @MainActor public func fetchProducts() {
        guard config != nil else {
            print("PremiumManager is not configured. Call `configure(with:)` first.")
            return
        }

        Observable<[ApphudPlacement]>.create { observer in
            Task {
                let placements = await Apphud.placements(maxAttempts: 10)
                observer.onNext(placements)
                observer.onCompleted()
            }
            return Disposables.create()
        }
        .compactMap { $0.first?.paywall }
        .do(onNext: { [weak self] paywall in
            if let id = paywall.json?["paywall"] as? Int {
                self?.paywallType.accept(PaymentScreenType(rawValue: id))
            } else {
                self?.paywallType.accept(.second)
            }
        })
        .map { $0.products }
        .observe(on: MainScheduler.instance)
        .subscribe(
            onNext: { [weak self] products in
                self?.products.accept(products)
                self?.assignDefaultProduct(products)
            }
        )
        .disposed(by: disposeBag)
    }

    private func assignDefaultProduct(_ products: [ApphudProduct]) {
        switch paywallType.value {
        case .first:
            defaultProduct.accept(products.first)
        case .second:
            defaultProduct.accept(products[safe: 1])
        }
    }
    
    public func submitPushNotificationsToken(deviceToken: Data) {
        Apphud.submitPushNotificationsToken(
            token: deviceToken,
            callback: nil
        )
    }
    
    @MainActor public func handlePushNotification(notification: UNNotification) {
        Apphud.handlePushNotification(
            apsInfo: notification.request.content.userInfo
        )
    }

    @MainActor public func purchase(product: ApphudProduct?) {
        guard config != nil else {
            print("PremiumManager is not configured. Call `configure(with:)` first.")
            return
        }

        if let product {
            Apphud.purchase(product) { [weak self] result in
                if result.error != nil {
                    self?.checkPremiumStatus()
                }
            }
        }
    }

    @MainActor public func restorePurchases() {
        guard let config = config else {
            print("PremiumManager is not configured. Call `configure(with:)` first.")
            return
        }

        if config.debugMode {
            isPremium.accept(true)
            return
        }

        Apphud.restorePurchases { [weak self] _, _, _ in
            self?.checkPremiumStatus()
        }
    }

    // MARK: - Private Methods
    private func checkPremiumStatus() {
        let status = Apphud.hasPremiumAccess()
        isPremium.accept(status)
    }
}

// MARK: - Safe Array Access
extension Array {
    public subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension ApphudProduct {

    public var duration: PremiumDuration? {
        for duration in PremiumDuration.allCases {
            if productId.lowercased().contains(duration.rawValue.lowercased()) {
                return duration
            }
        }
        return .week
    }

    public var priceNumber: Double? {
        guard let config = PremiumManager.shared.config else {
            return nil
        }

        if config.debugMode {
            switch duration {
            case .week: return 4.99
            case .month: return 9.99
            case .year: return 39.99
            case .day: return 1.99
            default: return 5.99
            }
        }
        guard let value = skProduct?.price as? Double else {
            return nil
        }
        return value
    }

    public var price: String? {
        guard let config = PremiumManager.shared.config else {
            return nil
        }

        if config.debugMode {
            return "$2.29"
        }
        guard let value = skProduct?.price.stringValue else {
            return nil
        }
        return "\(currency)\(value)"
    }

    public var currency: String {
        return skProduct?.priceLocale.currencySymbol ?? "$"
    }

    public var trialPeriodDays: Int? {
        guard let trial = skProduct?.introductoryPrice else { return nil }
        return daysForSubscriptionPeriod(trial.subscriptionPeriod)
    }

    public func daysForSubscriptionPeriod(_ period: SKProductSubscriptionPeriod) -> Int {
        switch period.unit {
        case .day:
            return period.numberOfUnits
        case .week:
            return period.numberOfUnits * 7
        case .month:
            return period.numberOfUnits * 30
        case .year:
            return period.numberOfUnits * 365
        @unknown default:
            return 0
        }
    }
}

public enum PremiumDuration: String, CaseIterable {
    case week = "week"
    case month = "month"
    case year = "year"
    case day = "day"
    case quarter = "quarter"

    public var longDescription: String {
        switch self {
        case .week: return "weekly"
        case .month: return "monthly"
        case .year: return "yearly"
        case .day: return "daily"
        case .quarter: return "quarterly"
        }
    }
}
