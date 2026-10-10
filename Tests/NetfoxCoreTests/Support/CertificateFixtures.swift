//
//  CertificateFixtures.swift
//  NetfoxCoreTests
//
//  DER certificates generated with openssl for the expiry parser tests.
//

import Foundation

enum CertificateFixtures {

    struct Fixture: Sendable {
        let name: String
        let note: String
        let base64: String
        /// Unix time of notBefore / notAfter, read with `openssl x509 -dates`.
        let notBefore: TimeInterval
        let notAfter: TimeInterval
        let isSelfSigned: Bool

        var der: Data { Data(base64Encoded: base64) ?? Data() }
    }

    /// self-signed, serial 0x01. notBefore Oct 10 06:33:18 2026 GMT, notAfter Nov 14 06:33:18 2027 GMT.
    static let serial01 = Fixture(
        name: "serial01",
        note: "self-signed, serial 0x01",
        base64: """
            MIIBnjCCAUSgAwIBAgIBATAKBggqhkjOPQQDAjAuMRYwFAYDVQQDDA1uZXRmb3gtcmV2aWV3MRQwEgYDVQQKDAtFeGFtcGxlIE9y\
            ZzAeFw0yNjEwMTAwNjMzMThaFw0yNzExMTQwNjMzMThaMC4xFjAUBgNVBAMMDW5ldGZveC1yZXZpZXcxFDASBgNVBAoMC0V4YW1w\
            bGUgT3JnMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEOfbs3IUFDoCRbWDI1bSEykIFPzwLd1zroyMMB732tlPgxjWnUsyBRtYA\
            Rbs0fpekPPJVvfSwJVf9T5mCJOqu/qNTMFEwHQYDVR0OBBYEFG8YUHh09WQbDWxK9vg6BC6XkbKsMB8GA1UdIwQYMBaAFG8YUHh0\
            9WQbDWxK9vg6BC6XkbKsMA8GA1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0EAwIDSAAwRQIgZnYVst0aSumH+OqsZhE8l8pINQZNbUXU\
            gTr828MxflQCIQC5ew5/tZ2/qZpuMcXCZKs2DYoOr8rdajPQNKoGPMELFQ==
            """,
        notBefore: 1791613998,
        notAfter: 1826173998,
        isSelfSigned: true
    )

    /// self-signed, serial 0x17 (the UTCTime tag byte). notBefore Oct 10 06:33:18 2026 GMT, notAfter Nov 14 06:33:18 2027 GMT.
    static let serial17 = Fixture(
        name: "serial17",
        note: "self-signed, serial 0x17 (the UTCTime tag byte)",
        base64: """
            MIIBnjCCAUSgAwIBAgIBFzAKBggqhkjOPQQDAjAuMRYwFAYDVQQDDA1uZXRmb3gtcmV2aWV3MRQwEgYDVQQKDAtFeGFtcGxlIE9y\
            ZzAeFw0yNjEwMTAwNjMzMThaFw0yNzExMTQwNjMzMThaMC4xFjAUBgNVBAMMDW5ldGZveC1yZXZpZXcxFDASBgNVBAoMC0V4YW1w\
            bGUgT3JnMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAERdgVYozrBYTIOojw7HsicRpfdfs76z4GvurQ/prr0WeibkId+3cYv0Sj\
            l9vtym2/Z7l95MkvahXuaNqTd1PmNKNTMFEwHQYDVR0OBBYEFGQ68yy3gse+3Z2s9vw1onpPoSkaMB8GA1UdIwQYMBaAFGQ68yy3\
            gse+3Z2s9vw1onpPoSkaMA8GA1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0EAwIDSAAwRQIgBaWtBpwmZgwL/f/rMWGVQVnusk4ZkNZy\
            E6ne2b25p2gCIQDfMiROXqaBs65p4GMaAO5XImhH8v1Fa5F5HPvyJn4Olw==
            """,
        notBefore: 1791613998,
        notAfter: 1826173998,
        isSelfSigned: true
    )

    /// self-signed, serial 0x4F17A3C2 (contains 0x17). notBefore Oct 10 06:33:18 2026 GMT, notAfter Nov 14 06:33:18 2027 GMT.
    static let serial4F17A3C2 = Fixture(
        name: "serial4F17A3C2",
        note: "self-signed, serial 0x4F17A3C2 (contains 0x17)",
        base64: """
            MIIBoTCCAUegAwIBAgIETxejwjAKBggqhkjOPQQDAjAuMRYwFAYDVQQDDA1uZXRmb3gtcmV2aWV3MRQwEgYDVQQKDAtFeGFtcGxl\
            IE9yZzAeFw0yNjEwMTAwNjMzMThaFw0yNzExMTQwNjMzMThaMC4xFjAUBgNVBAMMDW5ldGZveC1yZXZpZXcxFDASBgNVBAoMC0V4\
            YW1wbGUgT3JnMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEKptlxmw20Hq3e0TP9UGWzaK+HGpTJofB+O1P2AJWvIb8wE88HO8R\
            GH3+S3gyen9FMnLLD/HCWODat6P4OHFGmaNTMFEwHQYDVR0OBBYEFNkQ9cl3+XJNN18YRBmnWXpKYg+SMB8GA1UdIwQYMBaAFNkQ\
            9cl3+XJNN18YRBmnWXpKYg+SMA8GA1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0EAwIDSAAwRQIgJ+Yx6sUiZu60coOHgnoHBzT6b3Fx\
            rwJhS3Y3IfdnvFkCIQDheg7GUpUtCZDOaGDMmrI0U+KAartc7MW0fhgdAA2hww==
            """,
        notBefore: 1791613998,
        notAfter: 1826173998,
        isSelfSigned: true
    )

    /// self-signed EC P-256. notBefore Oct 10 07:26:55 2026 GMT, notAfter Nov  9 07:26:55 2026 GMT.
    static let probeEC = Fixture(
        name: "probeEC",
        note: "self-signed EC P-256",
        base64: """
            MIIBQzCB6gIJAIMq7FxI+1qYMAoGCCqGSM49BAMCMCoxFDASBgNVBAMMC3Byb2JlLmxvY2FsMRIwEAYDVQQKDAlQcm9iZSBPcmcw\
            HhcNMjYxMDEwMDcyNjU1WhcNMjYxMTA5MDcyNjU1WjAqMRQwEgYDVQQDDAtwcm9iZS5sb2NhbDESMBAGA1UECgwJUHJvYmUgT3Jn\
            MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAED2Byr4Mv0S5EqELI1W3xBTeryNQM/Qbxy2XM77+pwm3E8bAL6msy0bH17S0lhgAv\
            SibE/dPceDSvVnfY+FQl/TAKBggqhkjOPQQDAgNIADBFAiEA6UG3/fPUIjJL66LHgSl9kSvOtGAm+PsAkXnp7tJGIwgCIErvvdMy\
            EEr/mG1kVx2O5b1FwWGlWNTf80UdVPCOEAQy
            """,
        notBefore: 1791617215,
        notAfter: 1794209215,
        isSelfSigned: true
    )

    /// self-signed RSA. notBefore Oct 10 07:26:56 2026 GMT, notAfter Nov  9 07:26:56 2026 GMT.
    static let probeRSA = Fixture(
        name: "probeRSA",
        note: "self-signed RSA",
        base64: """
            MIICsDCCAZgCCQDSUoQ25m2HMTANBgkqhkiG9w0BAQsFADAaMRgwFgYDVQQDDA9yc2EucHJvYmUubG9jYWwwHhcNMjYxMDEwMDcy\
            NjU2WhcNMjYxMTA5MDcyNjU2WjAaMRgwFgYDVQQDDA9yc2EucHJvYmUubG9jYWwwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK\
            AoIBAQDR5uhjy+yKKfHsr8tBKrE+Xu6KNYgoEYuwofoo+Lh0E4PgJVZR1zO5Z1g45AiNiGjq5+ngzsp31+Wtl/yjx/9YcC+i6DiT\
            Z8agb3/57ktEd6clIPp/+d22EyWnjmZ7jL5+PONhy75hUiaEcPq+pBXhZzRNBtxAKi0+TN2lJrjQa5Xl54ku3CY0cxO+csU1gjLM\
            tTOUlWruV67Ib0xBpI6GLKamZWagxpO8/riJeNipj5G8CnDLauM4jjWFGF0FlYviFpQfhwkoUXbHeSOf6H6uw6aUdF2k6l00R+O8\
            g1cFyu+rolPyI6aH8Tvbx8xTrR15QtqTibixEWP+1JDNPqyTAgMBAAEwDQYJKoZIhvcNAQELBQADggEBAJ0Ly4JcK9IAKBN5/+br\
            xuqIIgz3TXGdkxAZzwwyi+EzjLgVmfnMbx9yqtqy7vLSdwP4b1oiDeUw0t1mW4unhQOs6wt2YG5+6BQHuHNVfttYMLCU6DAgZQ3a\
            RypsfUtn3WnmJDF4J9vUapd3maBmsTFW+Y13o+EW1bGxllob1Spibk7AqoQt5DxLfiYYZeitOl0S/iM2bnoI0jyMY1gaQGI+7CLt\
            zldiswqLG9qgZIlj0SASbcYM1cAJt1RBmOpHBoDThpFqCh9daljRn1xZJqvGhfxLLKGMAR2dpDCSxsb6xd8PG62NIkWPsW8gM0V5\
            9MBl9Wyf/AeGHF33ePFZ7DU=
            """,
        notBefore: 1791617216,
        notAfter: 1794209216,
        isSelfSigned: true
    )

    /// CA-signed EC leaf, serial 0x1717, notAfter in 2052 (GeneralizedTime). notBefore Oct 10 07:59:49 2026 GMT, notAfter Mar 27 07:59:49 2052 GMT.
    static let leafGeneralizedTime = Fixture(
        name: "leafGeneralizedTime",
        note: "CA-signed EC leaf, serial 0x1717, notAfter in 2052 (GeneralizedTime)",
        base64: """
            MIICYDCCAUigAwIBAgICFxcwDQYJKoZIhvcNAQELBQAwLzEXMBUGA1UEAwwObmV0Zm94IFRlc3QgQ0ExFDASBgNVBAoMC0V4YW1w\
            bGUgT3JnMCAXDTI2MTAxMDA3NTk0OVoYDzIwNTIwMzI3MDc1OTQ5WjAxMRkwFwYDVQQDDBBsZWFmLm5ldGZveC50ZXN0MRQwEgYD\
            VQQKDAtFeGFtcGxlIE9yZzBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABKQJ5zWQjC4FQTUBCqD67EO0yFI4+md5FeS74StP+SCx\
            JWEjjUeaPBjuiNdLbkMgZo3KU/PNfrrrRuLBNUYXZ/+jTTBLMAkGA1UdEwQCMAAwHQYDVR0OBBYEFPrqHCt15f6XgVr+Ab9F6UcW\
            5Mz6MB8GA1UdIwQYMBaAFG68HsYF+OUHKVD7nAZG4U66kVlRMA0GCSqGSIb3DQEBCwUAA4IBAQBmtXi4JdTfG59KnQcNCend0FmC\
            22BFwIe9o4P+ynfIo479xQWlYbFmZMlOBbDl0iSXKpnDeU9LgI84yQS3O1qIiysK2XZ9tK0uCj8c61V2enrOrKOlyhRpQC9GIGWD\
            Mf4e2gGk8APlC/26Kv2199aFV5kHq1OOMIDveXxS0N2PKDTkDmE8mWjFM4t+zb2P5/JKejA22Q8s8EU2SGoLKx1Te+N5t8oB9tib\
            B1wDoncN2MWJqX05rQnQX4htPwQBe/3mnbwU6kGjPeV+PFbK/B64bSfEpxNx0XTWuKatxabsHX96nLHNSTQipPkXzMnzzpjsDoAK\
            uAWVMCd/rGv3qbb9
            """,
        notBefore: 1791619189,
        notAfter: 2595139189,
        isSelfSigned: false
    )

    /// X.509 v1 (no [0] version field), serial 0x18 (the GeneralizedTime tag byte). notBefore Oct 10 07:59:56 2026 GMT, notAfter Nov 14 07:59:56 2027 GMT.
    static let versionOne = Fixture(
        name: "versionOne",
        note: "X.509 v1 (no [0] version field), serial 0x18 (the GeneralizedTime tag byte)",
        base64: """
            MIICpjCCAY4CARgwDQYJKoZIhvcNAQELBQAwGTEXMBUGA1UEAwwOdjEubmV0Zm94LnRlc3QwHhcNMjYxMDEwMDc1OTU2WhcNMjcx\
            MTE0MDc1OTU2WjAZMRcwFQYDVQQDDA52MS5uZXRmb3gudGVzdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAOL+3rc+\
            HgqUTCzXnwy7fRluVm79QACqEoQtH4V2bF5bxwUYadV5Qqw+Vncy6WVm8KmbaaEqzF40hptOB5Pvjt7r9JUvpy5j8Bfmhcr31Kuk\
            /WYU8sdR4WigkSRe+EtKtTTOvKcu6/93WzbpP8l9948sDVEgX4sFfGTs/zusLAZR7u69nbUsdha5Mak2cbuJz3jRPGyxF9lzh613\
            c9k75vWB5TMn8NNTaScllw3+InIDbfnxUK3R5sZ/FQNxQ49O3SiYZq8S1TvPIMR6mKQUJjoKc6XmYLlEDEm79O/p/h+ZaQilI9JV\
            pjbBDFa7hxUHl1XjZGfSsnc//ZT0TroiE9UCAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAP0xUyr1PyYaLj8jsFez+79lPc+jGe4iX\
            zQZZaz9xaF7hWTaigBUEhgDFjjqVO/uE/1eRIOCzp7g/n/NlC/aizRg5dkk+hYJX4npAuw5s7bzbjW7DzqOafLfbumPMAJ0QSwYY\
            o2FUq7uAybdfMmVWittR0dP+CO/gqpFasTuf/ABN4DM/e0SlzOZXDDMeCLuRu2jVp1zalb52oudKHfVwfaCfFbFAnIecSCgem568\
            RvM6j0ZiZRWh6C8dsOYyj63Rj6AG9TUhGtaSxupLVdOrtYJvwpAsnS5rEeBu6JTnA4jie14p7F4nbPzvTt6wFP0yUIzZvB6quQdy\
            QNpn+ABOxw==
            """,
        notBefore: 1791619196,
        notAfter: 1826179196,
        isSelfSigned: true
    )

    /// the CA that signed leafGeneralizedTime. notBefore Oct 10 07:59:49 2026 GMT, notAfter Oct  7 07:59:49 2036 GMT.
    static let testCA = Fixture(
        name: "testCA",
        note: "the CA that signed leafGeneralizedTime",
        base64: """
            MIIDPzCCAiegAwIBAgIUXwVZiF+rZ9kPTRHXFo7MNQDnzhMwDQYJKoZIhvcNAQELBQAwLzEXMBUGA1UEAwwObmV0Zm94IFRlc3Qg\
            Q0ExFDASBgNVBAoMC0V4YW1wbGUgT3JnMB4XDTI2MTAxMDA3NTk0OVoXDTM2MTAwNzA3NTk0OVowLzEXMBUGA1UEAwwObmV0Zm94\
            IFRlc3QgQ0ExFDASBgNVBAoMC0V4YW1wbGUgT3JnMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqm/K9ZdAetwHe/wP\
            i+Hf/t8z8XY/Ae+LNselhGA/Hv6Mr/6XzvEqrOjDMwnu7VuKAxss7QhCcLSPK3Wfr7Vwwx/S8TOXO+mUfrxxOUjszETPoYdHWTog\
            R7ZeZwzpiS47LZ52NLbv90efRtOI36KhTGHI8zWa48x33lIS49mFOpP5ozFscS9h7kvsFNXJH4/gMSfIoyhPo+lJDIYzsAcDib1i\
            RRhNQIFOcpcPrhLQouAZ7Smp2hure2Re+l+XAJPvncldLT+T5mDMGvnfFAK34ur5o3RfoU9yWnp4GqS2MCmWT0I71PCh0ybI/1xm\
            4haoaDfkCco0PqM6uRV4+Kq7lQIDAQABo1MwUTAdBgNVHQ4EFgQUbrwexgX45QcpUPucBkbhTrqRWVEwHwYDVR0jBBgwFoAUbrwe\
            xgX45QcpUPucBkbhTrqRWVEwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAnWwdySmXTRAKcjnuQ5vLPPWTYJJk\
            mTUkaM9mP+OABc/nxBvIkp/SMjfM3pqyIm8BC9fYIF7mb2JlTJbgryD7fnrUBiSGbDsNDj9AQCaoJ+N34pB5/CnXSxdI3oX/9Ccc\
            LYnUSIrAVl70k2xjiUB1E6m5OcpiVuokRfrUXYH2PZ2Gbo8UfkyNVFHxODmRffKWlmgYXUHlFkMToxhdz/mtGoh8ueBcyySV5PnV\
            afCEzymkOXB77+9Jeep7a4j5mvNe8buGWFCsHfI2WbVC2UEQzfif4aCvRuNedvMaciUQNg8fpkpyUySjeQIT/P0O1DNk6cNQjIza\
            Bhd1pQshJusGSw==
            """,
        notBefore: 1791619189,
        notAfter: 2106979189,
        isSelfSigned: true
    )

    static let all: [Fixture] = [serial01, serial17, serial4F17A3C2, probeEC, probeRSA, leafGeneralizedTime, versionOne, testCA]
}
