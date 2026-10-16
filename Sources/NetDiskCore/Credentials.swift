import Foundation

public struct Credentials: Sendable {
    public let cookie: String
    public let bduss: String
    public init(raw: String) throws {
        let parts = raw.split(whereSeparator: { $0 == ";" || $0 == "\n" }).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let value = parts.first(where: { $0.hasPrefix("BDUSS=") }).map({ String($0.dropFirst(6)) }), !value.isEmpty,
              !raw.contains("\r") else {
            throw NetDiskError.message("请粘贴包含 BDUSS 的完整 Cookie。")
        }
        cookie = parts.joined(separator: "; ")
        bduss = value
    }
}
