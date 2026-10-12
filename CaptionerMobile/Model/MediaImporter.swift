import CoreTransferable
import Foundation
import Photos
import UniformTypeIdentifiers

/// A video chosen in the Photos picker, copied into the app's Imports folder so the queue can
/// read it whenever it likes.
nonisolated struct ImportedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            ImportedVideo(url: try MediaImporter.copyIntoImports(received.file))
        }
    }
}

/// Where videos and exports live on iPhone and iPad: inside the app's Documents folder, which
/// the Files app can browse.
nonisolated enum MediaImporter {
    static var importsDirectory: URL {
        let folder = URL.documentsDirectory.appending(path: "Imports", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Copies a file into Imports under its own name (numbered if that name is taken).
    static func copyIntoImports(_ source: URL) throws -> URL {
        let base = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension
        var destination = importsDirectory.appending(path: "\(base).\(ext)")
        var n = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = importsDirectory.appending(path: "\(base) \(n).\(ext)")
            n += 1
        }
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    /// Files handed over by the Files app or another app: copy them in while access is granted.
    static func importFiles(_ urls: [URL]) -> [URL] {
        var copied: [URL] = []
        for url in urls {
            if url.path.hasPrefix(importsDirectory.path) {
                copied.append(url)
                continue
            }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let destination = try? copyIntoImports(url) { copied.append(destination) }
        }
        return copied
    }

    static func saveToPhotos(_ url: URL) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }

    /// Removes a video (and its exports) from the app's folders once it leaves the queue.
    static func discard(_ url: URL) {
        guard url.path.hasPrefix(importsDirectory.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
