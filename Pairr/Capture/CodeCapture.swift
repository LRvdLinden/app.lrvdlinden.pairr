import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Where a code is captured from.
enum CaptureSource: Identifiable {
    case camera, photo, file, nfc
    var id: Self { self }

    static var available: [CaptureSource] {
        var list: [CaptureSource] = []
        #if os(iOS)
        list.append(.camera)
        #endif
        list.append(.photo)
        #if os(macOS)
        list.append(.file)
        #endif
        #if os(iOS)
        if NFCReader.isAvailable { list.append(.nfc) }
        #endif
        return list
    }

    var title: LocalizedStringKey {
        switch self {
        case .camera: "Scan with the camera"
        case .photo: "Read from a photo"
        case .file: "Read from an image file"
        case .nfc: "Read an NFC tag"
        }
    }

    var symbol: String {
        switch self {
        case .camera: "camera.viewfinder"
        case .photo: "photo.on.rectangle"
        case .file: "doc.viewfinder"
        case .nfc: "wave.3.right"
        }
    }
}

/// Buttons for each capture source, for use in a Menu or a Form.
struct CaptureButtons: View {
    @Binding var source: CaptureSource?

    var body: some View {
        ForEach(CaptureSource.available) { s in
            Button { source = s } label: { Label(s.title, systemImage: s.symbol) }
        }
    }
}

/// Runs a capture (camera, photo, file or NFC) and returns one code, letting
/// the user choose when a photo holds several.
struct CodeCaptureModifier: ViewModifier {
    @Binding var source: CaptureSource?
    var preferred: CodeType?
    var onResult: (ParsedCode) -> Void

    @State private var showCamera = false
    @State private var showPhotos = false
    @State private var showFiles = false
    @State private var photoItem: PhotosPickerItem?
    @State private var choices: [ParsedCode] = []
    @State private var showChoices = false
    @State private var working = false
    @State private var nothingFound = false
    #if os(iOS)
    @State private var nfc = NFCReader()
    #endif

    func body(content: Content) -> some View {
        content
            .onChange(of: source) { _, new in
                guard let new else { return }
                source = nil
                switch new {
                case .camera: showCamera = true
                case .photo: showPhotos = true
                case .file: showFiles = true
                case .nfc: readNFC()
                }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $showCamera) {
                ScannerView(preferred: preferred) { deliver($0) }
            }
            #endif
            .photosPicker(isPresented: $showPhotos, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                photoItem = nil
                Task {
                    working = true
                    defer { working = false }
                    guard let data = try? await item.loadTransferable(type: Data.self) else { nothingFound = true; return }
                    deliver(await PhotoCodeReader.candidates(in: data, preferred: preferred))
                }
            }
            .fileImporter(isPresented: $showFiles, allowedContentTypes: [.image]) { result in
                guard case .success(let url) = result else { return }
                Task {
                    working = true
                    defer { working = false }
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    guard let data = try? Data(contentsOf: url) else { nothingFound = true; return }
                    deliver(await PhotoCodeReader.candidates(in: data, preferred: preferred))
                }
            }
            .sheet(isPresented: $showChoices) {
                CandidatePicker(choices: choices) { picked in
                    showChoices = false
                    onResult(picked)
                }
            }
            .overlay {
                if working {
                    ProgressView("Looking for codes…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .alert("No code found", isPresented: $nothingFound) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Try a sharper photo with the code well lit, or type the code yourself.")
            }
    }

    private func deliver(_ found: [ParsedCode]) {
        switch found.count {
        case 0: nothingFound = true
        case 1: onResult(found[0])
        default:
            choices = found
            // Wait for the scanner or picker to close first.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showChoices = true }
        }
    }

    private func readNFC() {
        #if os(iOS)
        nfc.scan { value in
            guard let value else { return }
            if let p = CodeParser.detect(value, preferred: preferred) { onResult(p) } else { nothingFound = true }
        }
        #endif
    }
}

extension View {
    func codeCapture(source: Binding<CaptureSource?>, preferred: CodeType? = nil,
                     onResult: @escaping (ParsedCode) -> Void) -> some View {
        modifier(CodeCaptureModifier(source: source, preferred: preferred, onResult: onResult))
    }
}

/// Lets the user pick one of several codes found in a photo.
struct CandidatePicker: View {
    let choices: [ParsedCode]
    var onPick: (ParsedCode) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(choices) { p in
                Button { onPick(p) } label: {
                    HStack(spacing: 12) {
                        CodeTypeBadge(type: p.type, compact: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: p.type.title).font(.caption).foregroundStyle(.secondary)
                            Text(verbatim: CodeParser.format(p.type, p.value))
                                .font(.body.monospaced().weight(.semibold))
                        }
                        Spacer()
                        if p.qrPayload != nil { Image(systemName: "qrcode").foregroundStyle(.secondary) }
                    }
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle("Choose a code")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .modalTracked()
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 320)
        #endif
    }
}
