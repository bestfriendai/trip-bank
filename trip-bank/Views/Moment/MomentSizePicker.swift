import SwiftUI

// Reusable component for picking moment size (width and height)
struct MomentSizePicker: View {
    @Binding var width: Double
    @Binding var height: Double
    let onChange: (() -> Void)?

    init(width: Binding<Double>, height: Binding<Double>, onChange: (() -> Void)? = nil) {
        self._width = width
        self._height = height
        self.onChange = onChange
    }

    var body: some View {
        VStack(spacing: 20) {
            // Width picker
            VStack(spacing: 8) {
                HStack {
                    Text("Width")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Picker("Width", selection: $width) {
                    Text("1 Column").tag(1.0)
                    Text("2 Columns").tag(2.0)
                }
                .pickerStyle(.segmented)
                .onChange(of: width) { _, _ in
                    onChange?()
                }
            }

            // Height slider
            VStack(spacing: 8) {
                HStack {
                    Text("Height")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(height, specifier: "%.1f") rows")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.primary)
                }

                Slider(value: $height, in: 1...4, step: 0.5)
                    .tint(.blue)
                    .onChange(of: height) { _, _ in
                        onChange?()
                    }
            }
        }
    }
}
