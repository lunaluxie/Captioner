import PhotosUI
import SwiftUI
import Translation

/// The queue: every video added, with its progress, leading into the editor.
struct HomeView: View {
    @Environment(CaptionQueue.self) private var queue
    @Environment(AppState.self) private var appState
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var importingFiles = false
    @State private var showSettings = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var path: [CaptionItem.ID] = []

    var body: some View {
        @Bindable var queue = queue
        NavigationStack(path: $path) {
            Group {
                if queue.items.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Captioner")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isImporting {
                        ProgressView()
                    }
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 20, matching: .videos) {
                        Image(systemName: "photo.badge.plus")
                    }
                    Button { importingFiles = true } label: { Image(systemName: "folder.badge.plus") }
                }
            }
            .navigationDestination(for: CaptionItem.ID.self) { id in
                if let item = queue.items.first(where: { $0.id == id }) {
                    EditorView(item: item)
                } else {
                    ContentUnavailableView("Video Removed", systemImage: "film")
                }
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            importPicked(items)
        }
        .fileImporter(isPresented: $importingFiles, allowedContentTypes: [.movie], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): queue.add(MediaImporter.importFiles(urls))
            case .failure(let error): importError = error.localizedDescription
            }
        }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
        #if DEBUG
        // Development aid: CAPTIONER_DEBUG_EDIT=1 opens the first video's editor as soon as it is in the queue.
        .task {
            guard ProcessInfo.processInfo.environment["CAPTIONER_DEBUG_EDIT"] != nil else { return }
            while queue.items.isEmpty { try? await Task.sleep(for: .milliseconds(200)) }
            if let first = queue.items.first { path = [first.id] }
        }
        #endif
        .alert("Couldn't Add Video", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .alert("Export Failed", isPresented: Binding(get: { queue.lastError != nil }, set: { if !$0 { queue.clearError() } })) {
            Button("OK") { queue.clearError() }
        } message: {
            Text(queue.lastError ?? "")
        }
        .translationTask(appState.translationRequest?.configuration) { session in
            await appState.performTranslation(with: session, queue: queue)
        }
    }

    private var list: some View {
        List {
            ForEach(queue.items) { item in
                NavigationLink(value: item.id) {
                    QueueRowMobile(item: item)
                }
            }
            .onDelete { offsets in
                let ids = offsets.map { queue.items[$0].id }
                let urls = offsets.map { queue.items[$0].url }
                queue.remove(Set(ids))
                for url in urls { MediaImporter.discard(url) }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Add a Video", systemImage: "captions.bubble")
        } description: {
            Text("Captioner listens to the speech in your video and burns in animated, word-by-word captions. Everything happens on this device.")
        } actions: {
            PhotosPicker(selection: $pickerItems, maxSelectionCount: 20, matching: .videos) {
                Label("Choose from Photos", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.borderedProminent)
            Button { importingFiles = true } label: {
                Label("Choose from Files", systemImage: "folder")
            }
            .buttonStyle(.bordered)
        }
    }

    private func importPicked(_ items: [PhotosPickerItem]) {
        isImporting = true
        Task {
            var urls: [URL] = []
            for item in items {
                do {
                    if let video = try await item.loadTransferable(type: ImportedVideo.self) {
                        urls.append(video.url)
                    }
                } catch {
                    importError = error.localizedDescription
                }
            }
            pickerItems = []
            queue.add(urls)
            isImporting = false
        }
    }
}

struct QueueRowMobile: View {
    let item: CaptionItem

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let progress {
                    ProgressView(value: progress)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var progress: Double? {
        switch item.status {
        case .transcribing: item.job?.phase == .downloading ? item.job?.downloadProgress : item.job?.progress
        case .exporting: item.exportProgress
        default: nil
        }
    }

    private var subtitle: String {
        let length = item.duration > 0 ? TimeFormat.clock(item.duration) : ""
        switch item.status {
        case .loading: return "Reading…"
        case .waiting: return "Waiting"
        case .transcribing: return "Generating captions…"
        case .ready: return [length, "\(item.captions.count) captions", item.translation != nil ? TranslationCatalog.name(Locale.Language(identifier: item.translation!.targetIdentifier)) : nil].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        case .exporting: return "Exporting…"
        case .exported: return "Exported"
        case .failed(let message): return message
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .loading, .waiting:
            Image(systemName: "clock").foregroundStyle(.secondary)
        case .transcribing, .exporting:
            ProgressView()
        case .ready:
            Image(systemName: "captions.bubble").foregroundStyle(Color.accentColor)
        case .exported:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }
}
