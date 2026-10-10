//
//  NFXTextFormatter.swift
//  netfox
//
//  Reusable attributed string formatter for SwiftUI views.
//  Extracts the formatNFXString logic from NFXGenericController
//  so SwiftUI views can use it without UIKit controller dependency.
//

#if os(iOS)

import UIKit

enum NFXTextFormatter {

    /// Formats a raw NFX log string into an NSAttributedString with:
    /// - Bold + orange section headers (-- Body --, -- Headers --)
    /// - Tappable link attributes on [Key] labels
    /// - Dynamic dark mode text colors
    static func formatNFXString(_ string: String) -> NSAttributedString {
        let tempMutableString = NSMutableAttributedString(string: string)
        let stringCount = string.count

        // Default text color
        tempMutableString.addAttribute(
            .foregroundColor,
            value: UIColor.NFXBlackColor(),
            range: NSRange(location: 0, length: stringCount)
        )

        // Default font
        tempMutableString.addAttribute(
            .font,
            value: UIFont.NFXFont(size: 13),
            range: NSRange(location: 0, length: stringCount)
        )

        // Bold + orange for section headers
        if let regexBodyHeaders = try? NSRegularExpression(
            pattern: "(\\-- Body \\--)|(\\-- Headers \\--)",
            options: .caseInsensitive
        ) {
            let matches = regexBodyHeaders.matches(
                in: string,
                options: .withoutAnchoringBounds,
                range: NSRange(location: 0, length: stringCount)
            )
            for match in matches {
                tempMutableString.addAttribute(.font, value: UIFont.NFXFontBold(size: 14), range: match.range)
                tempMutableString.addAttribute(.foregroundColor, value: UIColor.NFXOrangeColor(), range: match.range)
            }
        }

        // Tappable links for [Key] labels
        if let regexKeys = try? NSRegularExpression(
            pattern: "\\[.+?\\]",
            options: .caseInsensitive
        ) {
            let matches = regexKeys.matches(
                in: string,
                options: .withoutAnchoringBounds,
                range: NSRange(location: 0, length: stringCount)
            )
            for match in matches {
                tempMutableString.addAttribute(.foregroundColor, value: UIColor.NFXBlackColor(), range: match.range)
                tempMutableString.addAttribute(
                    .link,
                    value: (string as NSString).substring(with: match.range),
                    range: match.range
                )
            }
        }

        return tempMutableString
    }

    // MARK: - Info / Request / Response string builders (extracted from NFXDetailsController)

    static func infoString(for model: NFXHTTPModel) -> NSAttributedString {
        var temp = ""
        temp += "[URL] \n\(model.requestURL ?? "-")\n\n"
        temp += "[Method] \n\(model.requestMethod ?? "-")\n\n"
        if !model.noResponse {
            temp += "[Status] \n\(model.responseStatus ?? 0)\n\n"
        }
        temp += "[Request date] \n\(model.requestDate.map { "\($0)" } ?? "-")\n\n"
        if !model.noResponse {
            temp += "[Response date] \n\(model.responseDate.map { "\($0)" } ?? "-")\n\n"
            temp += "[Time interval] \n\(model.timeInterval.map { "\($0)" } ?? "-")\n\n"
        }
        temp += "[Timeout] \n\(model.requestTimeout ?? "-")\n\n"
        temp += "[Cache policy] \n\(model.requestCachePolicy ?? "-")\n\n"
        return formatNFXString(temp)
    }

    static func requestString(for model: NFXHTTPModel) -> NSAttributedString {
        var temp = ""
        temp += "-- Headers --\n\n"
        if let headers = model.requestHeaders, !headers.isEmpty {
            for (key, val) in headers {
                temp += "[\(key)] \n\(val)\n\n"
            }
        } else {
            temp += "Request headers are empty\n\n"
        }
        temp += requestBodyFooter(for: model)
        return formatNFXString(temp)
    }

    static func responseString(for model: NFXHTTPModel) -> NSAttributedString {
        if model.noResponse {
            return NSMutableAttributedString(string: "No response")
        }
        var temp = ""
        temp += "-- Headers --\n\n"
        if let headers = model.responseHeaders, !headers.isEmpty {
            for (key, val) in headers {
                temp += "[\(key)] \n\(val)\n\n"
            }
        } else {
            temp += "Response headers are empty\n\n"
        }
        temp += responseBodyFooter(for: model)
        return formatNFXString(temp)
    }

    static func requestBodyFooter(for model: NFXHTTPModel) -> String {
        var temp = "\n-- Body --\n\n"
        let bodyLength = model.requestBodyLength ?? 0
        if bodyLength == 0 {
            temp += "Request body is empty\n"
        } else if bodyLength > 1024 {
            temp += "Too long to show. If you want to see it, please tap the following button\n"
        } else {
            temp += "\(model.getRequestBody())\n"
        }
        return temp
    }

    static func responseBodyFooter(for model: NFXHTTPModel) -> String {
        var temp = "\n-- Body --\n\n"
        let bodyLength = model.responseBodyLength ?? 0
        if bodyLength == 0 {
            temp += "Response body is empty\n"
        } else if bodyLength > 1024 {
            temp += "Too long to show. If you want to see it, please tap the following button\n"
        } else {
            temp += "\(model.getResponseBody())\n"
        }
        return temp
    }

    // MARK: - Share log builder

    static func shareLog(for model: NFXHTTPModel, full: Bool) -> String {
        var temp = ""
        temp += "** INFO **\n"
        temp += "\(infoString(for: model).string)\n\n"
        temp += "** REQUEST **\n"
        temp += "\(requestString(for: model).string)\n\n"
        temp += "** RESPONSE **\n"
        temp += "\(responseString(for: model).string)\n\n"
        temp += "logged via netfox - [https://github.com/azimxxm/netfox-ios]\n"

        if full {
            if let requestData = try? String(contentsOf: model.getRequestBodyFileURL(), encoding: .utf8) {
                temp += requestData
            }
            if let responseData = try? String(contentsOf: model.getResponseBodyFileURL(), encoding: .utf8) {
                temp += responseData
            }
        }
        return temp
    }
}

#endif
