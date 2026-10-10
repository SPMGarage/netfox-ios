//
//  NFXAuthenticationChallengeSender.swift
//  netfox
//
//  Created by Nathan Jangula on 3/5/18.
//  Copyright © 2018 kasketis. All rights reserved.
//
//  Turns the host app's answer to a forwarded challenge back into the
//  completion handler of the internal session.
//

import Foundation

final class NFXAuthenticationChallengeSender: NSObject, URLAuthenticationChallengeSender {

    typealias Handler = @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void

    private let handler: Handler

    init(handler: @escaping Handler) {
        self.handler = handler
        super.init()
    }

    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {
        handler(.useCredential, credential)
    }

    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {
        handler(.useCredential, nil)
    }

    func cancel(_ challenge: URLAuthenticationChallenge) {
        handler(.cancelAuthenticationChallenge, nil)
    }

    func performDefaultHandling(for challenge: URLAuthenticationChallenge) {
        handler(.performDefaultHandling, nil)
    }

    func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) {
        handler(.rejectProtectionSpace, nil)
    }
}
