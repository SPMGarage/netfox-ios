//
//  NFXHelper.swift
//  netfox
//
//  Copyright © 2016 netfox. All rights reserved.
//

import Foundation
#if os(OSX)
import Cocoa
#else
import UIKit
#endif

// MARK: - HTTP Model Short Type

public enum HTTPModelShortType: String, CaseIterable {
    case JSON = "JSON"
    case XML = "XML"
    case HTML = "HTML"
    case IMAGE = "Image"
    case OTHER = "Other"
}

public extension HTTPModelShortType {
    init(contentType: String) {
        let lowered = contentType.lowercased()
        if lowered.contains("json") {
            self = .JSON
        } else if lowered == "application/xml" || lowered == "text/xml" {
            self = .XML
        } else if lowered == "text/html" {
            self = .HTML
        } else if lowered.hasPrefix("image/") {
            self = .IMAGE
        } else {
            self = .OTHER
        }
    }
}

// MARK: - Colors (Dynamic for Dark Mode)

extension NFXColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        self.init(
            red: CGFloat(red) / 255.0,
            green: CGFloat(green) / 255.0,
            blue: CGFloat(blue) / 255.0,
            alpha: 1.0
        )
    }

    convenience init(netHex: Int) {
        self.init(red: (netHex >> 16) & 0xff, green: (netHex >> 8) & 0xff, blue: netHex & 0xff)
    }

    #if os(iOS)
    // Accent / tint color
    static func NFXOrangeColor() -> NFXColor {
        return UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(netHex: 0xF28C5E)
                : UIColor(netHex: 0xEC5E28)
        }
    }

    // Success status
    static func NFXGreenColor() -> NFXColor {
        return UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(netHex: 0x4CD6A8)
                : UIColor(netHex: 0x38BB93)
        }
    }

    static func NFXDarkGreenColor() -> NFXColor {
        return UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(netHex: 0x38BB93)
                : UIColor(netHex: 0x2D7C6E)
        }
    }

    // Error status
    static func NFXRedColor() -> NFXColor {
        return UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(netHex: 0xE8705A)
                : UIColor(netHex: 0xD34A33)
        }
    }

    static func NFXDarkRedColor() -> NFXColor {
        return UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(netHex: 0xD34A33)
                : UIColor(netHex: 0x643026)
        }
    }

    // Backgrounds
    static func NFXBackgroundColor() -> NFXColor {
        return UIColor.systemBackground
    }

    static func NFXSecondaryBackgroundColor() -> NFXColor {
        return UIColor.secondarySystemBackground
    }

    static func NFXGroupedBackgroundColor() -> NFXColor {
        return UIColor.systemGroupedBackground
    }

    // Text
    static func NFXPrimaryTextColor() -> NFXColor {
        return UIColor.label
    }

    static func NFXSecondaryTextColor() -> NFXColor {
        return UIColor.secondaryLabel
    }

    static func NFXTertiaryTextColor() -> NFXColor {
        return UIColor.tertiaryLabel
    }

    // Separator
    static func NFXSeparatorColor() -> NFXColor {
        return UIColor.separator
    }

    // Status bar background
    static func NFXStatusBarBackgroundColor() -> NFXColor {
        return UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(netHex: 0x1C1C1E)
                : UIColor(netHex: 0xF2F2F7)
        }
    }

    #elseif os(OSX)
    static func NFXOrangeColor() -> NFXColor {
        return NFXColor(netHex: 0xEC5E28)
    }

    static func NFXGreenColor() -> NFXColor {
        return NFXColor(netHex: 0x38BB93)
    }

    static func NFXDarkGreenColor() -> NFXColor {
        return NFXColor(netHex: 0x2D7C6E)
    }

    static func NFXRedColor() -> NFXColor {
        return NFXColor(netHex: 0xD34A33)
    }

    static func NFXDarkRedColor() -> NFXColor {
        return NFXColor(netHex: 0x643026)
    }
    #endif

    // Legacy aliases kept for OSX compatibility
    static func NFXStarkWhiteColor() -> NFXColor {
        #if os(iOS)
        return NFXSecondaryBackgroundColor()
        #else
        return NFXColor(netHex: 0xCCC5B9)
        #endif
    }

    static func NFXDarkStarkWhiteColor() -> NFXColor {
        #if os(iOS)
        return UIColor.tertiarySystemFill
        #else
        return NFXColor(netHex: 0x9B958D)
        #endif
    }

    static func NFXLightGrayColor() -> NFXColor {
        #if os(iOS)
        return UIColor.separator
        #else
        return NFXColor(netHex: 0x9B9B9B)
        #endif
    }

    static func NFXGray44Color() -> NFXColor {
        #if os(iOS)
        return UIColor.secondaryLabel
        #else
        return NFXColor(netHex: 0x707070)
        #endif
    }

    static func NFXGray95Color() -> NFXColor {
        #if os(iOS)
        return UIColor.systemGroupedBackground
        #else
        return NFXColor(netHex: 0xF2F2F2)
        #endif
    }

    static func NFXBlackColor() -> NFXColor {
        #if os(iOS)
        return UIColor.label
        #else
        return NFXColor(netHex: 0x231F20)
        #endif
    }
}

// MARK: - Fonts (System Fonts)

extension NFXFont {
    #if os(iOS)
    static func NFXFont(size: CGFloat) -> UIFont {
        return .systemFont(ofSize: size)
    }

    static func NFXFontBold(size: CGFloat) -> UIFont {
        return .boldSystemFont(ofSize: size)
    }

    static func NFXFontMedium(size: CGFloat) -> UIFont {
        return .systemFont(ofSize: size, weight: .medium)
    }

    static func NFXMonoFont(size: CGFloat) -> UIFont {
        if let mono = UIFont(name: "SFMono-Regular", size: size) {
            return mono
        }
        return .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    #elseif os(OSX)
    static func NFXFont(size: CGFloat) -> NSFont {
        return .systemFont(ofSize: size)
    }

    static func NFXFontBold(size: CGFloat) -> NSFont {
        return .boldSystemFont(ofSize: size)
    }
    #endif
}

// MARK: - URLRequest Extensions

extension URLRequest {
    func getNFXURL() -> String {
        return url?.absoluteString ?? "-"
    }

    func getNFXURLComponents() -> URLComponents? {
        guard let url = self.url else { return nil }
        return URLComponents(string: url.absoluteString)
    }

    func getNFXMethod() -> String {
        return httpMethod ?? "-"
    }

    func getNFXCachePolicy() -> String {
        switch cachePolicy {
        case .useProtocolCachePolicy: return "UseProtocolCachePolicy"
        case .reloadIgnoringLocalCacheData: return "ReloadIgnoringLocalCacheData"
        case .reloadIgnoringLocalAndRemoteCacheData: return "ReloadIgnoringLocalAndRemoteCacheData"
        case .returnCacheDataElseLoad: return "ReturnCacheDataElseLoad"
        case .returnCacheDataDontLoad: return "ReturnCacheDataDontLoad"
        case .reloadRevalidatingCacheData: return "ReloadRevalidatingCacheData"
        @unknown default: return "Unknown \(cachePolicy)"
        }
    }

    func getNFXTimeout() -> String {
        return String(Double(timeoutInterval))
    }

    func getNFXHeaders() -> [AnyHashable: Any] {
        return allHTTPHeaderFields ?? [:]
    }

    func getNFXBody() -> Data {
        return httpBodyStream?.readfully()
            ?? URLProtocol.property(forKey: "NFXBodyData", in: self) as? Data
            ?? Data()
    }

    func getCurl() -> String {
        guard let url = url else { return "" }
        let baseCommand = "curl \"\(url.absoluteString)\""

        var command = [baseCommand]

        if let method = httpMethod {
            command.append("-X \(method)")
        }

        for (key, value) in getNFXHeaders() {
            command.append("-H \u{22}\(key): \(value)\u{22}")
        }

        if let body = String(data: getNFXBody(), encoding: .utf8), !body.isEmpty {
            command.append("-d \u{22}\(body)\u{22}")
        }

        return command.joined(separator: " ")
    }
}

// MARK: - URLResponse Extensions

extension URLResponse {
    func getNFXStatus() -> Int {
        return (self as? HTTPURLResponse)?.statusCode ?? 999
    }

    func getNFXHeaders() -> [AnyHashable: Any] {
        return (self as? HTTPURLResponse)?.allHeaderFields ?? [:]
    }
}

// MARK: - Images (SF Symbols on iOS 14+)

extension NFXImage {
    #if os(iOS)
    static func NFXSettings() -> NFXImage {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        return UIImage(systemName: "gearshape", withConfiguration: config) ?? UIImage()
    }

    static func NFXClose() -> NFXImage {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        return UIImage(systemName: "xmark", withConfiguration: config) ?? UIImage()
    }

    static func NFXInfo() -> NFXImage {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        return UIImage(systemName: "info.circle", withConfiguration: config) ?? UIImage()
    }

    static func NFXStatistics() -> NFXImage {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        return UIImage(systemName: "chart.bar", withConfiguration: config) ?? UIImage()
    }

    static func NFXTrash() -> NFXImage {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        return UIImage(systemName: "trash", withConfiguration: config) ?? UIImage()
    }

    static func NFXShare() -> NFXImage {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        return UIImage(systemName: "square.and.arrow.up", withConfiguration: config) ?? UIImage()
    }

    static func NFXCopy() -> NFXImage {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        return UIImage(systemName: "doc.on.doc", withConfiguration: config) ?? UIImage()
    }
    #elseif os(OSX)
    static func NFXSettings() -> NFXImage {
        return NSImage(data: NFXAssets.getImage(NFXAssetName.settings)) ?? NSImage()
    }

    static func NFXClose() -> NFXImage {
        return NSImage(data: NFXAssets.getImage(NFXAssetName.close)) ?? NSImage()
    }

    static func NFXInfo() -> NFXImage {
        return NSImage(data: NFXAssets.getImage(NFXAssetName.info)) ?? NSImage()
    }

    static func NFXStatistics() -> NFXImage {
        return NSImage(data: NFXAssets.getImage(NFXAssetName.statistics)) ?? NSImage()
    }
    #endif
}

// MARK: - InputStream

extension InputStream {
    func readfully() -> Data {
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)

        open()

        var amount = 0
        repeat {
            amount = read(&buffer, maxLength: buffer.count)
            if amount > 0 {
                result.append(buffer, count: amount)
            }
        } while amount > 0

        close()

        return result
    }
}

// MARK: - Debug Info

struct NFXDebugInfo {

    static func getNFXAppName() -> String {
        return Bundle.main.infoDictionary?["CFBundleName"] as? String ?? ""
    }

    static func getNFXAppVersionNumber() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    static func getNFXAppBuildNumber() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    static func getNFXBundleIdentifier() -> String {
        return Bundle.main.bundleIdentifier ?? ""
    }

    static func getNFXOSVersion() -> String {
        #if os(iOS)
        return UIDevice.current.systemVersion
        #elseif os(OSX)
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    static func getNFXDeviceType() -> String {
        #if os(iOS)
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = systemInfo.machine
        let mirror = Mirror(reflecting: machine)
        var identifier = ""
        for child in mirror.children {
            if let value = child.value as? Int8, value != 0 {
                identifier.append(String(UnicodeScalar(UInt8(value))))
            }
        }
        return identifier
        #elseif os(OSX)
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    static func getNFXDeviceScreenResolution() -> String {
        #if os(iOS)
        let scale = UIScreen.main.scale
        let bounds = UIScreen.main.bounds
        let width = bounds.size.width * scale
        let height = bounds.size.height * scale
        return "\(Int(width)) x \(Int(height))"
        #elseif os(OSX)
        return "N/A"
        #endif
    }

    static func getNFXIP(completion: @escaping (_ result: String) -> Void) {
        var request = URLRequest(url: URL(string: "https://api.ipify.org/?format=json")!)
        request.timeoutInterval = 5
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: NFXProtocol.nfxInternalKey, in: mutableRequest)

        URLSession.shared.dataTask(with: mutableRequest as URLRequest) { data, _, error in
            guard error == nil,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ip = json["ip"] as? String else {
                completion("-")
                return
            }
            completion(ip)
        }.resume()
    }
}

// MARK: - NFX Path

struct NFXPath {

    static let sessionLogName = "session.log"
    static let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    static let nfxDirURL = tmpDirURL.appendingPathComponent("NFX", isDirectory: true)
    static let sessionLogURL = nfxDirURL.appendingPathComponent(sessionLogName)

    static func createNFXDirIfNotExist() {
        do {
            try FileManager.default.createDirectory(at: nfxDirURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("[NFX]: failed to create working dir - \(error.localizedDescription)")
        }
    }

    static func deleteNFXDir() {
        guard FileManager.default.fileExists(atPath: nfxDirURL.path) else { return }
        do {
            try FileManager.default.removeItem(at: nfxDirURL)
        } catch {
            print("[NFX]: failed to delete working dir - \(error.localizedDescription)")
        }
    }

    static func deleteOldNFXLogs() {
        let oldSessionLogName = "session.log"
        let oldRequestPrefixName = "nfx_re"
        let fileManager = FileManager.default
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
              let fileEnumerator = fileManager.enumerator(
                  at: documentsDir,
                  includingPropertiesForKeys: nil,
                  options: [.skipsSubdirectoryDescendants],
                  errorHandler: nil
              ) else { return }

        for case let fileURL as URL in fileEnumerator {
            if fileURL.lastPathComponent == oldSessionLogName || fileURL.lastPathComponent.hasPrefix(oldRequestPrefixName) {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }

    static func pathURLToFile(_ fileName: String) -> URL {
        return nfxDirURL.appendingPathComponent(fileName)
    }
}

// MARK: - String File Writing

extension String {

    func appendToFileURL(_ fileURL: URL) {
        guard let fileHandle = try? FileHandle(forWritingTo: fileURL) else {
            writeToFile(fileURL)
            return
        }

        guard let data = data(using: .utf8) else { return }

        if #available(iOS 13.4, macOS 10.15.4, *) {
            do {
                try fileHandle.seekToEnd()
                try fileHandle.write(contentsOf: data)
            } catch {
                print("[NFX]: Failed to append to \(fileURL) - \(error.localizedDescription)")
                writeToFile(fileURL)
            }
        } else {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
        }
    }

    private func writeToFile(_ fileURL: URL) {
        do {
            try write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("[NFX]: Failed to save to \(fileURL) - \(error.localizedDescription)")
        }
    }
}

// MARK: - URLSessionConfiguration Swizzling

private var nfxExemptConfigKey: UInt8 = 0

@objc extension URLSessionConfiguration {
    private static var firstOccurrence = true

    static func implementNetfox() {
        guard firstOccurrence else { return }
        firstOccurrence = false

        swizzleProtocolSetter()
        swizzleProtocolGetter()
        swizzleDefault()
        swizzleEphemeral()
    }

    // MARK: - Setter swizzle (de-duplication)

    private static func swizzleProtocolSetter() {
        let instance = URLSessionConfiguration.default
        let aClass: AnyClass = object_getClass(instance)!

        let origSelector = #selector(setter: URLSessionConfiguration.protocolClasses)
        let newSelector = #selector(setter: URLSessionConfiguration.protocolClasses_Swizzled)

        guard let origMethod = class_getInstanceMethod(aClass, origSelector),
              let newMethod = class_getInstanceMethod(aClass, newSelector) else {
            print("[NFX]: WARNING - Failed to swizzle protocolClasses setter")
            return
        }
        method_exchangeImplementations(origMethod, newMethod)
    }

    @objc private var protocolClasses_Swizzled: [AnyClass]? {
        get {
            return self.protocolClasses_Swizzled
        }
        set {
            guard let newTypes = newValue else {
                self.protocolClasses_Swizzled = nil
                return
            }

            var types = [AnyClass]()
            for newType in newTypes {
                if !types.contains(where: { $0 == newType }) {
                    types.append(newType)
                }
            }

            self.protocolClasses_Swizzled = types
        }
    }

    // MARK: - Getter swizzle (always inject NFXProtocol when reading protocolClasses)
    // This is the nuclear fix: catches ALL sessions regardless of creation timing

    private static func swizzleProtocolGetter() {
        let instance = URLSessionConfiguration.default
        let aClass: AnyClass = object_getClass(instance)!

        let origSelector = #selector(getter: URLSessionConfiguration.protocolClasses)
        let newSelector = #selector(getter: URLSessionConfiguration.nfx_protocolClasses)

        guard let origMethod = class_getInstanceMethod(aClass, origSelector),
              let newMethod = class_getInstanceMethod(aClass, newSelector) else {
            print("[NFX]: WARNING - Failed to swizzle protocolClasses getter")
            return
        }
        method_exchangeImplementations(origMethod, newMethod)
    }

    @objc private var nfx_protocolClasses: [AnyClass]? {
        // Calls the original getter (methods are swapped)
        let classes = self.nfx_protocolClasses

        // Skip injection if netfox is not enabled
        guard NFX.swiftSharedInstance.isEnabled() else { return classes }

        // Skip injection for NFXProtocol's own internal session config (prevents recursion)
        if objc_getAssociatedObject(self, &nfxExemptConfigKey) != nil {
            return classes
        }

        // Inject NFXProtocol if not already present
        if var classes = classes {
            if !classes.contains(where: { $0 == NFXProtocol.self }) {
                classes.insert(NFXProtocol.self, at: 0)
            }
            return classes
        }
        return [NFXProtocol.self]
    }

    // Mark a config as exempt from NFXProtocol injection
    static func markAsNFXInternal(_ config: URLSessionConfiguration) {
        objc_setAssociatedObject(config, &nfxExemptConfigKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // MARK: - Default / Ephemeral getter swizzles (for explicit injection)

    private static func swizzleDefault() {
        let aClass: AnyClass = object_getClass(self)!

        let origSelector = #selector(getter: URLSessionConfiguration.default)
        let newSelector = #selector(getter: URLSessionConfiguration.default_swizzled)

        guard let origMethod = class_getClassMethod(aClass, origSelector),
              let newMethod = class_getClassMethod(aClass, newSelector) else {
            print("[NFX]: WARNING - Failed to swizzle URLSessionConfiguration.default")
            return
        }
        method_exchangeImplementations(origMethod, newMethod)
    }

    private static func swizzleEphemeral() {
        let aClass: AnyClass = object_getClass(self)!

        let origSelector = #selector(getter: URLSessionConfiguration.ephemeral)
        let newSelector = #selector(getter: URLSessionConfiguration.ephemeral_swizzled)

        guard let origMethod = class_getClassMethod(aClass, origSelector),
              let newMethod = class_getClassMethod(aClass, newSelector) else {
            print("[NFX]: WARNING - Failed to swizzle URLSessionConfiguration.ephemeral")
            return
        }
        method_exchangeImplementations(origMethod, newMethod)
    }

    @objc private class var default_swizzled: URLSessionConfiguration {
        get {
            let config = URLSessionConfiguration.default_swizzled
            config.protocolClasses?.insert(NFXProtocol.self, at: 0)
            return config
        }
    }

    @objc private class var ephemeral_swizzled: URLSessionConfiguration {
        get {
            let config = URLSessionConfiguration.ephemeral_swizzled
            config.protocolClasses?.insert(NFXProtocol.self, at: 0)
            return config
        }
    }
}

// MARK: - UIWindow Key Window

#if os(iOS)
extension UIWindow {
    static var keyWindow: UIWindow? {
        return UIApplication.shared.connectedScenes
            .sorted { $0.activationState.sortPriority < $1.activationState.sortPriority }
            .compactMap { $0 as? UIWindowScene }
            .compactMap { $0.windows.first { $0.isKeyWindow } }
            .first
    }
}

private extension UIScene.ActivationState {
    var sortPriority: Int {
        switch self {
        case .foregroundActive: return 1
        case .foregroundInactive: return 2
        case .background: return 3
        case .unattached: return 4
        @unknown default: return 5
        }
    }
}
#endif

// MARK: - Publisher / Subscription (reactive pattern)

class Publisher<T> {

    private var subscriptions = Set<Subscription<T>>()

    var hasSubscribers: Bool { !subscriptions.isEmpty }

    init() where T == Void { }
    init() { }

    func subscribe(_ subscription: Subscription<T>) {
        subscriptions.insert(subscription)
    }

    @discardableResult
    func subscribe(_ callback: @escaping (T) -> Void) -> Subscription<T> {
        let subscription = Subscription(callback)
        subscriptions.insert(subscription)
        return subscription
    }

    func trigger(_ obj: T) {
        subscriptions.forEach {
            if $0.isCancelled {
                unsubscribe($0)
            } else {
                $0.callback(obj)
            }
        }
    }

    func unsubscribe(_ subscription: Subscription<T>) {
        subscriptions.remove(subscription)
    }

    func unsubscribeAll() {
        subscriptions.removeAll()
    }

    func callAsFunction(_ value: T) {
        trigger(value)
    }

    func callAsFunction() where T == Void {
        trigger(())
    }
}

class Subscription<T>: Equatable, Hashable {

    let id = UUID()
    private(set) var isCancelled = false
    fileprivate let callback: (T) -> Void

    init(_ callback: @escaping (T) -> Void) {
        self.callback = callback
    }

    func cancel() {
        isCancelled = true
    }

    static func == (lhs: Subscription<T>, rhs: Subscription<T>) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - NSRegularExpression Helpers

extension NSRegularExpression {
    convenience init(_ pattern: String) {
        do {
            try self.init(pattern: pattern)
        } catch {
            preconditionFailure("Illegal regular expression: \(pattern).")
        }
    }

    func matches(_ string: String) -> Bool {
        let range = NSRange(string.startIndex..., in: string)
        return firstMatch(in: string, options: [], range: range) != nil
    }
}
