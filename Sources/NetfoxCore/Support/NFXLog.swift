//
//  NFXLog.swift
//  netfox
//
//  P2-10: every diagnostic goes through os.Logger. netfox never prints to stdout.
//

import os

/// The loggers netfox uses internally, one per category.
package enum NFXLog {
    package static let subsystem = "uz.azimjondev.netfox"

    /// start / stop and other facade events.
    package static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    /// URLProtocol, session router and swizzling.
    package static let interception = Logger(subsystem: subsystem, category: "interception")
    /// Body files, session log and exports.
    package static let storage = Logger(subsystem: subsystem, category: "storage")
    /// D4: opt-in console logging of every captured request.
    package static let console = Logger(subsystem: subsystem, category: "network")
    /// Inspector presentation.
    package static let ui = Logger(subsystem: subsystem, category: "ui")
}
