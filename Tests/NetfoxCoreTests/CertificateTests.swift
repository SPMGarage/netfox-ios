//
//  CertificateTests.swift
//  NetfoxCoreTests
//
//  P0-4: validity dates come from the X.509 structure, not from byte scanning.
//

import Foundation
@testable import NetfoxCore
import Security
import Testing

@Suite("Certificate info")
struct CertificateTests {

    @Test("DER walk reads notBefore / notAfter", arguments: CertificateFixtures.all)
    func derValidity(_ fixture: CertificateFixtures.Fixture) throws {
        let validity = try #require(NFXDERParser.validity(ofCertificate: fixture.der), "\(fixture.name)")
        #expect(validity.notBefore.timeIntervalSince1970 == fixture.notBefore, "\(fixture.name)")
        #expect(validity.notAfter.timeIntervalSince1970 == fixture.notAfter, "\(fixture.name)")
    }

    @Test("a serial number containing 0x17 does not shift the expiry date")
    func serialWithUTCTimeTag() throws {
        let fixture = CertificateFixtures.serial17
        let validity = try #require(NFXDERParser.validity(ofCertificate: fixture.der))
        // 14 Nov 2027 06:33:18 UTC, not the issue date
        #expect(validity.notAfter == Date(timeIntervalSince1970: 1_826_173_998))
        #expect(validity.notAfter != validity.notBefore)
    }

    @Test("NFXCertificateInfo: dates, self-signed check and key description", arguments: CertificateFixtures.all)
    func certificateInfo(_ fixture: CertificateFixtures.Fixture) throws {
        let certificate = try #require(SecCertificateCreateWithData(nil, fixture.der as CFData), "\(fixture.name)")
        let info = try #require(NFXCertificateInfo(chain: [certificate]))
        #expect(info.notValidAfter?.timeIntervalSince1970 == fixture.notAfter, "\(fixture.name)")
        #expect(info.notValidBefore?.timeIntervalSince1970 == fixture.notBefore, "\(fixture.name)")
        #expect(info.isSelfSigned == fixture.isSelfSigned, "\(fixture.name)")
        #expect(info.chainLength == 1)
        #expect(info.publicKeyDescription.hasPrefix("RSA") || info.publicKeyDescription.hasPrefix("ECDSA"))
    }

    @Test("a CA-signed leaf names its issuer from the chain")
    func issuerFromChain() throws {
        let leaf = try #require(SecCertificateCreateWithData(nil, CertificateFixtures.leafGeneralizedTime.der as CFData))
        let ca = try #require(SecCertificateCreateWithData(nil, CertificateFixtures.testCA.der as CFData))
        let info = try #require(NFXCertificateInfo(chain: [leaf, ca]))
        #expect(info.subjectSummary == "leaf.netfox.test")
        #expect(info.issuerSummary == "netfox Test CA")
        #expect(info.isSelfSigned == false)
        #expect(info.chainLength == 2)
        #expect(info.publicKeyDescription == "ECDSA 256-bit")
    }

    @Test("malformed input gives nil, not a wrong date")
    func malformed() throws {
        #expect(NFXDERParser.validity(ofCertificate: Data()) == nil)
        #expect(NFXDERParser.validity(ofCertificate: Data([0x30, 0x82, 0xFF])) == nil)
        let truncated = CertificateFixtures.serial17.der.prefix(60)
        #expect(NFXDERParser.validity(ofCertificate: Data(truncated)) == nil)
    }
}
