import CryptoKit
import Foundation

public enum LocateSignature {
    static func hex<S: Sequence>(_ bytes: S) -> String where S.Element == UInt8 {
        bytes.map { ($0 < 16 ? "0" : "") + String($0, radix: 16) }.joined()
    }
    public static func parameters(bduss: String, uid: UInt64, time: Int64) -> [String: String] {
        let devuid = hex(Insecure.MD5.hash(data: Data(bduss.utf8))).uppercased() + "|0"
        let hash = hex(Insecure.SHA1.hash(data: Data(bduss.utf8)))
        let source = hash + String(uid) + "ebrcUYiuxaZv2XGu7KIYKxUrqfnOfpDF" + String(time) + devuid
        return ["time": String(time), "rand": hex(Insecure.SHA1.hash(data: Data(source.utf8))), "devuid": devuid, "cuid": devuid]
    }
    public static func md5(_ data: Data) -> String { hex(Insecure.MD5.hash(data: data)) }
}
