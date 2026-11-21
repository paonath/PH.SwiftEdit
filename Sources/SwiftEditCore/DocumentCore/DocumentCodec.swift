import Foundation

/// Decoded text buffer paired with its authoritative wire encoding, line-break style, and binary read-only flag.
public struct DecodedDocumentPayload: Equatable, Sendable {
    public let text: String
    public let encoding: TextEncoding
    public let lineEnding: LineEnding
    public let isBinaryReadOnly: Bool

    public init(text: String, encoding: TextEncoding, lineEnding: LineEnding, isBinaryReadOnly: Bool) {
        self.text = text
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.isBinaryReadOnly = isBinaryReadOnly
    }
}

/// Stateless lossless codec translating raw file bytes to and from canonical `\n`-normalized Swift `String` values (`BC-007`, `DATA-004`).
public enum DocumentCodec {
    /// Byte count (`8 KiB`) scanned at the start of non-UTF-16 files to detect `0x00` NUL binary streams (`DATA-003`).
    public static let binaryProbeBytes: Int = 8 * 1024
    /// Maximum number of bytes (`1 MiB`) converted into read-only printable ASCII inspection text for binary files (`SEC-011`).
    public static let maxBinaryInspectionBytes: Int = 1_048_576

    /// Returns `true` when the first `8 KiB` of a non-UTF-16-BOM byte buffer contains at least one `0x00` NUL byte.
    public static func isBinaryPrefix(_ data: Data) -> Bool {
        let probeLen = min(data.count, binaryProbeBytes)
        guard probeLen > 0 else { return false }
        return data.withUnsafeBytes { rawBuf -> Bool in
            guard let base = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return false }
            if probeLen >= 2 {
                let b0 = base[0]
                let b1 = base[1]
                if (b0 == 0xFF && b1 == 0xFE) || (b0 == 0xFE && b1 == 0xFF) {
                    return false
                }
            }
            return memchr(base, 0x00, probeLen) != nil
        }
    }

    /// Produces a read-only ASCII inspection payload capped at `1 MiB`, replacing non-printable/NUL bytes with `.` (`DATA-003`, `SEC-011`).
    public static func decodeBinaryInspectionPreview(_ data: Data) -> DecodedDocumentPayload {
        let capLen = min(data.count, maxBinaryInspectionBytes)
        let preview = String(unsafeUninitializedCapacity: capLen) { dst in
            data.withUnsafeBytes { rawBuf -> Int in
                guard let base = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                var outLen = 0
                for i in 0..<capLen {
                    let byte = base[i]
                    if (byte >= 0x20 && byte <= 0x7E) || byte == 0x09 || byte == 0x0A {
                        dst[outLen] = byte
                        outLen += 1
                    } else if byte != 0x0D {
                        dst[outLen] = 0x2E // '.' placeholder for non-printable/NUL bytes
                        outLen += 1
                    }
                }
                return outLen
            }
        }
        return DecodedDocumentPayload(
            text: preview,
            encoding: .utf8,
            lineEnding: .lf,
            isBinaryReadOnly: true
        )
    }

    /// Decodes `data` by inspecting BOM headers, enforcing strict UTF-8/UTF-16 scalar validity (`DomainError.unsupportedEncoding` on invalid bytes).
    public static func decode(_ data: Data) throws -> DecodedDocumentPayload {
        if isBinaryPrefix(data) {
            return decodeBinaryInspectionPreview(data)
        }
        let rawString: String
        let detectedEncoding: TextEncoding

        if data.starts(with: TextEncoding.utf8WithBOM.bomBytes) {
            let body = data.dropFirst(TextEncoding.utf8WithBOM.bomBytes.count)
            guard let decoded = String(bytes: body, encoding: .utf8) else {
                throw DomainError.unsupportedEncoding
            }
            rawString = decoded
            detectedEncoding = .utf8WithBOM
        } else if data.starts(with: TextEncoding.utf16LEWithBOM.bomBytes) {
            let body = data.dropFirst(TextEncoding.utf16LEWithBOM.bomBytes.count)
            guard body.count % 2 == 0, let decoded = decodeStrictUTF16(body, littleEndian: true) else {
                throw DomainError.unsupportedEncoding
            }
            rawString = decoded
            detectedEncoding = .utf16LEWithBOM
        } else if data.starts(with: TextEncoding.utf16BEWithBOM.bomBytes) {
            let body = data.dropFirst(TextEncoding.utf16BEWithBOM.bomBytes.count)
            guard body.count % 2 == 0, let decoded = decodeStrictUTF16(body, littleEndian: false) else {
                throw DomainError.unsupportedEncoding
            }
            rawString = decoded
            detectedEncoding = .utf16BEWithBOM
        } else {
            guard let decoded = String(bytes: data, encoding: .utf8) else {
                throw DomainError.unsupportedEncoding
            }
            rawString = decoded
            detectedEncoding = .utf8
        }

        let detectedLineEnding = LineEnding.detect(in: rawString)
        let normalized = detectedLineEnding == .lf ? rawString : LineEnding.normalizeToLF(rawString)

        return DecodedDocumentPayload(
            text: normalized,
            encoding: detectedEncoding,
            lineEnding: detectedLineEnding,
            isBinaryReadOnly: false
        )
    }

    /// Re-encodes canonical text into `Data` preserving the specified BOM header and `LF` or `CRLF` sequence.
    public static func encode(_ text: String, encoding: TextEncoding, lineEnding: LineEnding) throws -> Data {
        let canonicalLF = LineEnding.normalizeToLF(text)
        let wireText = lineEnding.apply(toCanonicalLF: canonicalLF)
        let bom = encoding.bomBytes

        switch encoding {
        case .utf8, .utf8WithBOM:
            var output = Data()
            output.reserveCapacity(bom.count + wireText.utf8.count)
            output.append(contentsOf: bom)
            output.append(contentsOf: wireText.utf8)
            return output
        case .utf16LEWithBOM, .utf16BEWithBOM:
            let littleEndian = (encoding == .utf16LEWithBOM)
            let unitCount = wireText.utf16.count
            var output = Data(count: bom.count + unitCount * 2)
            output.withUnsafeMutableBytes { rawOut in
                guard let dst = rawOut.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                for (i, b) in bom.enumerated() {
                    dst[i] = b
                }
                var writeIdx = bom.count
                for unit in wireText.utf16 {
                    if littleEndian {
                        dst[writeIdx] = UInt8(truncatingIfNeeded: unit)
                        dst[writeIdx + 1] = UInt8(truncatingIfNeeded: unit >> 8)
                    } else {
                        dst[writeIdx] = UInt8(truncatingIfNeeded: unit >> 8)
                        dst[writeIdx + 1] = UInt8(truncatingIfNeeded: unit)
                    }
                    writeIdx += 2
                }
            }
            return output
        }
    }

    private static func decodeStrictUTF16(_ body: Data, littleEndian: Bool) -> String? {
        guard !body.isEmpty else { return "" }
        return body.withUnsafeBytes { rawBuf -> String? in
            guard let base = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return "" }
            let pairCount = body.count / 2
            var utf8Bytes: [UInt8] = []
            utf8Bytes.reserveCapacity(pairCount)
            var i = 0
            while i < pairCount {
                let b0 = base[i * 2]
                let b1 = base[i * 2 + 1]
                let u1: UInt16 = littleEndian ? (UInt16(b0) | (UInt16(b1) << 8)) : ((UInt16(b0) << 8) | UInt16(b1))
                i += 1
                let scalarValue: UInt32
                if u1 < 0xD800 || u1 > 0xDFFF {
                    scalarValue = UInt32(u1)
                } else if u1 <= 0xDBFF {
                    guard i < pairCount else { return nil }
                    let lb0 = base[i * 2]
                    let lb1 = base[i * 2 + 1]
                    let u2: UInt16 = littleEndian ? (UInt16(lb0) | (UInt16(lb1) << 8)) : ((UInt16(lb0) << 8) | UInt16(lb1))
                    guard u2 >= 0xDC00 && u2 <= 0xDFFF else { return nil }
                    i += 1
                    scalarValue = 0x10000 + ((UInt32(u1 - 0xD800) << 10) | UInt32(u2 - 0xDC00))
                } else {
                    return nil
                }

                if scalarValue < 0x80 {
                    utf8Bytes.append(UInt8(scalarValue))
                } else if scalarValue < 0x800 {
                    utf8Bytes.append(UInt8(0xC0 | (scalarValue >> 6)))
                    utf8Bytes.append(UInt8(0x80 | (scalarValue & 0x3F)))
                } else if scalarValue < 0x10000 {
                    utf8Bytes.append(UInt8(0xE0 | (scalarValue >> 12)))
                    utf8Bytes.append(UInt8(0x80 | ((scalarValue >> 6) & 0x3F)))
                    utf8Bytes.append(UInt8(0x80 | (scalarValue & 0x3F)))
                } else {
                    utf8Bytes.append(UInt8(0xF0 | (scalarValue >> 18)))
                    utf8Bytes.append(UInt8(0x80 | ((scalarValue >> 12) & 0x3F)))
                    utf8Bytes.append(UInt8(0x80 | ((scalarValue >> 6) & 0x3F)))
                    utf8Bytes.append(UInt8(0x80 | (scalarValue & 0x3F)))
                }
            }
            return String(decoding: utf8Bytes, as: UTF8.self)
        }
    }
}
