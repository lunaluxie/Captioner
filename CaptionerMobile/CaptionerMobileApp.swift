import SwiftUI

@main
struct CaptionerMobileApp: App {
    @State private var queue = CaptionQueue.shared
    @State private var appState = AppState()

    init() {
        _ = FontLibrary.shared
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(queue)
                .environment(appState)
                .onOpenURL { url in
                    queue.add(MediaImporter.importFiles([url]))
                }
                .task {
                    #if DEBUG
                    // Development aid: CAPTIONER_DEBUG_OPEN=/path/a.mp4:/path/b.mp4 adds videos at launch.
                    if let list = ProcessInfo.processInfo.environment["CAPTIONER_DEBUG_OPEN"] {
                        queue.add(MediaImporter.importFiles(list.split(separator: ":").map { URL(fileURLWithPath: String($0)) }))
                        // CAPTIONER_DEBUG_SUBTITLES=/path.srt feeds captions to the first video, since the
                        // simulator has no speech models.
                        if let srt = ProcessInfo.processInfo.environment["CAPTIONER_DEBUG_SUBTITLES"], let item = queue.items.first {
                            while item.status == .loading { try? await Task.sleep(for: .milliseconds(200)) }
                            try? item.importSubtitles(from: URL(fileURLWithPath: srt))
                            queue.pumpTranscription()
                        }
                    }
                    #endif
                }
        }
    }
}
