import SwiftUI

/// The current style: pick a preset or saved style from the gallery, then fine-tune it.
struct StyleSheet: View {
    @Bindable var item: CaptionItem
    @Environment(\.dismiss) private var dismiss
    @State private var showGallery = false
    @State private var naming = false
    @State private var newName = ""

    private var settings: AppSettings { AppSettings.shared }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { showGallery = true } label: {
                        HStack(spacing: 12) {
                            StyleSampleView(style: item.style)
                                .frame(width: 96, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(item.style.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    if settings.isDefault(item.style) {
                                        DefaultBadge()
                                    }
                                }
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Menu {
                        Button("Save as New Style…") {
                            newName = settings.isSavedStyle(item.style.id) ? item.style.name + " copy" : item.style.name + " (Custom)"
                            naming = true
                        }
                        if settings.isSavedStyle(item.style.id) {
                            Button("Update “\(settings.baseStyle(for: item.style.id)?.name ?? item.style.name)”") {
                                settings.updateSavedStyle(item.style)
                            }
                            .disabled(!settings.isEdited(item.style))
                        }
                        Divider()
                        if settings.isDefault(item.style) {
                            Label("Default for New Videos", systemImage: "checkmark")
                        } else {
                            Button("Use as Default for New Videos") { settings.defaultStyle = item.style }
                        }
                    } label: {
                        Label(settings.isSavedStyle(item.style.id) && !settings.isEdited(item.style) ? "Saved" : "Save Style", systemImage: settings.isSavedStyle(item.style.id) && !settings.isEdited(item.style) ? "bookmark.fill" : "bookmark")
                    }
                } header: {
                    Text("Style")
                }
                Section("Adjust") {
                    StyleEditorView(style: $item.style)
                }
            }
            .navigationTitle("Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showGallery) {
                StyleGalleryView(item: item)
            }
            .alert("Save Style", isPresented: $naming) {
                TextField("Name", text: $newName)
                Button("Save") {
                    let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    item.style = settings.saveStyle(item.style, name: name.isEmpty ? item.style.name : name)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("It appears in the gallery under Saved.")
            }
        }
    }

    private var subtitle: String {
        var parts = [item.style.layoutName]
        if settings.isSavedStyle(item.style.id) { parts.append("saved") }
        if settings.isEdited(item.style) { parts.append("edited") }
        return parts.joined(separator: " · ")
    }
}
