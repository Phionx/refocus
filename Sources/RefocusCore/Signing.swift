import Foundation
import Security

public enum Signing {
    public static func requirement(for url: URL) throws -> String {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), nil) == errSecSuccess else {
            throw RefocusError.invalid("Refocus's signature is invalid. Rebuild or reinstall the app.")
        }
        var requirement: SecRequirement?
        var text: CFString?
        guard SecCodeCopyDesignatedRequirement(code, [], &requirement) == errSecSuccess,
              let requirement, SecRequirementCopyString(requirement, [], &text) == errSecSuccess,
              let text else { throw RefocusError.invalid("Couldn't verify Refocus's code signature.") }
        return text as String
    }
}
