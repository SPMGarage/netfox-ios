//
//  NFXStatusAppearance.swift
//  netfox
//
//  Colors and VoiceOver text for a record's outcome, shared by the list and the picker.
//

#if os(iOS)
import NetfoxCore
import SwiftUI

/// How a record's outcome looks: green when it succeeded, red when it failed, gray without a response.
nonisolated struct NFXStatusAppearance: Sendable {

    nonisolated enum Outcome: Sendable {
        case succeeded
        case failed
        case noResponse
    }

    let outcome: Outcome

    init(_ record: NFXRecord) {
        if !record.hasResponse {
            outcome = .noResponse
        } else {
            outcome = record.isSuccess ? .succeeded : .failed
        }
    }

    /// VoiceOver text of the status dot.
    var accessibilityLabel: String {
        switch outcome {
        case .succeeded: "Succeeded"
        case .failed: "Failed"
        case .noResponse: "No response"
        }
    }

    /// Fill of the status dot.
    var dotColor: Color {
        switch outcome {
        case .succeeded: .nfxGreen
        case .failed: .nfxRed
        case .noResponse: .secondary
        }
    }

    /// Text color of the method badge and the status code.
    var textColor: Color {
        switch outcome {
        case .succeeded: .nfxDarkGreen
        case .failed: .nfxRed
        case .noResponse: .secondary
        }
    }

    /// Fill behind the method badge.
    var badgeFill: Color {
        switch outcome {
        case .succeeded: Color.nfxGreen.opacity(0.15)
        case .failed: Color.nfxRed.opacity(0.15)
        case .noResponse: Color(uiColor: .systemGray5)
        }
    }
}
#endif
