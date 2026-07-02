// Stem Lab — native wrapper around the bundled stem-splitting engine.
// Drop a song (or drop it on the Dock icon), watch both models' progress,
// stop mid-run, open the stems folder when done.

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Paths

enum Paths {
    static let dest = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/StemLab")
    static let caches = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Caches/StemLab")
    static let engine = dest.appendingPathComponent("stemlab.sh")
    static let rfLog = caches.appendingPathComponent("last_rf.log")
    static let ftLog = caches.appendingPathComponent("last_ft.log")
    static var payload: URL? { Bundle.main.url(forResource: "payload", withExtension: "tar.gz") }
    static var bundledVersion: String {
        guard let u = Bundle.main.url(forResource: "VERSION", withExtension: nil),
              let s = try? String(contentsOf: u, encoding: .utf8) else { return "?" }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static var installedVersion: String {
        (try? String(contentsOf: dest.appendingPathComponent("VERSION"), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

// MARK: - tqdm log parsing (port of split's snap())

struct Snap {
    var starts = 0
    var pct = 0
    var phase = "load"
    var eta = ""
}

func snapLog(_ url: URL) -> Snap {
    guard let data = try? Data(contentsOf: url),
          let text = String(data: data, encoding: .utf8) else { return Snap() }
    var s = Snap()
    let pctRe = try! NSRegularExpression(pattern: #"^ *([0-9]+)%\|"#)
    let etaRe = try! NSRegularExpression(pattern: #"<([0-9:]+),"#)
    for raw in text.split(whereSeparator: { $0 == "\r" || $0 == "\n" }) {
        let line = String(raw)
        let range = NSRange(line.startIndex..., in: line)
        if line.contains("[00:00<?") { s.starts += 1 }
        if let m = pctRe.firstMatch(in: line, range: range),
           let r = Range(m.range(at: 1), in: line), let p = Int(line[r]) {
            s.pct = p
            s.phase = "sep"
            if let e = etaRe.firstMatch(in: line, range: range),
               let er = Range(e.range(at: 1), in: line) { s.eta = String(line[er]) }
        }
        if line.contains("Saving "), line.contains(" stem") { s.phase = "write" }
    }
    return s
}

func fmtMMSS(_ secs: Int) -> String { String(format: "%d:%02d", secs / 60, secs % 60) }

// MARK: - Job controller

enum JobState: Equatable {
    case idle
    case installing
    case running
    case done(secs: Int)
    case failed(message: String, logTail: String)
}

final class StageProgress: ObservableObject, Identifiable {
    let id: String
    let label: String
    let nModels: Int
    let logURL: URL
    @Published var overall: Double = 0
    @Published var info: String = "Loading Model"
    @Published var finished = false

    init(label: String, nModels: Int, logURL: URL) {
        self.id = label
        self.label = label
        self.nModels = nModels
        self.logURL = logURL
    }

    func refresh() {
        guard !finished else { return }
        let s = snapLog(logURL)
        if s.starts == 0 {
            overall = 0
            info = "Loading Model"
            return
        }
        overall = min(100, Double(((s.starts - 1) * 100 + s.pct) / nModels))
        var parts = [s.phase == "write" ? "Writing Stems" : "Separating"]
        if nModels > 1 { parts.append("Model \(min(s.starts, nModels))/\(nModels)") }
        if s.phase == "sep", !s.eta.isEmpty { parts.append("ETA \(s.eta)") }
        info = parts.joined(separator: " · ")
    }

    func markDone() {
        overall = 100
        info = "Done"
        finished = true
    }
}

final class JobController: ObservableObject {
    @Published var state: JobState = .idle
    @Published var fileName = ""
    @Published var elapsed = 0
    let vocals = StageProgress(label: "Vocals", nModels: 1, logURL: Paths.rfLog)
    let band = StageProgress(label: "Drums / Bass / Other", nModels: 4, logURL: Paths.ftLog)

    private var process: Process?
    private var timer: Timer?
    private var startedAt = Date()
    private var stopRequested = false
    private(set) var stemsDir: URL?

    var isBusy: Bool {
        if case .idle = state { return false }
        if case .done = state { return false }
        if case .failed = state { return false }
        return true
    }

    // MARK: lifecycle

    func start(with url: URL) {
        guard !isBusy else { NSSound.beep(); return }
        fileName = url.lastPathComponent
        stemsDir = url.deletingLastPathComponent()
            .appendingPathComponent("stems")
            .appendingPathComponent(url.deletingPathExtension().lastPathComponent)
        stopRequested = false
        resetStages()
        state = .installing
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.installIfNeededThenRun(url)
        }
    }

    func stop() {
        stopRequested = true
        process?.terminate()   // SIGTERM; stemlab.sh's trap kills both model processes
    }

    func reset() {
        state = .idle
        fileName = ""
        elapsed = 0
        resetStages()
    }

    func openStemsFolder() {
        guard let dir = stemsDir else { return }
        NSWorkspace.shared.activateFileViewerSelecting(
            (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))
                ?? [dir]
        )
    }

    private func resetStages() {
        for s in [vocals, band] {
            s.overall = 0
            s.info = "Loading Model"
            s.finished = false
        }
    }

    // MARK: engine

    private func installIfNeededThenRun(_ url: URL) {
        let fm = FileManager.default
        if !fm.isExecutableFile(atPath: Paths.engine.path) || Paths.installedVersion != Paths.bundledVersion {
            guard let payload = Paths.payload else {
                fail("App Bundle Is Damaged (Payload Missing)", ""); return
            }
            try? fm.removeItem(at: Paths.dest)
            do {
                try fm.createDirectory(at: Paths.dest, withIntermediateDirectories: true)
            } catch {
                fail("Could Not Create \(Paths.dest.path)", error.localizedDescription); return
            }
            let tar = Process()
            tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            tar.arguments = ["-xzf", payload.path, "-C", Paths.dest.path]
            do { try tar.run() } catch { fail("Could Not Unpack the Audio Engine", error.localizedDescription); return }
            tar.waitUntilExit()
            guard tar.terminationStatus == 0 else { fail("Audio Engine Unpack Failed", ""); return }
            // the tarball may carry an older VERSION file; the app decides the installed version
            try? Paths.bundledVersion.write(
                to: Paths.dest.appendingPathComponent("VERSION"), atomically: true, encoding: .utf8)
        }
        runEngine(url)
    }

    private func runEngine(_ url: URL) {
        // stale logs from a previous run would parse as instant progress
        try? FileManager.default.removeItem(at: Paths.rfLog)
        try? FileManager.default.removeItem(at: Paths.ftLog)

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [Paths.engine.path, url.path]
        var env = ProcessInfo.processInfo.environment
        env["NO_COLOR"] = "1"
        p.environment = env
        let out = Pipe()
        p.standardOutput = out
        p.standardError = out

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.process = p
            self.startedAt = Date()
            self.state = .running
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                self?.tick()
            }
        }

        do { try p.run() } catch {
            fail("Could Not Start the Engine", error.localizedDescription); return
        }
        let output = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()
        let status = p.terminationStatus
        let secs = Int(Date().timeIntervalSince(startedAt))

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.timer?.invalidate()
            self.timer = nil
            self.process = nil
            if self.stopRequested {
                self.reset()
            } else if status == 0 {
                self.vocals.markDone()
                self.band.markDone()
                self.state = .done(secs: secs)
            } else {
                let tail = output.split(separator: "\n").suffix(12).joined(separator: "\n")
                self.state = .failed(message: "Separation Failed (Exit \(status))", logTail: tail)
            }
        }
    }

    private func tick() {
        elapsed = Int(Date().timeIntervalSince(startedAt))
        vocals.refresh()
        band.refresh()
    }

    private func fail(_ message: String, _ detail: String) {
        DispatchQueue.main.async { [weak self] in
            self?.state = .failed(message: message, logTail: detail)
        }
    }
}

// MARK: - Views

struct StageRow: View {
    @ObservedObject var stage: StageProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(stage.label).font(.system(.body, weight: .medium))
                Spacer()
                Text("\(Int(stage.overall))%")
                    .font(.system(.body).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: stage.overall, total: 100)
            Text(stage.info)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct DropZone: View {
    let onFile: (URL) -> Void
    @State private var hovering = false
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 34))
                .foregroundStyle(hovering ? Color.accentColor : .secondary)
            Text("Drop a Song Here")
                .font(.title3.weight(.medium))
            Text("WAV · MP3 · FLAC · M4A")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Choose File…") { showPicker = true }
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 190)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                .foregroundStyle(hovering ? Color.accentColor : Color.secondary.opacity(0.5))
        )
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: $hovering) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { DispatchQueue.main.async { onFile(url) } }
            }
            return true
        }
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.audio]) { result in
            if case .success(let url) = result { onFile(url) }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var job: JobController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch job.state {
            case .idle:
                DropZone { job.start(with: $0) }

            case .installing:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Setting Up the Audio Engine…")
                        .font(.title3.weight(.medium))
                    Text("One Time Only · Takes a Minute or Two")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 190)

            case .running:
                Text(job.fileName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                StageRow(stage: job.vocals)
                StageRow(stage: job.band)
                HStack {
                    Text(fmtMMSS(job.elapsed))
                        .font(.system(.body).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(role: .destructive) { job.stop() } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                }

            case .done(let secs):
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.green)
                    Text("Done in \(fmtMMSS(secs))")
                        .font(.title3.weight(.medium))
                    Text("Vocals · Drums · Bass · Other")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Split Another…") { job.reset() }
                        Button {
                            job.openStemsFolder()
                        } label: {
                            Label("Open Stems Folder", systemImage: "folder")
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, minHeight: 190)

            case .failed(let message, let logTail):
                VStack(alignment: .leading, spacing: 8) {
                    Label(message, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.headline)
                    if !logTail.isEmpty {
                        ScrollView {
                            Text(logTail)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 110)
                        .padding(6)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    HStack { Spacer(); Button("OK") { job.reset() } }
                }
            }
        }
        .padding(18)
        .frame(width: 440)
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?
    var job: JobController?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        job?.start(with: url)
    }

    func applicationWillTerminate(_ notification: Notification) {
        job?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct StemLabApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var job = JobController()

    var body: some Scene {
        Window("Stem Lab", id: "main") {
            ContentView()
                .environmentObject(job)
                .onAppear { delegate.job = job }
        }
        .windowResizability(.contentSize)
    }
}
