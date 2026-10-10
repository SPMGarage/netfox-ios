//
//  NetfoxDemoApp.swift
//  NetfoxDemo
//
//  Small host app for trying netfox, running UI checks and recording README GIFs.
//

import SwiftUI
import netfox

@main
struct NetfoxDemoApp: App {

    init() {
        #if DEBUG
        NFX.sharedInstance().start()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            DemoView()
        }
    }
}
