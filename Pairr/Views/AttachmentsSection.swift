import SwiftUI
import SwiftData
import PhotosUI
import QuickLook
import UniformTypeIdentifiers

/// Photos, manuals and links of a device. Files are stored encrypted.
struct AttachmentsSection: View {
    @Bindable var device: Device
    @Environment(\.modelContext) private var context
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showPhotos = false
    @State private var showFiles = false
    @State private var showLink = false
    @State private var linkText = ""
    @State private var preview: URL?
    @State private var errorText: String?

    var body: some View {
        Section {
            let items = device.sortedAttachments
            let photos = items.filter { $0.kind == .photo }
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photos) { a in
                            thumbnail(a)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            ForEach(items.filter { $0.kind != .photo }) { a in
                row(a)
            }
            Menu {
                Button { showPhotos = true } label: { Label("Photo", systemImage: "photo") }
                Button { showFiles = true } label: { Label("File or manual (PDF)", systemImage: "doc") }
                Button { linkText = ""; showLink = true } label: { Label("Link", systemImage: "link") }
            } label: {
                Label("Add attachment", systemImage: "paperclip")
            }
            if let errorText {
                Text(verbatim: errorText).font(.footnote).foregroundStyle(.red)
            }
        } header: {
            Text("Attachments")
        } footer: {
            Text("A photo of the sticker, the manual or where the device is in your home.")
        }
        .photosPicker(isPresented: $showPhotos, selection: $photoItems, maxSelectionCount: 6, matching: .images)
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            let picked = items
            photoItems = []
            Task {
                for item in picked {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        add(.photo, name: String(localized: "Photo"), data: PhotoCodeReader.compressedJPEG(data) ?? data, type: .jpeg)
                    }
                }
            }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf, .image, .plainText, .data], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            for url in urls {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url) else { continue }
                let type = UTType(filenameExtension: url.pathExtension) ?? .data
                if type.conforms(to: .image) {
                    add(.photo, name: url.deletingPathExtension().lastPathComponent,
                        data: PhotoCodeReader.compressedJPEG(data) ?? data, type: .jpeg)
                } else {
                    add(.document, name: url.lastPathComponent, data: data, type: type)
                }
            }
        }
        .alert("Add link", isPresented: $showLink) {
            TextField(text: $linkText) { Text(verbatim: "https://…") }
            Button("Add") { addLink() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("For example the product page or the online manual.")
        }
        .quickLookPreview($preview)
    }

    private func thumbnail(_ a: Attachment) -> some View {
        Group {
            if let data = a.data, let image = Image(imageData: data) {
                image.resizable().scaledToFill()
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
            }
        }
        .frame(width: 96, height: 96)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture { open(a) }
        .contextMenu {
            Button { open(a) } label: { Label("Open", systemImage: "eye") }
            Button(role: .destructive) { remove(a) } label: { Label("Delete", systemImage: "trash") }
        }
        .accessibilityLabel(Text(verbatim: a.name))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func row(_ a: Attachment) -> some View {
        switch a.kind {
        case .link:
            if let url = a.url {
                Link(destination: url) {
                    Label { Text(verbatim: a.name.isEmpty ? url.absoluteString : a.name).lineLimit(1) } icon: { Image(systemName: "link") }
                }
                .contextMenu {
                    Button(role: .destructive) { remove(a) } label: { Label("Delete", systemImage: "trash") }
                }
                .swipeActions { Button(role: .destructive) { remove(a) } label: { Label("Delete", systemImage: "trash") } }
            }
        default:
            Button { open(a) } label: {
                Label { Text(verbatim: a.name).lineLimit(1) } icon: {
                    Image(systemName: a.contentType == UTType.pdf.identifier ? "doc.richtext" : "doc")
                }
            }
            .foregroundStyle(.primary)
            .contextMenu {
                Button(role: .destructive) { remove(a) } label: { Label("Delete", systemImage: "trash") }
            }
            .swipeActions { Button(role: .destructive) { remove(a) } label: { Label("Delete", systemImage: "trash") } }
        }
    }

    private func add(_ kind: AttachmentKind, name: String, data: Data, type: UTType) {
        guard data.count < 25_000_000 else {
            errorText = String(localized: "This file is too large (25 MB at most).")
            return
        }
        do {
            let a = Attachment(kind: kind, name: name)
            a.sealedData = try CodeVault.seal(data)
            a.contentType = type.identifier
            context.insert(a)
            device.attachments = (device.attachments ?? []) + [a]
            device.touch()
            try? context.save()
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func addLink() {
        var text = linkText.trimmed
        guard !text.isEmpty else { return }
        if !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text) else { return }
        let a = Attachment(kind: .link, name: url.host() ?? text)
        a.urlString = url.absoluteString
        context.insert(a)
        device.attachments = (device.attachments ?? []) + [a]
        device.touch()
        try? context.save()
    }

    /// Decrypts to a temporary file and opens it in Quick Look.
    private func open(_ a: Attachment) {
        guard let data = a.data else { return }
        let ext = UTType(a.contentType)?.preferredFilenameExtension ?? (a.kind == .photo ? "jpg" : "dat")
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("PairrPreview", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let base = a.name.isEmpty ? "Pairr" : (a.name as NSString).deletingPathExtension
        let url = dir.appendingPathComponent(base).appendingPathExtension(ext)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            preview = url
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func remove(_ a: Attachment) {
        context.delete(a)
        device.touch()
        try? context.save()
    }
}
