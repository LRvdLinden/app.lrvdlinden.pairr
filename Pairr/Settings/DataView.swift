import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Backups, export, import and deleting data.
struct DataView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Device.name) private var devices: [Device]
    @AppStorage(AutoBackup.enabledKey) private var autoBackup = true

    @State private var exported: URL?
    @State private var showSave = false
    @State private var askPassword = false
    @State private var password = ""
    @State private var password2 = ""
    @State private var importing = false
    @State private var importType: UTType = .pairrBackup
    @State private var pendingBackup: Data?
    @State private var restorePassword = ""
    @State private var askRestorePassword = false
    @State private var message: String?
    @State private var busy = false
    @State private var autoBackups: [URL] = []
    @State private var confirmWipe = false
    @State private var confirmWipeAgain = false
    @State private var lastAuto = AutoBackup.lastDate

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $autoBackup) {
                    Label("Weekly backup to iCloud Drive", systemImage: "clock.arrow.circlepath")
                }
                LabeledContent("Last backup") {
                    if let lastAuto { Text(lastAuto, format: .dateTime.day().month().year().hour().minute()) } else { Text("Not yet") }
                }
                Button { Task { await backupNow() } } label: { Label("Back up now", systemImage: "icloud.and.arrow.up") }
                    .disabled(devices.isEmpty || busy)
                ForEach(autoBackups, id: \.self) { url in
                    Button { restoreAuto(url) } label: {
                        Label {
                            Text(verbatim: url.deletingPathExtension().lastPathComponent)
                        } icon: {
                            Image(systemName: "arrow.counterclockwise.icloud")
                        }
                    }
                }
            } header: {
                Text("Automatic backup")
            } footer: {
                Text("Encrypted, in iCloud Drive → Pairr → Backups. The last 5 are kept. Tap a backup to restore devices that are missing.")
            }

            Section {
                ForEach(ExportFormat.allCases) { format in
                    Button {
                        if format == .backup { password = ""; password2 = ""; askPassword = true } else { export(format) }
                    } label: {
                        Label(format.title, systemImage: format.symbol)
                    }
                    .disabled(devices.isEmpty || busy)
                }
                if let exported {
                    ShareLink(item: exported) {
                        Label {
                            Text(verbatim: exported.lastPathComponent)
                        } icon: {
                            Image(systemName: "square.and.arrow.up").foregroundStyle(Theme.accent)
                        }
                    }
                    Button { showSave = true } label: { Label("Save to Files…", systemImage: "folder") }
                }
            } header: {
                Text("Export")
            } footer: {
                Text("PDF, CSV and Markdown contain your codes as plain text. A Pairr backup is encrypted with your password and also works without iCloud.")
            }

            Section("Import") {
                Button { importType = .pairrBackup; importing = true } label: {
                    Label("Restore a Pairr backup", systemImage: "arrow.down.doc")
                }
                Button { importType = .commaSeparatedText; importing = true } label: {
                    Label("Import a CSV file", systemImage: "tablecells.badge.ellipsis")
                }
            }

            Section {
                Button("Delete all data", role: .destructive) { confirmWipe = true }
                    .disabled(devices.isEmpty)
            } footer: {
                Text("Deletes all devices and codes on all your devices and in iCloud. Backups in iCloud Drive stay unless you choose otherwise.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Backup and export")
        .overlay { if busy { ProgressView().controlSize(.large) } }
        .task { await loadAutoBackups() }
        .fileExporter(isPresented: $showSave, item: exported, contentTypes: [.data], defaultFilename: exported?.lastPathComponent) { _ in }
        .fileImporter(isPresented: $importing, allowedContentTypes: [importType, .data]) { result in
            guard case .success(let url) = result else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { message = String(localized: "The file couldn't be read."); return }
            handleImport(data, isCSV: url.pathExtension.lowercased() == "csv")
        }
        .alert("Backup password", isPresented: $askPassword) {
            SecureField("Password", text: $password)
            SecureField("Repeat password", text: $password2)
            Button("Export") { export(.backup) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("At least 8 characters. Without this password the backup can't be opened.")
        }
        .alert("Backup password", isPresented: $askRestorePassword) {
            SecureField("Password", text: $restorePassword)
            Button("Restore") { restorePasswordBackup() }
            Button("Cancel", role: .cancel) { pendingBackup = nil }
        }
        .alert("Pairr", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: message ?? "")
        }
        .confirmationDialog("Delete all data?", isPresented: $confirmWipe, titleVisibility: .visible) {
            Button("Delete, keep the backups", role: .destructive) { wipePending = .keepBackups; confirmWipeAgain = true }
            Button("Delete, including the backups", role: .destructive) { wipePending = .withBackups; confirmWipeAgain = true }
        } message: {
            Text("Make an export first if you want to keep your codes somewhere else.")
        }
        .alert("Are you sure?", isPresented: $confirmWipeAgain) {
            Button("Delete everything", role: .destructive) { wipe() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }

    private enum WipeMode { case keepBackups, withBackups }
    @State private var wipePending: WipeMode = .keepBackups

    // MARK: Actions

    private func export(_ format: ExportFormat) {
        if format == .backup {
            guard password == password2 else { message = String(localized: "The passwords don't match."); return }
        }
        do {
            exported = try ExportService.export(format, devices: devices, password: password)
        } catch {
            message = error.localizedDescription
        }
        password = ""; password2 = ""
    }

    private func backupNow() async {
        busy = true
        defer { busy = false }
        do {
            if try await AutoBackup.run(container: context.container) == nil {
                message = String(localized: "iCloud Drive is not available. Turn it on in Settings, or export a backup with a password.")
            }
            lastAuto = AutoBackup.lastDate
            await loadAutoBackups()
        } catch {
            message = error.localizedDescription
        }
    }

    private func loadAutoBackups() async {
        autoBackups = await Task.detached { AutoBackup.list() }.value
    }

    private func restoreAuto(_ url: URL) {
        Task {
            busy = true
            defer { busy = false }
            // Downloads the file from iCloud Drive when needed.
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            var data: Data?
            for _ in 0..<20 {
                data = try? Data(contentsOf: url)
                if data != nil { break }
                try? await Task.sleep(for: .milliseconds(500))
            }
            guard let data else { message = String(localized: "The file couldn't be read."); return }
            handleImport(data, isCSV: false)
        }
    }

    private func handleImport(_ data: Data, isCSV: Bool) {
        do {
            if Backup.isPasswordBackup(data) {
                pendingBackup = data
                restorePassword = ""
                askRestorePassword = true
            } else if Backup.isVaultBackup(data) {
                report(try Backup.restore(Backup.openWithVault(data), into: context))
            } else if isCSV || String(data: data.prefix(200), encoding: .utf8) != nil {
                let n = try CSVImport.run(data, into: context)
                message = String(format: String(localized: "%lld devices imported."), n)
            } else {
                throw BackupError.notABackup
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func restorePasswordBackup() {
        guard let data = pendingBackup else { return }
        pendingBackup = nil
        do {
            report(try Backup.restore(Backup.openWithPassword(data, password: restorePassword), into: context))
        } catch {
            message = error.localizedDescription
        }
        restorePassword = ""
    }

    private func report(_ r: (added: Int, skipped: Int)) {
        message = String(format: String(localized: "%lld devices restored, %lld were already there."), r.added, r.skipped)
    }

    private func wipe() {
        for d in devices { context.delete(d) }
        try? context.save()
        if wipePending == .withBackups {
            for url in AutoBackup.list() { try? FileManager.default.removeItem(at: url) }
            UserDefaults.standard.removeObject(forKey: AutoBackup.lastKey)
            autoBackups = []
            lastAuto = nil
        }
        message = String(localized: "All data has been deleted.")
    }
}
