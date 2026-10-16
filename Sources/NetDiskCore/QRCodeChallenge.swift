import Foundation

public struct QRCodeChallenge: Sendable {
    public let sign: String
    public let image: Data
    public let expires: Date
}
