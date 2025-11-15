import SwiftUI
import PhotosUI
import AVFoundation

enum MediaPickerResult {
    case cancelled
    case loading(count: Int)
    case loaded([SelectedMediaItem])
}

struct PHPickerView: UIViewControllerRepresentable {
    let onResult: (MediaPickerResult) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 10
        config.filter = .any(of: [.images, .videos])

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onResult: (MediaPickerResult) -> Void

        init(onResult: @escaping (MediaPickerResult) -> Void) {
            self.onResult = onResult
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                onResult(.cancelled)
                return
            }

            // Immediately show loading state
            onResult(.loading(count: results.count))

            // Load media in background
            Task {
                var media: [SelectedMediaItem] = []

                for (index, result) in results.enumerated() {
                    print("Loading item \(index + 1)/\(results.count)")

                    if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                        if let item = await loadVideo(from: result.itemProvider) {
                            media.append(item)
                        }
                    } else if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                        if let item = await loadImage(from: result.itemProvider) {
                            media.append(item)
                        }
                    }
                }

                print("✅ Loaded \(media.count)/\(results.count) items")

                await MainActor.run {
                    onResult(.loaded(media))
                }
            }
        }

        private func loadImage(from itemProvider: NSItemProvider) async -> SelectedMediaItem? {
            return await withCheckedContinuation { continuation in
                itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                    if let error = error {
                        print("❌ Failed to load image: \(error)")
                        continuation.resume(returning: nil)
                        return
                    }

                    guard let image = object as? UIImage else {
                        continuation.resume(returning: nil)
                        return
                    }

                    continuation.resume(returning: SelectedMediaItem(image: image, videoURL: nil, isVideo: false))
                }
            }
        }

        private func loadVideo(from itemProvider: NSItemProvider) async -> SelectedMediaItem? {
            return await withCheckedContinuation { continuation in
                itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    if let error = error {
                        print("❌ Failed to load video: \(error)")
                        continuation.resume(returning: nil)
                        return
                    }

                    guard let url = url else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("mov")

                    do {
                        try FileManager.default.copyItem(at: url, to: tempURL)
                        let thumbnail = self.generateThumbnail(from: tempURL)
                        continuation.resume(returning: SelectedMediaItem(image: thumbnail, videoURL: tempURL, isVideo: true))
                    } catch {
                        print("❌ Failed to copy video: \(error)")
                        continuation.resume(returning: nil)
                    }
                }
            }
        }

        private func generateThumbnail(from url: URL) -> UIImage? {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true

            do {
                let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
                return UIImage(cgImage: cgImage)
            } catch {
                return nil
            }
        }
    }
}

struct SelectedMediaItem: Equatable {
    let image: UIImage?
    let videoURL: URL?
    let isVideo: Bool

    static func == (lhs: SelectedMediaItem, rhs: SelectedMediaItem) -> Bool {
        lhs.isVideo == rhs.isVideo && lhs.videoURL == rhs.videoURL
    }
}
