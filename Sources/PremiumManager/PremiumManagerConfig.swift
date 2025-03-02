import Foundation

public struct PremiumManagerConfig {
    public let apiKey: String
    public let debugMode: Bool

    public init(apiKey: String, debugMode: Bool = false) {
        self.apiKey = apiKey
        self.debugMode = debugMode
    }
}
