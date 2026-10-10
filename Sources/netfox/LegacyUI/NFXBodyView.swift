//
//  NFXBodyView.swift
//  netfox
//
//  SwiftUI body viewer for request/response payloads.
//  Supports raw text, color-coded JSON (B10), and image preview.
//

#if os(iOS)

import SwiftUI

struct NFXBodyView: View {
    let model: NFXHTTPModel
    let bodyType: NFXBodyType

    @State private var showCopied = false

    var body: some View {
        ScrollView {
            if model.shortType == .IMAGE && bodyType == .response {
                imageBody
            } else {
                textBody
            }
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle(bodyType == .request ? "Request Body" : "Response Body")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    copyBody()
                } label: {
                    if showCopied {
                        Text("Copied!")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(UIColor.NFXGreenColor()))
                    } else {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }

    // MARK: - Image body

    @ViewBuilder
    private var imageBody: some View {
        let bodyString = model.getResponseBody()
        if let data = Data(base64Encoded: bodyString, options: .ignoreUnknownCharacters),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding()
        } else {
            Text("Unable to decode image")
                .foregroundColor(.secondary)
                .padding()
        }
    }

    // MARK: - Text body (with JSON syntax highlighting for B10)

    @ViewBuilder
    private var textBody: some View {
        let content = bodyType == .request ? model.getRequestBody() : model.getResponseBody()

        if content.isEmpty {
            Text("Body is empty")
                .foregroundColor(.secondary)
                .padding()
        } else if isJSON(content) {
            // Color-coded JSON (B10)
            NFXAttributedTextView(attributedText: colorCodedJSON(content))
                .padding()
        } else {
            Text(content)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .padding()
        }
    }

    // MARK: - Actions

    private func copyBody() {
        let content = bodyType == .request ? model.getRequestBody() : model.getResponseBody()
        UIPasteboard.general.string = content
        withAnimation {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                showCopied = false
            }
        }
    }

    // MARK: - JSON Detection

    private func isJSON(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.hasPrefix("{") && trimmed.hasSuffix("}"))
            || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))
    }

    // MARK: - Color-coded JSON (B10)

    private func colorCodedJSON(_ jsonString: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let defaultFont = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)

        let keyColor = UIColor.NFXOrangeColor()
        let stringColor = UIColor.NFXGreenColor()
        let numberColor = UIColor.systemBlue
        let boolColor = UIColor.systemPurple
        let nullColor = UIColor.systemGray
        let defaultColor = UIColor.label

        // Parse token-by-token for reliable coloring
        let chars = Array(jsonString)
        var i = 0
        let count = chars.count

        // Track whether the next string is a key (follows { or ,)
        var expectKey = false

        while i < count {
            let ch = chars[i]

            switch ch {
            case "\"":
                // Read entire string
                let start = i
                i += 1
                while i < count {
                    if chars[i] == "\\" {
                        i += 2
                        continue
                    }
                    if chars[i] == "\"" {
                        i += 1
                        break
                    }
                    i += 1
                }
                let token = String(chars[start..<min(i, count)])

                // Determine if this is a key or a value
                // Look ahead for colon to decide
                var isKey = false
                var j = i
                while j < count && chars[j].isWhitespace || (j < count && chars[j] == "\n") {
                    j += 1
                }
                if j < count && chars[j] == ":" {
                    isKey = true
                }

                let color = isKey ? keyColor : stringColor
                result.append(NSAttributedString(
                    string: token,
                    attributes: [.font: defaultFont, .foregroundColor: color]
                ))

            case "t", "f":
                // true / false
                let remaining = String(chars[i...])
                if remaining.hasPrefix("true") {
                    result.append(NSAttributedString(
                        string: "true",
                        attributes: [.font: defaultFont, .foregroundColor: boolColor]
                    ))
                    i += 4
                } else if remaining.hasPrefix("false") {
                    result.append(NSAttributedString(
                        string: "false",
                        attributes: [.font: defaultFont, .foregroundColor: boolColor]
                    ))
                    i += 5
                } else {
                    result.append(NSAttributedString(
                        string: String(ch),
                        attributes: [.font: defaultFont, .foregroundColor: defaultColor]
                    ))
                    i += 1
                }

            case "n":
                let remaining = String(chars[i...])
                if remaining.hasPrefix("null") {
                    result.append(NSAttributedString(
                        string: "null",
                        attributes: [.font: defaultFont, .foregroundColor: nullColor]
                    ))
                    i += 4
                } else {
                    result.append(NSAttributedString(
                        string: String(ch),
                        attributes: [.font: defaultFont, .foregroundColor: defaultColor]
                    ))
                    i += 1
                }

            case "-", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // Number
                let start = i
                while i < count && (chars[i].isNumber || chars[i] == "." || chars[i] == "e" || chars[i] == "E" || chars[i] == "+" || chars[i] == "-") {
                    // Avoid consuming the minus of a negative number that follows something else
                    if i > start && (chars[i] == "-" || chars[i] == "+") && chars[i-1] != "e" && chars[i-1] != "E" {
                        break
                    }
                    i += 1
                }
                let token = String(chars[start..<i])
                result.append(NSAttributedString(
                    string: token,
                    attributes: [.font: defaultFont, .foregroundColor: numberColor]
                ))

            case "{", "}":
                expectKey = (ch == "{")
                result.append(NSAttributedString(
                    string: String(ch),
                    attributes: [.font: defaultFont, .foregroundColor: defaultColor]
                ))
                i += 1

            default:
                result.append(NSAttributedString(
                    string: String(ch),
                    attributes: [.font: defaultFont, .foregroundColor: defaultColor]
                ))
                i += 1
            }
        }

        _ = expectKey // Suppress unused variable warning

        return result
    }
}

#endif
