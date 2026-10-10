//
//  NFXBodyFile.swift
//  netfox
//
//  A stored body file for ShareLink, with a readable name and extension.
//

#if os(iOS)
import CoreTransferable
import Foundation
import NetfoxCore
import UniformTypeIdentifiers

nonisolated struct NFXBodyFile: Transferable {
    let url: URL
    let fileName: String

    /// `part` and the MIME type give the name, e.g. "response-body.png".
    init(url: URL, part: NFXBodyPart, mimeType: String?) {
        self.url = url
        let fileExtension = mimeType.flatMap { UTType(mimeType: $0)?.preferredFilenameExtension } ?? "bin"
        self.fileName = "\(part.rawValue)-body.\(fileExtension)"
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .data) { file in
            SentTransferredFile(file.url)
        }
        .suggestedFileName { file in file.fileName }
    }
}
#endif
