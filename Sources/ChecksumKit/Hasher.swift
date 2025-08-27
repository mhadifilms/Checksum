import Foundation
import CryptoKit

public struct MD5Digest: Equatable, Sendable {
    public let hexString: String
}

public enum HasherError: Error {
    case cannotOpenFile(URL)
    case readFailed(URL, underlying: Error?)
}

public enum Hasher {
    /// Stream a file through MD5 in chunks to avoid memory spikes.
    public static func md5(of fileURL: URL, chunkSize: Int = 2 * 1024 * 1024) throws -> MD5Digest {
        guard let stream = InputStream(url: fileURL) else { throw HasherError.cannotOpenFile(fileURL) }
        stream.open()
        defer { stream.close() }

        var context = Insecure.MD5()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: chunkSize)
            if read < 0 {
                throw HasherError.readFailed(fileURL, underlying: stream.streamError)
            }
            if read == 0 { break }
            context.update(data: Data(bytes: buffer, count: read))
        }

        let digest = context.finalize()
        let hex = digest.map { String(format: "%02hhx", $0) }.joined()
        return MD5Digest(hexString: hex)
    }
}


