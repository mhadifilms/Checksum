import Foundation
import ArgumentParser
import ChecksumKit

struct FastClone: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "checksum",
        abstract: "MD5-verified cloning: copy sources to destinations with verification.")

    @Option(name: .shortAndLong, help: "Source paths (files or folders)")
    var source: [String]

    @Option(name: .shortAndLong, help: "Destination folders (one or more)")
    var destination: [String]

    @Flag(name: .shortAndLong, help: "Overwrite destination files if they exist")
    var overwrite: Bool = false

    @Option(name: .long, help: "Max concurrent copies (default: number of CPUs)")
    var concurrency: Int?

    @Flag(name: .long, help: "Emit JSON lines for each completed file")
    var json: Bool = false

    func run() throws {
        let sources = source.map { URL(fileURLWithPath: $0) }
        let destinations = destination.map { URL(fileURLWithPath: $0) }
        let options = CopyOptions(overwrite: overwrite)
        let job = CloneJob(sources: sources, destinations: destinations, options: options)
        let planner = Planner()
        let plans = try planner.expand(job: job)
        let verifier = CopyVerifier()

        let start = Date()
        let maxConcurrent = concurrency ?? max(1, ProcessInfo.processInfo.processorCount - 1)
        let semaphore = DispatchSemaphore(value: maxConcurrent)
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "fastclone.copy", attributes: .concurrent)
        let failuresLock = NSLock()
        var failures: [Error] = []

        for plan in plans {
            for dest in plan.destinationFiles {
                group.enter()
                semaphore.wait()
                queue.async {
                    do {
                        let result = try verifier.copyAndVerifyFile(source: plan.sourceFile, destination: dest, options: options) { done, total in
                            let pct = total > 0 ? Int((Double(done) / Double(total)) * 100.0) : 0
                            fputs("PROGRESS \(pct)%: \(plan.sourceFile.lastPathComponent) -> \(dest.lastPathComponent)\n", stderr)
                        }
                        if json {
                            if let data = try? JSONEncoder().encode(result), let line = String(data: data, encoding: .utf8) {
                                print(line)
                            }
                        } else {
                            print("OK \(plan.sourceFile.path) -> \(dest.path)")
                        }
                    } catch {
                        failuresLock.lock(); failures.append(error); failuresLock.unlock()
                        fputs("ERROR: \(error)\n", stderr)
                    }
                    group.leave(); semaphore.signal()
                }
            }
        }
        group.wait()
        let elapsed = String(format: "%.2fs", Date().timeIntervalSince(start))
        if failures.isEmpty {
            print("Completed \(plans.count) item(s) in \(elapsed)")
        } else {
            throw ExitCode.failure
        }
    }
}

@discardableResult
func awaitResult<T>(_ operation: @autoclosure () throws -> T) rethrows -> T { try operation() }

FastClone.main()


