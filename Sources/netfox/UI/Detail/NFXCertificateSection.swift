//
//  NFXCertificateSection.swift
//  netfox
//
//  D6: the server certificate of an HTTPS request (when certificate capture is on).
//

#if os(iOS)
import NetfoxCore
import SwiftUI

struct NFXCertificateSection: View {
    let certificate: NFXCertificateInfo

    var body: some View {
        Section("TLS Certificate") {
            NFXValueRow(title: "Subject", value: certificate.subjectSummary)
            NFXValueRow(title: "Issuer", value: certificate.issuerSummary)
            if let notBefore = certificate.notValidBefore {
                NFXValueRow(title: "Valid From", value: notBefore.formatted(date: .abbreviated, time: .shortened))
            }
            if let notAfter = certificate.notValidAfter {
                NFXValueRow(title: "Expires", value: notAfter.formatted(date: .abbreviated, time: .shortened))
                if notAfter < .now {
                    Label("This certificate has expired", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.nfxRed)
                }
            }
            NFXValueRow(title: "Public Key", value: certificate.publicKeyDescription)
            NFXValueRow(title: "Chain Length", value: certificate.chainLength.formatted())
            LabeledContent("Self-Signed") {
                Label(
                    certificate.isSelfSigned ? "Yes" : "No",
                    systemImage: certificate.isSelfSigned ? "exclamationmark.triangle.fill" : "checkmark.shield.fill"
                )
                .foregroundStyle(certificate.isSelfSigned ? Color.nfxOrange : Color.nfxDarkGreen)
            }
        }
    }
}
#endif
