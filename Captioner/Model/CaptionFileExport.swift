import AppKit
import Foundation

/// Saves the captions as a subtitle or text file wherever the user picks.
enum CaptionFileExport {
    static func save(_ item: CaptionItem, format: SubtitleWriter.Format) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.type]
        panel.nameFieldStringValue = item.name + "." + format.fileExtension
        panel.directoryURL = AppSettings.shared.exportFolder ?? item.url.deletingLastPathComponent()
        panel.canCreateDirectories = true
        panel.title = "Save Captions"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try SubtitleWriter.write(item.captions, format: format, options: item.textOptions, to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
