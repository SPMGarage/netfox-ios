//
//  NFXInfoView.swift
//  netfox
//
//  SwiftUI replacement for NFXInfoController_iOS
//

#if os(iOS)

import SwiftUI

struct NFXInfoView: View {
    @State private var ipAddress = "Retrieving..."

    var body: some View {
        ScrollView {
            NFXAttributedTextView(attributedText: generateInfoString(ipAddress))
                .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Info")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchIP()
        }
    }

    private func fetchIP() async {
        await withCheckedContinuation { continuation in
            NFXDebugInfo.getNFXIP { result in
                DispatchQueue.main.async {
                    ipAddress = result
                    continuation.resume()
                }
            }
        }
    }

    private func generateInfoString(_ ip: String) -> NSAttributedString {
        var temp = ""
        temp += "[App name] \n\(NFXDebugInfo.getNFXAppName())\n\n"
        temp += "[App version] \n\(NFXDebugInfo.getNFXAppVersionNumber()) (build \(NFXDebugInfo.getNFXAppBuildNumber()))\n\n"
        temp += "[App bundle identifier] \n\(NFXDebugInfo.getNFXBundleIdentifier())\n\n"
        temp += "[Device OS] \niOS \(NFXDebugInfo.getNFXOSVersion())\n\n"
        temp += "[Device type] \n\(NFXDebugInfo.getNFXDeviceType())\n\n"
        temp += "[Device screen resolution] \n\(NFXDebugInfo.getNFXDeviceScreenResolution())\n\n"
        temp += "[Device IP address] \n\(ip)\n\n"
        return NFXTextFormatter.formatNFXString(temp)
    }
}

#endif
