import SwiftUI
import PhotosUI
import UIKit

struct ComposePostView: View {
    let account: AppAccount
    let appPassword: String
    let blueskyClient: LiveBlueskyClient
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var postText = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [(data: Data, mimeType: String)] = []
    @State private var imageAlts: [String] = []
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var textViewRef: UITextView?

    private let maxImages = 4

    var body: some View {
        NavigationStack {
            List {
                Section {
                    WritingToolsTextView(text: $postText, textViewRef: $textViewRef)
                        .frame(minHeight: 120)
                } header: {
                    Text(verbatim: loc("compose.text_section"))
                }

                if !selectedImages.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                    let altBinding = Binding(
                                        get: { index < imageAlts.count ? imageAlts[index] : "" },
                                        set: { if index < imageAlts.count { imageAlts[index] = $0 } }
                                    )
                                    VStack(spacing: 4) {
                                        if let uiImage = UIImage(data: image.data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        TextField(loc("compose.alt_placeholder"), text: altBinding)
                                            .font(.caption)
                                            .textFieldStyle(.plain)
                                            .frame(width: 100)
                                        Button {
                                            selectedImages.remove(at: index)
                                            imageAlts.remove(at: index)
                                        } label: {
                                            Label { Text(verbatim: loc("actions.remove")) } icon: { Image(systemName: "xmark.circle.fill") }
                                                .font(.caption)
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text(verbatim: loc("compose.images_section"))
                    }
                }

                Section {
                    PhotosPicker(selection: $selectedItems, maxSelectionCount: maxImages, matching: .images) {
                        Label { Text(verbatim: loc("compose.add_images")) } icon: { Image(systemName: "photo.on.rectangle.angled") }
                    }
                    .disabled(selectedImages.count >= maxImages)
                    .onChange(of: selectedItems) { _, items in
                        Task { await loadImages(from: items) }
                    }

                    Button {
                        triggerWritingTools()
                    } label: {
                        Label { Text(verbatim: loc("compose.improve")) } icon: { Image(systemName: "wand.and.stars") }
                    }
                    .disabled(postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(loc("compose.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("actions.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("compose.post")) {
                        Task { await post() }
                    }
                    .disabled(postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                }
            }
            .alert(loc("compose.error"), isPresented: .constant(errorMessage != nil)) {
                Button(loc("actions.ok")) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func triggerWritingTools() {
        guard let textView = textViewRef, !postText.isEmpty else { return }
        textView.becomeFirstResponder()
        textView.selectedRange = NSRange(location: 0, length: textView.text.utf16.count)
        if #available(iOS 18.2, *) {
            textView.showWritingTools(NSNull())
        }
    }

    private func loadImages(from items: [PhotosPickerItem]) async {
        var newImages: [(Data, String)] = []
        var newAlts: [String] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let mimeType = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
                newImages.append((data, mimeType))
                newAlts.append("")
            }
        }
        selectedImages = Array(newImages.prefix(maxImages))
        imageAlts = Array(newAlts.prefix(maxImages))
    }

    private func post() async {
        isPosting = true
        defer { isPosting = false }
        do {
            let images: [PostImageAttachment]?
            if selectedImages.isEmpty {
                images = nil
            } else {
                var result: [PostImageAttachment] = []
                for (index, image) in selectedImages.enumerated() {
                    let blob = try await blueskyClient.uploadBlob(
                        data: image.data,
                        mimeType: image.mimeType,
                        account: account,
                        appPassword: appPassword
                    )
                    let alt = imageAlts[safe: index] ?? ""
                    result.append(PostImageAttachment(blob: blob.blob, alt: alt))
                }
                images = result
            }
            _ = try await blueskyClient.createPost(
                text: postText,
                images: images,
                account: account,
                appPassword: appPassword
            )
            onComplete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - WritingTools UITextView Wrapper

private struct WritingToolsTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var textViewRef: UITextView?

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.font = .preferredFont(forTextStyle: .body)
        tv.backgroundColor = .clear
        tv.delegate = context.coordinator
        tv.isScrollEnabled = false
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)

        if #available(iOS 18.0, *) {
            tv.writingToolsBehavior = .complete
        }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        textViewRef = uiView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        init(text: Binding<String>) {
            _text = text
        }
        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
