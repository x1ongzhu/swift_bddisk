import Foundation

public enum NetDiskError: LocalizedError {
    case message(String)
    public var errorDescription: String? {
        switch self { case .message(let text): text }
    }
}
