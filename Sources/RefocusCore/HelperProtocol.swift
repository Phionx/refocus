import Foundation

public enum RefocusService {
    public static let name = "org.refocus.app.helper"
    public static let plist = name + ".plist"
}

@objc public protocol RefocusHelperProtocol {
    func disableBlocking(reply: @escaping (Data?, String?) -> Void)
    func readConfiguration(reply: @escaping (Data?, String?) -> Void)
    func applyConfiguration(_ data: Data, reply: @escaping (Data?, String?) -> Void)
}
