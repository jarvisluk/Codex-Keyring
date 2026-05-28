import Darwin
import Foundation

enum OAuthCallbackConnectionReader {
    private static let headerTerminator = Data([0x0D, 0x0A, 0x0D, 0x0A])

    static func readHeader(from clientFD: Int32, maxBytes: Int = 32 * 1024) -> Data {
        var buffer = Data()
        let chunkSize = 4096
        var scratch = [UInt8](repeating: 0, count: chunkSize)

        while buffer.count < maxBytes {
            let bytesRead = scratch.withUnsafeMutableBytes { ptr in
                Darwin.read(clientFD, ptr.baseAddress, chunkSize)
            }
            if bytesRead <= 0 { break }
            buffer.append(scratch, count: bytesRead)
            if buffer.range(of: headerTerminator) != nil {
                break
            }
        }

        if let headerEnd = buffer.range(of: headerTerminator) {
            return buffer.subdata(in: 0..<headerEnd.lowerBound)
        }
        return buffer
    }
}
