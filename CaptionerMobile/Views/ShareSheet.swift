import SwiftUI
import UIKit

/// A file to hand to the system share sheet.
struct ShareFile: Identifiable {
    let url: URL
    var id: String { url.path }
}

/// The system share sheet for one file.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Writes the captions as a subtitle or text file into Captioner's folder in Files.
enum CaptionFileExport {
    static func write(_ item: CaptionItem, format: SubtitleWriter.Format) throws -> URL {
        let folder = AppSettings.shared.exportFolder ?? URL.documentsDirectory.appending(path: "Exports", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: item.name + "." + format.fileExtension)
        try SubtitleWriter.write(item.captions, format: format, options: item.textOptions, to: url)
        return url
    }
}
