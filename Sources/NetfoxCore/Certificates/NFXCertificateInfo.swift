//
//  NFXCertificateInfo.swift
//  netfox
//
//  D6: TLS certificate details of an HTTPS request, captured from the server
//  trust challenge of the internal session.
//

import Foundation
import Security

/// The server certificate of one HTTPS request. Dates are stored as `Date`; the UI formats them.
package struct NFXCertificateInfo: Sendable, Hashable {
    package let subjectSummary: String
    package let issuerSummary: String
    package let notValidBefore: Date?
    package let notValidAfter: Date?
    /// For example "RSA 2048-bit" or "ECDSA 256-bit".
    package let publicKeyDescription: String
    package let isSelfSigned: Bool
    package let chainLength: Int

    package init(
        subjectSummary: String,
        issuerSummary: String,
        notValidBefore: Date?,
        notValidAfter: Date?,
        publicKeyDescription: String,
        isSelfSigned: Bool,
        chainLength: Int
    ) {
        self.subjectSummary = subjectSummary
        self.issuerSummary = issuerSummary
        self.notValidBefore = notValidBefore
        self.notValidAfter = notValidAfter
        self.publicKeyDescription = publicKeyDescription
        self.isSelfSigned = isSelfSigned
        self.chainLength = chainLength
    }

    /// Reads the chain of a server trust (leaf first). nil when the trust has no certificates.
    package init?(trust: SecTrust) {
        let chain = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []
        self.init(chain: chain)
    }

    /// Builds the info from a certificate chain, leaf first.
    package init?(chain: [SecCertificate]) {
        guard let leaf = chain.first else { return nil }
        let subject = SecCertificateCopySubjectSummary(leaf) as String? ?? "Unknown"
        let selfSigned = Self.isSelfSigned(leaf)
        let issuer: String
        if chain.count > 1 {
            issuer = SecCertificateCopySubjectSummary(chain[1]) as String? ?? "Unknown"
        } else {
            issuer = selfSigned ? subject : "Unknown"
        }
        let validity = Self.validity(of: leaf)
        self.init(
            subjectSummary: subject,
            issuerSummary: issuer,
            notValidBefore: validity.notBefore,
            notValidAfter: validity.notAfter,
            publicKeyDescription: Self.publicKeyDescription(of: leaf),
            isSelfSigned: selfSigned,
            chainLength: chain.count
        )
    }

    // MARK: - Helpers

    /// Validity dates: the Security API on iOS 18 / macOS 15, the DER walk below that.
    package static func validity(of certificate: SecCertificate) -> (notBefore: Date?, notAfter: Date?) {
        if #available(iOS 18.0, macOS 15.0, *) {
            let notBefore = SecCertificateCopyNotValidBeforeDate(certificate) as Date?
            let notAfter = SecCertificateCopyNotValidAfterDate(certificate) as Date?
            if notBefore != nil || notAfter != nil {
                return (notBefore, notAfter)
            }
        }
        let der = SecCertificateCopyData(certificate) as Data
        let validity = NFXDERParser.validity(ofCertificate: der)
        return (validity?.notBefore, validity?.notAfter)
    }

    /// Self-signed when the normalized issuer equals the normalized subject.
    package static func isSelfSigned(_ certificate: SecCertificate) -> Bool {
        guard let issuer = SecCertificateCopyNormalizedIssuerSequence(certificate) as Data?,
              let subject = SecCertificateCopyNormalizedSubjectSequence(certificate) as Data? else {
            return false
        }
        return issuer == subject
    }

    /// "RSA 2048-bit", "ECDSA 256-bit", or "Unknown".
    package static func publicKeyDescription(of certificate: SecCertificate) -> String {
        guard let key = SecCertificateCopyKey(certificate),
              let attributes = SecKeyCopyAttributes(key) as? [String: Any] else {
            return "Unknown"
        }
        let type = attributes[kSecAttrKeyType as String] as? String ?? ""
        let bits = (attributes[kSecAttrKeySizeInBits as String] as? NSNumber)?.intValue ?? 0
        let algorithm: String?
        if type == (kSecAttrKeyTypeRSA as String) {
            algorithm = "RSA"
        } else if type == (kSecAttrKeyTypeECSECPrimeRandom as String) || type == (kSecAttrKeyTypeEC as String) {
            algorithm = "ECDSA"
        } else {
            algorithm = nil
        }
        switch (algorithm, bits) {
        case let (algorithm?, bits) where bits > 0: return "\(algorithm) \(bits)-bit"
        case let (algorithm?, _): return algorithm
        case let (nil, bits) where bits > 0: return "\(bits)-bit"
        default: return "Unknown"
        }
    }
}
