//
//  NFXClientThread.swift
//  netfox
//
//  P1-6: NSURLProtocol.h says the client "will answer the request on the same
//  thread that called" URLProtocol(_:didReceive:). The router's delegate queue
//  has no run loop, so the answer would never arrive. Challenges are therefore
//  forwarded on the thread that called startLoading, in its run loop modes
//  (as in Apple's CustomHTTPProtocol sample).
//

import Foundation

// @unchecked Sendable: both properties are immutable; NSThread can be referenced
// from any thread, and work is only ever scheduled onto it through its run loop.
final class NFXClientThread: @unchecked Sendable {

    private let thread: Thread
    private let modes: [String]

    /// Captures the current thread and run loop mode. Call it from startLoading.
    init() {
        thread = Thread.current
        var modes = [RunLoop.Mode.default.rawValue]
        if let current = RunLoop.current.currentMode, current != .default {
            modes.append(current.rawValue)
        }
        self.modes = modes
    }

    /// Runs `work` on the captured thread's run loop.
    func perform(_ work: @escaping @Sendable () -> Void) {
        let trampoline = Trampoline(work)
        trampoline.perform(#selector(Trampoline.run), on: thread, with: nil, waitUntilDone: false, modes: modes)
    }

    private final class Trampoline: NSObject {
        private let work: @Sendable () -> Void

        init(_ work: @escaping @Sendable () -> Void) {
            self.work = work
        }

        @objc func run() {
            work()
        }
    }
}

/// Carries a value the compiler cannot prove Sendable across one hop.
// @unchecked Sendable: used only to hand the URLProtocol instance (whose Sendable
// conformance is unavailable) to its own client thread; URLProtocol is designed for that.
struct NFXUncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
}
