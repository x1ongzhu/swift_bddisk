import Foundation

public enum QRCodeStatus: Equatable, Sendable {
    case waiting, scanned, expired
    case confirmed(String)

    public static func decode(_ data: Data) throws -> Self {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetDiskError.message("扫码状态返回格式异常。")
        }
        if let code = object["errno"] as? Int, code != 0 { throw NetDiskError.message("扫码状态查询失败，请刷新二维码。") }
        guard let text = object["channel_v"] as? String else { return .waiting }
        guard let channel = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else {
            throw NetDiskError.message("扫码状态返回格式异常。")
        }
        if let code = channel["v"] as? String, !code.isEmpty { return .confirmed(code) }
        switch channel["status"] as? Int ?? 0 {
        case 0: return .waiting
        case 1: return .scanned
        case -1, -2: return .expired
        default: throw NetDiskError.message("登录状态异常，请刷新二维码。")
        }
    }
}
