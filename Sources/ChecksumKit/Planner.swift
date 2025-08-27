import Foundation

public struct CloneJob: Sendable {
    public let sources: [URL]
    public let destinations: [URL]
    public let options: CopyOptions

    public init(sources: [URL], destinations: [URL], options: CopyOptions) {
        self.sources = sources
        self.destinations = destinations
        self.options = options
    }
}

public enum PlannerError: Error {
    case noSources
    case noDestinations
}

public struct PlannedCopy: Sendable {
    public let sourceFile: URL
    public let destinationFiles: [URL]
}

public struct Planner {
    public init() {}

    public func expand(job: CloneJob) throws -> [PlannedCopy] {
        guard !job.sources.isEmpty else { throw PlannerError.noSources }
        guard !job.destinations.isEmpty else { throw PlannerError.noDestinations }

        var plans: [PlannedCopy] = []
        for src in job.sources {
            let srcIsDir = (try? src.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if srcIsDir {
                let enumerator = FileManager.default.enumerator(at: src, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
                while let file = enumerator?.nextObject() as? URL {
                    let isDir = (try? file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if isDir { continue }
                    let relPath = file.path.replacingOccurrences(of: src.path, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    // Copy CONTENTS of src into destination (not nesting the top-level folder)
                    let destinations = job.destinations.map { $0.appendingPathComponent(relPath) }
                    plans.append(PlannedCopy(sourceFile: file, destinationFiles: destinations))
                }
            } else {
                let destinations = job.destinations.map { $0.appendingPathComponent(src.lastPathComponent) }
                plans.append(PlannedCopy(sourceFile: src, destinationFiles: destinations))
            }
        }
        return plans
    }
}


