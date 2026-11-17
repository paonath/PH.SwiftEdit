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
        if data.starts(with: TextEncoding.utf16LEWithBOM.bomBytes) || data.starts(with: TextEncoding.utf16BEWithBOM.bomBytes) {
            return false
        }
        let window = data.prefix(binaryProbeBytes)
        return window.contains(0x00)
    }

    /// Produces a read-only ASCII inspection payload capped at `1 MiB`, replacing non-printable/NUL bytes with `.` (`DATA-003`, `SEC-011`).
    public static func decodeBinaryInspectionPreview(_ data: Data) -> DecodedDocumentPayload {
        let capped = data.prefix(maxBinaryInspectionBytes)
        var asciiChars = [UInt8]()
        asciiChars.reserveCapacity(capped.count)
        for byte in capped {
            if (0x20...0x7E).contains(byte) || byte == 0x09 || byte == 0x0A {
                asciiChars.append(byte)
            } else if byte != 0x0D {
                asciiChars.append(0x2E) // '.' placeholder for non-printable/NUL bytes
            }
        }
        let preview = String(decoding: asciiChars, as: UTF8.self)
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
        let normalized = LineEnding.normalizeToLF(rawString)

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
        var output = Data(encoding.bomBytes)

        switch encoding {
        case .utf8, .utf8WithBOM:
            output.append(contentsOf: wireText.utf8)
        case .utf16LEWithBOM:
            for unit in wireText.utf16 {
                var le = unit.littleEndian
                withUnsafeBytes(of: &le) { output.append(contentsOf: $0) }
            }
        case .utf16BEWithBOM:
            for unit in wireText.utf16 {
                var be = unit.bigEndian
                withUnsafeBytes(of: &be) { output.append(contentsOf: $0) }
            }
        }
        return output
    }

    private static func decodeStrictUTF16(_ body: Data, littleEndian: Bool) -> String? {
        var units: [UInt16] = []
        units.reserveCapacity(body.count / 2)
        var iter = body.makeIterator()
        while let b0 = iter.next(), let b1 = iter.next() {
            let unit = littleEndian
                ? (UInt16(b0) | (UInt16(b1) << 8))
                : ((UInt16(b0) << 8) | UInt16(b1))
            units.append(unit)
        }
        var scalars = String.UnicodeScalarView()
        var parser = UTF16()
        var unitIter = units.makeIterator()
        while true {
            switch parser.decode(&unitIter) {
            case .scalarValue(let scalar):
                scalars.append(scalar)
            case .emptyInput:
                return String(scalars)
            case .error:
                return nil
            }
        }
    }
}
