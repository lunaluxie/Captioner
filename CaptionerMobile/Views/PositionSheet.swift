import SwiftUI

/// Where the captions sit, for 16:9 and 9:16 frames.
struct PositionSheet: View {
    @Bindable var item: CaptionItem
    @Environment(\.dismiss) private var dismiss
    @State private var orientation: FrameOrientation?

    var body: some View {
        let current = orientation ?? item.orientation
        let binding = Binding(get: { item.placement[current] }, set: { item.placement[current] = $0; AppSettings.shared.placement = item.placement })
        NavigationStack {
            Form {
                Section {
                    Picker("Frame", selection: Binding(get: { current }, set: { orientation = $0 })) {
                        ForEach(FrameOrientation.allCases, id: \.self) { o in
                            Text(o == item.orientation ? "\(o.title) (this video)" : o.title).tag(o)
                        }
                    }
                    .pickerStyle(.segmented)
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Vertical")
                            Spacer()
                            Text("\(Int(binding.wrappedValue.vertical * 100))%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: binding.vertical, in: 0.05...0.97)
                    }
                    Picker("Alignment", selection: binding.alignment) {
                        ForEach(CaptionAlignment.allCases, id: \.self) { alignment in
                            Image(systemName: alignment.symbolName).tag(alignment)
                        }
                    }
                    .pickerStyle(.segmented)
                    VStack(alignment: .leading) {
                        Text("Side margin")
                        Slider(value: binding.horizontalInset, in: 0...0.2)
                    }
                    VStack(alignment: .leading) {
                        Text("Max width")
                        Slider(value: binding.maxWidth, in: 0.4...1)
                    }
                } footer: {
                    Text("You can also drag the caption in the preview. Each frame shape remembers its own position.")
                }
                Section {
                    Button("Reset to Default") {
                        item.placement[current] = current == .portrait ? .portraitDefault : .landscapeDefault
                        AppSettings.shared.placement = item.placement
                    }
                }
            }
            .navigationTitle("Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
