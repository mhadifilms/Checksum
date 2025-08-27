import Foundation
import SwiftUI
import ChecksumKit
import UserNotifications

@MainActor
final class CloneViewModel: ObservableObject {
    struct Job: Identifiable, Codable, Sendable {
        let id: UUID
        var sources: [URL]
        var destinations: [URL]
        var createdAt: Date
        var completedAt: Date?
        var status: String // queued, running, success, failed
        var logPath: URL?
    }

    @Published var jobs: [Job] = []
    @Published var selectedJobId: UUID?
    @Published var sources: [URL] = []
    @Published var destinations: [URL] = []
    @Published var isCloning: Bool = false
    @Published var overallProgress: Double = 0
    @Published var overwrite: Bool = false
    @Published var startedAt: Date?
    @Published var remainingText: String = ""
    @Published var destinationProgress: [UUID: [URL: Double]] = [:]

    private var processingQueue = false
    private var shouldCancel = false
    private var emaThroughput: Double = 0
    nonisolated(unsafe) private var cancelFlagUnsafe: Bool = false

    private let planner = Planner()

    func addSources(urls: [URL]) { sources.append(contentsOf: urls) }
    func addDestinations(urls: [URL]) { destinations.append(contentsOf: urls) }
    func removeSource(at offsets: IndexSet) { sources.remove(atOffsets: offsets) }
    func removeDestination(at offsets: IndexSet) { destinations.remove(atOffsets: offsets) }

    func startClone() async {
        guard !isCloning else { return }
        isCloning = true
        overallProgress = 0
        startedAt = Date()
        remainingText = ""
        let sourcesSnapshot = sources
        let destinationsSnapshot = destinations
        let options = CopyOptions(overwrite: overwrite)
        // Persist a job record and JSONL log path
        let jobId = UUID()
        let logURL = self.jobLogURL(for: jobId)
        appendJSONL(logURL, ["event": "job_created", "id": jobId.uuidString])
        let job = Job(id: jobId, sources: sourcesSnapshot, destinations: destinationsSnapshot, createdAt: Date(), completedAt: nil, status: "running", logPath: logURL)
        self.jobs.append(job)
        saveJobs()

        destinationProgress[jobId] = Dictionary(uniqueKeysWithValues: destinationsSnapshot.map { ($0, 0.0) })

        Task.detached { [weak self, sourcesSnapshot, destinationsSnapshot, options, jobId, logURL] in
            do {
                let planner = Planner()
                let job = CloneJob(sources: sourcesSnapshot, destinations: destinationsSnapshot, options: options)
                let plans = try planner.expand(job: job)
                let totalFiles = plans.count * max(1, destinationsSnapshot.count)
                var completed = 0
                for plan in plans {
                    for dest in plan.destinationFiles {
                        if self?.cancelFlagUnsafe == true { throw CopyError.cancelled }
                        do {
                            let verifier = CopyVerifier()
                            let cancelCheck: () -> Bool = { self?.cancelFlagUnsafe ?? false }
                            _ = try verifier.copyAndVerifyFile(source: plan.sourceFile, destination: dest, options: options, progress: { done, total in
                                let ratio = total > 0 ? Double(done) / Double(total) : 0
                                Task { @MainActor [weak self] in
                                    guard let self, let startedAt = self.startedAt else { return }
                                    // Smooth ETA using exponential moving average of throughput
                                    let elapsed = Date().timeIntervalSince(startedAt)
                                    let bytesDone = Double(done)
                                    let totalBytes = Double(total)
                                    let instThroughput = bytesDone / max(elapsed, 0.001)
                                    self.emaThroughput = self.emaThroughput * 0.85 + instThroughput * 0.15
                                    let remainingBytes = max(totalBytes - bytesDone, 0)
                                    let remaining = self.emaThroughput > 0 ? remainingBytes / self.emaThroughput : 0
                                    self.remainingText = "Elapsed: \(self.formatTime(elapsed)) • Remaining: \(self.formatTime(remaining))"
                                    var map = self.destinationProgress[jobId] ?? [:]
                                    map[dest] = ratio
                                    self.destinationProgress[jobId] = map
                                }
                            }, cancel: cancelCheck)
                            self?.appendJSONL(logURL, ["event": "file_ok", "src": plan.sourceFile.path, "dst": dest.path])
                            completed += 1
                            let progress = Double(completed) / Double(totalFiles)
                            Task { @MainActor [weak self] in
                                self?.overallProgress = progress
                                var map = self?.destinationProgress[jobId] ?? [:]
                                map[dest] = 1.0
                                self?.destinationProgress[jobId] = map
                            }
                        } catch {
                            self?.appendJSONL(logURL, ["event": "file_error", "src": plan.sourceFile.path, "dst": dest.path, "error": error.localizedDescription])
                            completed += 1
                            let progress = Double(completed) / Double(totalFiles)
                            Task { @MainActor [weak self] in
                                self?.overallProgress = progress
                            }
                        }
                    }
                }
            } catch {
                // Surface error with NSAlert later if needed
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isCloning = false
                
                // Check if cancelled
                if self.cancelFlagUnsafe {
                    self.sendCancellationNotification()
                    self.markJobCancelled(id: jobId)
                } else {
                    self.sendCompletionNotification()
                    self.markJobCompleted(id: jobId)
                }
            }
        }
    }

    // MARK: - Queue
    func enqueueCurrentJob() {
        let id = UUID()
        let record = Job(id: id, sources: sources, destinations: destinations, createdAt: Date(), completedAt: nil, status: "queued", logPath: jobLogURL(for: id))
        jobs.append(record)
        saveJobs()
    }

    func startQueue() {
        guard !processingQueue else { return }
        processingQueue = true
        cancelFlagUnsafe = false
        Task {
            if let idx = jobs.firstIndex(where: { $0.status == "queued" }) {
                let job = jobs[idx]
                await runJob(job)
            }
            processingQueue = false
        }
    }

    private func runJob(_ job: Job) async {
        await MainActor.run {
            self.sources = job.sources
            self.destinations = job.destinations
        }
        await startClone()
    }

    func stopCurrentJob() {
        cancelFlagUnsafe = true
    }

    private func markJobCompleted(id: UUID) {
        if let idx = jobs.firstIndex(where: { $0.id == id }) {
            jobs[idx].completedAt = Date()
            jobs[idx].status = "success"
            saveJobs()
        }
    }
    
    private func markJobCancelled(id: UUID) {
        if let idx = jobs.firstIndex(where: { $0.id == id }) {
            jobs[idx].completedAt = Date()
            jobs[idx].status = "cancelled"
            saveJobs()
        }
    }

    private func markJobFailed(id: UUID, error: Error) {
        if let idx = jobs.firstIndex(where: { $0.id == id }) {
            jobs[idx].completedAt = Date()
            jobs[idx].status = "failed"
            saveJobs()
        }
    }

    private func jobLogURL(for id: UUID) -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Checksum", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("job_\(id.uuidString).jsonl")
    }

    nonisolated private func appendJSONL(_ url: URL, _ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
        let line = (String(data: data, encoding: .utf8) ?? "") + "\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            if let d = line.data(using: .utf8) { try? handle.write(contentsOf: d) }
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func saveJobs() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Checksum", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("jobs.json")
        if let data = try? JSONEncoder().encode(jobs) { try? data.write(to: url) }
    }

    private func sendCompletionNotification() {
        // Reveal the first actual destination folder (if user selected a file as source, we still map to folder paths)
        guard let firstDest = destinations.first else { return }
        let isBundled = (Bundle.main.bundleIdentifier != nil) && (Bundle.main.bundleURL.pathExtension == "app")
        if isBundled {
            let content = UNMutableNotificationContent()
            content.title = "Clone Complete"
            content.body = "All copies verified successfully."
            content.sound = .default
            content.categoryIdentifier = "CLONE_DONE"
            content.userInfo = ["dest": firstDest.path]
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        } else {
            let alert = NSAlert()
            alert.messageText = "Clone Complete"
            alert.informativeText = "All copies verified successfully."
            alert.addButton(withTitle: "View")
            alert.addButton(withTitle: "OK")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open the folder itself in Finder
                NSWorkspace.shared.open(firstDest)
            }
        }
    }
    
    private func sendCancellationNotification() {
        let isBundled = (Bundle.main.bundleIdentifier != nil) && (Bundle.main.bundleURL.pathExtension == "app")
        if isBundled {
            let content = UNMutableNotificationContent()
            content.title = "Operation Cancelled"
            content.body = "The copy operation was stopped."
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        } else {
            let alert = NSAlert()
            alert.messageText = "Operation Cancelled"
            alert.informativeText = "The copy operation was stopped."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func sendErrorNotification(error: Error) {
        let isBundled = (Bundle.main.bundleIdentifier != nil) && (Bundle.main.bundleURL.pathExtension == "app")
        if isBundled {
            let content = UNMutableNotificationContent()
            content.title = "Clone Failed"
            content.body = "The copy operation failed: \(error.localizedDescription)"
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        } else {
            let alert = NSAlert()
            alert.messageText = "Clone Failed"
            alert.informativeText = "The copy operation failed: \(error.localizedDescription)"
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }
}


