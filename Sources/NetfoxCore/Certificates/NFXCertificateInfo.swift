//
//  NFXCertificateInfo.swift
//  netfox
//
//  D6: TLS certificate info capture and storage.
//  Uses associated objects on NFXHTTPModel to avoid modifying the @objc model.
//

#if os(iOS)

import Foundation
import Security

// MARK: - Certificate Info Model

struct NFXCertificateInfo {
    let subject: String
    let issuer: String
    let expiryDate: String
    let publicKeyAlgorithm: String
    let isSelfSigned: Bool
    let chainLength: Int

    init(from serverTrust: SecTrust) {
        let certCount = SecTrustGetCertificateCount(serverTrust)

        // Build cert chain using iOS 15-compatible API
        var chain = [SecCertificate]()
        for i in 0..<certCount {
            if let cert = SecTrustGetCertificateAtIndex(serverTrust, i) {
                chain.append(cert)
            }
        }

        guard let leafCert = chain.first else {
            self.subject = "Unknown"
            self.issuer = "Unknown"
            self.expiryDate = "Unknown"
            self.publicKeyAlgorithm = "Unknown"
            self.isSelfSigned = false
            self.chainLength = 0
            return
        }

        self.chainLength = certCount

        // Subject from leaf certificate
        let summary = SecCertificateCopySubjectSummary(leafCert) as String? ?? "Unknown"
        self.subject = summary

        // Issuer from second cert in chain (the CA that signed the leaf)
        if chain.count > 1 {
            let issuerCert = chain[1]
            self.issuer = SecCertificateCopySubjectSummary(issuerCert) as String? ?? "Unknown"
        } else {
            self.issuer = summary // self-signed
        }

        // Public key info
        if let publicKey = SecCertificateCopyKey(leafCert) {
            let keyAttrs = SecKeyCopyAttributes(publicKey) as? [String: Any]
            let keyType = keyAttrs?[kSecAttrKeyType as String] as? String ?? ""
            let keySize = keyAttrs?[kSecAttrKeySizeInBits as String] as? Int ?? 0

            let algorithm: String
            if keyType.contains("RSA") || keyType == (kSecAttrKeyTypeRSA as String) {
                algorithm = "RSA \(keySize)-bit"
            } else if keyType.contains("EC") || keyType == (kSecAttrKeyTypeECSECPrimeRandom as String) {
                algorithm = "ECDSA \(keySize)-bit"
            } else if keySize > 0 {
                algorithm = "\(keySize)-bit"
            } else {
                algorithm = "Unknown"
            }
            self.publicKeyAlgorithm = algorithm
        } else {
            self.publicKeyAlgorithm = "Unknown"
        }

        // Expiry: parse from DER data (best effort)
        // iOS doesn't expose cert dates directly — use the certificate's DER data
        let derData = SecCertificateCopyData(leafCert) as Data
        self.expiryDate = NFXCertificateInfo.parseExpiryFromDER(derData) ?? "N/A"

        // Self-signed: only one cert in chain
        self.isSelfSigned = (certCount == 1)
    }

    // Best-effort expiry date extraction from X.509 DER-encoded certificate
    // Looks for the ASN.1 UTCTime or GeneralizedTime pattern
    private static func parseExpiryFromDER(_ data: Data) -> String? {
        let bytes = [UInt8](data)
        // Find the second time value in the TBS certificate (validity: notBefore, notAfter)
        var timeCount = 0
        var i = 0
        while i < bytes.count - 2 {
            // UTCTime tag = 0x17, GeneralizedTime tag = 0x18
            if bytes[i] == 0x17 || bytes[i] == 0x18 {
                let isUTC = bytes[i] == 0x17
                let length = Int(bytes[i + 1])
                if length > 0 && i + 2 + length <= bytes.count {
                    timeCount += 1
                    if timeCount == 2 { // second time = notAfter
                        let timeData = Data(bytes[(i + 2)..<(i + 2 + length)])
                        if let timeString = String(data: timeData, encoding: .ascii) {
                            return formatCertDate(timeString, isUTC: isUTC)
                        }
                    }
                }
            }
            i += 1
        }
        return nil
    }

    private static func formatCertDate(_ raw: String, isUTC: Bool) -> String? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        if isUTC {
            // UTCTime: YYMMDDHHMMSSZ
            formatter.dateFormat = "yyMMddHHmmss'Z'"
        } else {
            // GeneralizedTime: YYYYMMDDHHMMSSZ
            formatter.dateFormat = "yyyyMMddHHmmss'Z'"
        }
        formatter.timeZone = TimeZone(identifier: "UTC")

        if let date = formatter.date(from: raw) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .short
            return display.string(from: date)
        }
        return raw
    }
}

// MARK: - Associated Object on NFXHTTPModel

private var certificateInfoKey: UInt8 = 0

extension NFXHTTPModel {
    var certificateInfo: NFXCertificateInfo? {
        get { objc_getAssociatedObject(self, &certificateInfoKey) as? NFXCertificateInfo }
        set { objc_setAssociatedObject(self, &certificateInfoKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

#endif
