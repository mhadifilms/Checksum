import Foundation
import CryptoKit

public enum CopyError: Error {
    case sourceNotFound(URL)
    case failedToCreateDirectory(URL, Error)
    case copyFailed(URL, URL, Error)
    case verificationFailed(URL, URL, expected: String, actual: String)
    case cancelled
}

public struct CopyOptions: Sendable {
    public var overwrite: Bool
    public var bufferSize: Int
    public var preserveDates: Bool
    public var followSymlinks: Bool

    public init(overwrite: Bool = false, bufferSize: Int = 8 * 1024 * 1024, preserveDates: Bool = true, followSymlinks: Bool = false) {
        self.overwrite = overwrite
        self.bufferSize = bufferSize
        self.preserveDates = preserveDates
        self.followSymlinks = followSymlinks
    }
}

public struct VerificationResult: Sendable, Codable {
    public let source: URL
    public let destination: URL
    public let md5: String
}

public final class CopyVerifier {
    private let fileManager = FileManager.default

    public init() {}

    public func copyAndVerifyFile(
        source: URL,
        destination: URL,
        options: CopyOptions = .init(),
        progress: ((Int64, Int64) -> Void)? = nil,
        cancel: (() -> Bool)? = nil
    ) throws -> VerificationResult {
        guard fileManager.fileExists(atPath: source.path) else { throw CopyError.sourceNotFound(source) }

        let destDir = destination.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: destDir.path) {
            do { try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true) }
            catch { throw CopyError.failedToCreateDirectory(destDir, error) }
        }

        if fileManager.fileExists(atPath: destination.path) {
            if options.overwrite {
                try? fileManager.removeItem(at: destination)
            } else {
                let srcMD5 = try Hasher.md5(of: source).hexString
                let dstMD5 = try Hasher.md5(of: destination).hexString
                if srcMD5 != dstMD5 { throw CopyError.verificationFailed(source, destination, expected: srcMD5, actual: dstMD5) }
                return VerificationResult(source: source, destination: destination, md5: dstMD5)
            }
        }

        let (srcMD5, dstMD5) = try streamCopyAndHash(from: source, to: destination, bufferSize: options.bufferSize, progress: progress, cancel: cancel)
        if srcMD5 != dstMD5 { throw CopyError.verificationFailed(source, destination, expected: srcMD5, actual: dstMD5) }

        if options.preserveDates {
            if let attrs = try? fileManager.attributesOfItem(atPath: source.path) {
                var newAttrs: [FileAttributeKey: Any] = [:]
                if let creation = attrs[.creationDate] { newAttrs[.creationDate] = creation }
                if let mod = attrs[.modificationDate] { newAttrs[.modificationDate] = mod }
                try? fileManager.setAttributes(newAttrs, ofItemAtPath: destination.path)
            }
        }

        return VerificationResult(source: source, destination: destination, md5: dstMD5)
    }

    private func streamCopyAndHash(from src: URL, to dst: URL, bufferSize: Int, progress: ((Int64, Int64) -> Void)?, cancel: (() -> Bool)?) throws -> (String, String) {
        guard let inStream = InputStream(url: src), let outStream = OutputStream(url: dst, append: false) else {
            do { try fileManager.copyItem(at: src, to: dst) } catch { throw CopyError.copyFailed(src, dst, error) }
            let srcMD5 = try Hasher.md5(of: src).hexString
            let dstMD5 = try Hasher.md5(of: dst).hexString
            return (srcMD5, dstMD5)
        }
        inStream.open(); outStream.open()
        defer { inStream.close(); outStream.close() }
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        var srcCtx = Insecure.MD5()
        var dstCtx = Insecure.MD5()
        let totalBytes = (try? FileManager.default.attributesOfItem(atPath: src.path)[.size] as? NSNumber)?.int64Value ?? 0
        var copied: Int64 = 0
        while inStream.hasBytesAvailable {
            if cancel?() == true { throw CopyError.cancelled }
            let read = inStream.read(buffer, maxLength: bufferSize)
            if read < 0 { throw inStream.streamError ?? CopyError.copyFailed(src, dst, NSError(domain: "InputStream", code: -1)) }
            if read == 0 { break }
            srcCtx.update(data: Data(bytes: buffer, count: read))
            var writtenTotal = 0
            while writtenTotal < read {
                if cancel?() == true { throw CopyError.cancelled }
                let written = outStream.write(buffer.advanced(by: writtenTotal), maxLength: read - writtenTotal)
                if written <= 0 { throw outStream.streamError ?? CopyError.copyFailed(src, dst, NSError(domain: "OutputStream", code: -1)) }
                writtenTotal += written
            }
            dstCtx.update(data: Data(bytes: buffer, count: read))
            copied += Int64(read)
            if let cb = progress { cb(copied, totalBytes) }
        }
        let srcMD5 = srcCtx.finalize().map { String(format: "%02hhx", $0) }.joined()
        let dstMD5 = dstCtx.finalize().map { String(format: "%02hhx", $0) }.joined()
        return (srcMD5, dstMD5)
    }
}


