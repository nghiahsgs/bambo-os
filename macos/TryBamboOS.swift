// Try BamboOS: a small window in front of scripts/try-bambo.sh.
//
// The app decides nothing about the VM itself. It turns the choices in the
// window into the environment variables that try-bambo.sh documents, and asks
// the script for the state (--info) and to stop or reset the VM.
//
// Build: make app   (scripts/build-app.sh, needs the Xcode command line tools)

import AppKit
import ApplicationServices
import SwiftUI

// MARK: - Tessera colours (themes/tessera/tokens.md)

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255)
    }
    static let bg = Color(hex: 0x101012)
    static let surface = Color(hex: 0x161618)
    static let hairline = Color.white.opacity(0.08)
    static let fg = Color(hex: 0xf4f4f5)
    static let muted = Color(hex: 0x8e8e96)
    static let accentBlue = Color(hex: 0x5b8def)
    static let accentOrange = Color(hex: 0xff8a4c)
    static let accentGreen = Color(hex: 0x3ecf8e)
}

// MARK: - The script

/// Runs scripts/try-bambo.sh from the repository this app was built from.
struct Script {
    let repo: URL

    static func locate() -> Script? {
        // build-app.sh writes the repository path into Info.plist.
        if let path = Bundle.main.object(forInfoDictionaryKey: "BamboRepo") as? String,
           FileManager.default.isExecutableFile(atPath: path + "/scripts/try-bambo.sh") {
            return Script(repo: URL(fileURLWithPath: path))
        }
        return nil
    }

    var path: String { repo.path + "/scripts/try-bambo.sh" }
    var logURL: URL { repo.appendingPathComponent("out/try.log") }

    /// Apps started from Finder get a short PATH without Homebrew.
    func environment(_ extra: [String: String] = [:]) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let path = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + path
        // Never inherit these: the window is the only source.
        for key in ["BAMBO_SHARE", "BAMBO_WINDOWED", "BAMBO_CLIPBOARD", "BAMBO_MEM", "BAMBO_CPUS",
                    "BAMBO_STATE", "BAMBO_DRY_RUN", "BAMBO_RES", "BAMBO_QEMU_EXTRA"] {
            env.removeValue(forKey: key)
        }
        for (key, value) in extra { env[key] = value }
        return env
    }

    /// Run a short command (--info, --stop, --kill, --reset) and return its output.
    func run(_ argument: String) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [path, argument]
        process.environment = environment()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return (1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    /// Start the VM. Output goes to out/try.log, so the VM outlives this app.
    func start(_ settings: [String: String]) throws {
        try FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let log = try FileHandle(forWritingTo: logURL)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [path]
        process.environment = environment(settings)
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = log
        process.standardError = log
        try process.run()
    }
}

// MARK: - State

struct VMInfo: Equatable {
    var image = ""
    var imageSize: Int64 = 0
    var imageDate: Date?
    var disk = "none"          // none, current, stale
    var diskSize: Int64 = 0
    var pid = ""

    var running: Bool { !pid.isEmpty }

    init() {}
    init(parsing text: String) {
        for line in text.split(separator: "\n") {
            guard let equals = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<equals])
            let value = String(line[line.index(after: equals)...])
            switch key {
            case "image": image = value
            case "image_size": imageSize = Int64(value) ?? 0
            case "image_mtime": imageDate = TimeInterval(value).map { Date(timeIntervalSince1970: $0) }
            case "disk": disk = value
            case "disk_size": diskSize = Int64(value) ?? 0
            case "pid": pid = value
            default: break
            }
        }
    }
}

@MainActor
final class Model: ObservableObject {
    let script: Script?
    @Published var info = VMInfo()
    @Published var log = ""
    @Published var message = ""
    @Published var keyboardGranted = AXIsProcessTrusted()
    @Published var stopping = false

    @AppStorage("shareEnabled") var shareEnabled = false
    @AppStorage("sharePath") var sharePath = ""
    @AppStorage("fullScreen") var fullScreen = true
    @AppStorage("clipboard") var clipboard = true
    @AppStorage("memoryGB") var memoryGB = 4
    @AppStorage("cpus") var cpus = 4

    private var timer: Timer?

    init() {
        script = Script.locate()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        guard let script else { return }
        keyboardGranted = AXIsProcessTrusted()
        Task.detached {
            let result = script.run("--info")
            let text = (try? String(contentsOf: script.logURL, encoding: .utf8)) ?? ""
            let tail = text.split(separator: "\n").suffix(6).joined(separator: "\n")
            await MainActor.run {
                let next = VMInfo(parsing: result.output)
                if next != self.info { self.info = next }
                if !next.running { self.stopping = false }
                if tail != self.log { self.log = tail }
            }
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Share"
        panel.message = "The VM can read and change everything in this folder."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // Touch the folder now, so a macOS permission question appears here
        // and not behind the full-screen VM.
        _ = try? FileManager.default.contentsOfDirectory(atPath: url.path)
        sharePath = url.path
        shareEnabled = true
        message = ""
    }

    func start() {
        guard let script else { return }
        var settings = [
            "BAMBO_WINDOWED": fullScreen ? "0" : "1",
            "BAMBO_CLIPBOARD": clipboard ? "1" : "0",
            "BAMBO_MEM": String(memoryGB * 1024),
            "BAMBO_CPUS": String(cpus),
        ]
        if shareEnabled && !sharePath.isEmpty { settings["BAMBO_SHARE"] = sharePath }
        message = ""
        do {
            try script.start(settings)
        } catch {
            message = "Could not start: \(error.localizedDescription)"
            return
        }
        // The script refuses a bad folder or a missing image within a moment.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self else { return }
            self.refresh()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !self.info.running { self.message = "The VM did not start. See the last lines below." }
            }
        }
    }

    func stop() {
        guard let script else { return }
        stopping = true
        Task.detached {
            let result = script.run("--stop")
            if result.status != 0 {
                await MainActor.run {
                    self.stopping = false
                    self.message = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
    }

    func forceStop() {
        guard let script else { return }
        Task.detached { _ = script.run("--kill") }
    }

    func reset() {
        guard let script else { return }
        let alert = NSAlert()
        alert.messageText = "Delete the VM disk?"
        alert.informativeText = "Everything saved inside the VM is lost: files, logins and settings. "
            + "A shared folder on the Mac is not touched."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let result = script.run("--reset")
        message = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        refresh()
    }

    func openKeyboardSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Views

struct Card<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.muted)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.hairline, lineWidth: 1))
    }
}

struct ContentView: View {
    @StateObject private var model = Model()

    private func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private var imageLine: String {
        guard !model.info.image.isEmpty else { return "No image yet" }
        return (model.info.image as NSString).lastPathComponent
    }

    private var imageDetail: String {
        guard !model.info.image.isEmpty else {
            return "Build one first: run \"make arm64\" in the bambo-os folder."
        }
        var parts = [size(model.info.imageSize)]
        if let date = model.info.imageDate {
            parts.append("built " + date.formatted(date: .abbreviated, time: .shortened))
        }
        return parts.joined(separator: ", ")
    }

    private var diskDetail: String {
        switch model.info.disk {
        case "current": return "VM disk: \(size(model.info.diskSize)) of your changes. Kept between starts."
        case "stale": return "The image was rebuilt. The next start begins with a clean VM disk."
        default: return "No VM disk yet. The first start creates one."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if model.script == nil {
                Card(title: "Not set up") {
                    Text("This app cannot find the bambo-os folder it was built from. Run \"make app\" there again.")
                        .foregroundStyle(Color.fg)
                }
            } else {
                imageCard
                folderCard
                optionsCard
                keyboardCard
                if !model.message.isEmpty {
                    Text(model.message)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentOrange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !model.log.isEmpty {
                    Text(model.log)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(Color.muted)
                        .lineLimit(6)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                buttons.padding(.top, 4)
            }
        }
        .padding(20)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.bg)
        .foregroundStyle(Color.fg)
        .preferredColorScheme(.dark)
        .onAppear { snapshotIfAsked() }
    }

    /// Test hook: BAMBO_APP_SNAPSHOT=/path/file.png saves a picture of the
    /// window a moment after launch, then quits.
    private func snapshotIfAsked() {
        guard let path = ProcessInfo.processInfo.environment["BAMBO_APP_SNAPSHOT"] else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if let view = NSApp.windows.first(where: { $0.isVisible })?.contentView,
               let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            }
            NSApp.terminate(nil)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Try BamboOS").font(.system(size: 22, weight: .semibold))
                Text("BamboOS in a virtual machine on this Mac")
                    .font(.system(size: 12)).foregroundStyle(Color.muted)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(model.info.running ? Color.accentGreen : Color.muted)
                    .frame(width: 8, height: 8)
                Text(model.info.running ? "Running" : "Stopped")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(model.info.running ? Color.accentGreen : Color.muted)
            }
        }
    }

    private var imageCard: some View {
        Card(title: "Image") {
            Text(imageLine).font(.system(size: 13, weight: .medium, design: .monospaced))
            Text(imageDetail).font(.system(size: 12)).foregroundStyle(Color.muted)
            if !model.info.image.isEmpty {
                Text(diskDetail)
                    .font(.system(size: 12))
                    .foregroundStyle(model.info.disk == "stale" ? Color.accentOrange : Color.muted)
            }
        }
    }

    private var folderCard: some View {
        Card(title: "Shared folder") {
            Toggle("Share a Mac folder with the VM", isOn: model.$shareEnabled)
                .toggleStyle(.switch)
                .disabled(model.info.running)
            HStack(spacing: 10) {
                Text(model.sharePath.isEmpty ? "No folder chosen" : model.sharePath)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(model.shareEnabled && !model.sharePath.isEmpty ? Color.fg : Color.muted)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Choose…") { model.chooseFolder() }
                    .disabled(model.info.running)
            }
            Text("It appears in the VM as ~/Mac. The VM can read and change everything in it. "
                 + "A change takes effect at the next start.")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var optionsCard: some View {
        Card(title: "Options") {
            HStack(spacing: 24) {
                Toggle("Full screen", isOn: model.$fullScreen)
                Toggle("Share the clipboard", isOn: model.$clipboard)
            }
            HStack(spacing: 24) {
                Picker("Memory", selection: model.$memoryGB) {
                    ForEach([4, 6, 8, 12, 16], id: \.self) { Text("\($0) GB").tag($0) }
                }
                .frame(width: 170)
                Picker("CPU cores", selection: model.$cpus) {
                    ForEach([2, 4, 6, 8], id: \.self) { Text("\($0)").tag($0) }
                }
                .frame(width: 150)
            }
        }
        .disabled(model.info.running)
    }

    private var keyboardCard: some View {
        Card(title: "Keyboard") {
            if model.keyboardGranted {
                Text("Cmd + Space and Cmd + Tab go to the VM.")
                    .font(.system(size: 12)).foregroundStyle(Color.accentGreen)
            } else {
                Text("macOS keeps Cmd + Space and Cmd + Tab for itself. In the VM, use Cmd + R for the launcher. "
                     + "To send them to the VM, allow Try BamboOS under Accessibility.")
                    .font(.system(size: 12)).foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Accessibility settings") { model.openKeyboardSettings() }
            }
            Text("Leave the VM: Ctrl + Option + G releases the keyboard, Cmd + F leaves full screen.")
                .font(.system(size: 11.5)).foregroundStyle(Color.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            Button("Reset VM disk…") { model.reset() }
                .disabled(model.info.running || model.info.disk == "none")
            Spacer()
            if model.info.running {
                if model.stopping {
                    Button("Force stop") { model.forceStop() }
                }
                Button(model.stopping ? "Shutting down…" : "Shut down") { model.stop() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.stopping)
            } else {
                Button("Start BamboOS") { model.start() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.info.image.isEmpty)
            }
        }
        .controlSize(.large)
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    // One window is the whole app: closing it quits, so opening the app again
    // always shows the window. A running VM is not affected.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct TryBamboOSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("Try BamboOS", id: "main") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
