import PhotosUI
import SwiftUI

/// A logo or handle drawn over the video: pick the image from Photos or Files, then set its
/// opacity, size, position and margin.
struct WatermarkSheet: View {
    @Bindable var item: CaptionItem
    @Environment(CaptionQueue.self) private var queue
    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?
    @State private var importingFile = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        WatermarkThumbnail(fileName: item.watermark.fileName)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.watermark.isEnabled ? "Watermark on" : "No watermark")
                                .font(.headline)
                            Text(item.watermark.isEnabled ? "Drawn over every frame, under the captions." : "Choose a PNG with transparency for best results.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(item.watermark.isEnabled ? "Choose from Photos" : "Choose from Photos", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        importingFile = true
                    } label: {
                        Label("Choose from Files", systemImage: "folder")
                    }
                    if item.watermark.isEnabled {
                        Button(role: .destructive) {
                            removeWatermark()
                        } label: {
                            Label("Remove Watermark", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("Image")
                }
                Section {
                    WatermarkControls(settings: $item.watermark)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Size is a share of the video's width. New videos start with this watermark.")
                }
            }
            .navigationTitle("Watermark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onChange(of: item.watermark) { _, watermark in AppSettings.shared.watermark = watermark }
        .onChange(of: pickerItem) { _, picked in
            guard let picked else { return }
            Task {
                do {
                    guard let data = try await picked.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadUnknown) }
                    adopt(try WatermarkLibrary.add(data: data))
                } catch {
                    self.error = error.localizedDescription
                }
                pickerItem = nil
            }
        }
        .fileImporter(isPresented: $importingFile, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url):
                do { adopt(try WatermarkLibrary.add(url)) } catch { self.error = error.localizedDescription }
            case .failure(let failure):
                error = failure.localizedDescription
            }
        }
        .alert("Couldn't Use Image", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    private func adopt(_ fileName: String) {
        let previous = item.watermark.fileName
        item.watermark.fileName = fileName
        if let previous { forget(previous) }
    }

    private func removeWatermark() {
        guard let fileName = item.watermark.fileName else { return }
        item.watermark.fileName = nil
        forget(fileName)
    }

    /// Deletes an image once no video in the queue uses it.
    private func forget(_ fileName: String) {
        guard !queue.items.contains(where: { $0.watermark.fileName == fileName }) else { return }
        WatermarkLibrary.remove(fileName)
    }
}
