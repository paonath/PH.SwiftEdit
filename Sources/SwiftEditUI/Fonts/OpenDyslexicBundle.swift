#if os(macOS)
import AppKit
import CoreText
import CryptoKit
import Foundation

/// File-byte seam so integrity checks are testable with tampered or missing inputs (`AR-007`, `TEST-004`).
protocol FontFileReading: Sendable {
    func data(at url: URL) throws -> Data
}

/// Disk reader used in production.
struct DiskFontFileReader: FontFileReading {
    func data(at url: URL) throws -> Data { try Data(contentsOf: url) }
}

/// Font registration seam; production registers for the current process only.
protocol FontRegistering: AnyObject {
    /// Returns `true` when `url` is (or already was) registered for this process.
    func registerForProcess(_ url: URL) -> Bool
}

/// CoreText registrar using `CTFontManagerScope.process`: fonts are never installed system-wide (`SEC-001`).
final class CoreTextProcessFontRegistrar: FontRegistering {
    func registerForProcess(_ url: URL) -> Bool {
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) { return true }
        let code = error.map { CFErrorGetCode($0.takeRetainedValue()) } ?? 0
        return code == CTFontManagerError.alreadyRegistered.rawValue
    }
}

/// Outcome of verifying and registering the bundled OpenDyslexic faces.
enum OpenDyslexicAvailability: Equatable, Sendable {
    case available
    case unavailable(reason: String)

    var isAvailable: Bool { self == .available }
}

/// Bundled OpenDyslexic (SIL OFL 1.1, upstream `antijingoist/opendyslexic` @ `77bda89f3f20`, unmodified files) (`REQ-006`).
///
/// Security model (`SEC-008`, `SEC-012`):
/// - every file, including `OFL.txt`, must match its pinned SHA-256 before anything is registered (fail closed);
/// - fonts are registered with `CTFontManagerScope.process`, so no other process ever sees them;
/// - faces are built from the descriptors of the verified file URLs, never looked up by family name, so an installed
///   system font called "OpenDyslexic" can never stand in for the verified bundle.
@MainActor
public final class OpenDyslexicBundle {
    /// Pinned SHA-256 digests captured at download time (user-confirmed, change `017`).
    static let pinnedDigests: [String: String] = [
        "OpenDyslexic-Regular.otf": "32f5840fb2bf844bdabafe372591ddfb9286e98117f5b21950aaf54ea856919a",
        "OpenDyslexic-Bold.otf": "5d690ea4c87ccb0d5d5d81487826a395e9b20a6c1d606f1f262c060d2bef4f03",
        "OpenDyslexic-Italic.otf": "dfa0185bb0d47cb76cb5d082531822d0dca03152f5b6ec6c9f6e3f8d00b71782",
        "OpenDyslexic-Bold-Italic.otf": "b50779f4f547917a648d38976a664cab8952563112ce03209ff568b1eb364090",
        "OFL.txt": "caafcccfb70fc72458fcbda812ec8f0a06cb300cbabb87eabbb30b946124394b",
    ]

    /// Face files keyed by `(bold, italic)`.
    private static let faceFiles: [FaceKey: String] = [
        FaceKey(bold: false, italic: false): "OpenDyslexic-Regular.otf",
        FaceKey(bold: true, italic: false): "OpenDyslexic-Bold.otf",
        FaceKey(bold: false, italic: true): "OpenDyslexic-Italic.otf",
        FaceKey(bold: true, italic: true): "OpenDyslexic-Bold-Italic.otf",
    ]

    /// `Fonts` directory inside the `SwiftEditUI` resource bundle.
    static var defaultDirectory: URL? { Bundle.module.url(forResource: "Fonts", withExtension: nil) }

    /// Process-wide instance used by the app.
    static let shared = OpenDyslexicBundle(directory: defaultDirectory ?? URL(fileURLWithPath: "/nonexistent"))

    private struct FaceKey: Hashable {
        let bold: Bool
        let italic: Bool
    }

    private let directory: URL
    private let reader: any FontFileReading
    private let registrar: any FontRegistering
    private var availability: OpenDyslexicAvailability?
    private var descriptors: [FaceKey: CTFontDescriptor] = [:]
    /// Number of verification/registration passes actually executed (idempotency check).
    private(set) var registrationPasses = 0

    init(directory: URL, reader: any FontFileReading = DiskFontFileReader(), registrar: (any FontRegistering)? = nil) {
        self.directory = directory
        self.reader = reader
        self.registrar = registrar ?? CoreTextProcessFontRegistrar()
    }

    /// Verifies every pinned file, then registers the faces once; later calls return the cached outcome.
    @discardableResult
    func registerIfNeeded() -> OpenDyslexicAvailability {
        if let availability { return availability }
        registrationPasses += 1
        let result = verifyAndRegister()
        availability = result
        return result
    }

    private func verifyAndRegister() -> OpenDyslexicAvailability {
        for (name, digest) in Self.pinnedDigests.sorted(by: { $0.key < $1.key }) {
            let url = directory.appendingPathComponent(name)
            guard let bytes = try? reader.data(at: url) else { return .unavailable(reason: "missing \(name)") }
            let actual = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            guard actual == digest else { return .unavailable(reason: "digest mismatch for \(name)") }
        }
        var resolved: [FaceKey: CTFontDescriptor] = [:]
        for (key, name) in Self.faceFiles {
            let url = directory.appendingPathComponent(name)
            guard let list = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
                  let descriptor = list.first else { return .unavailable(reason: "unreadable \(name)") }
            resolved[key] = descriptor
        }
        for name in Self.faceFiles.values.sorted() {
            guard registrar.registerForProcess(directory.appendingPathComponent(name)) else {
                return .unavailable(reason: "registration failed for \(name)")
            }
        }
        descriptors = resolved
        return .available
    }

    /// Verified face at `size` using a disambiguated method name that avoids call-graph collision with `AppTypography.font` (`REQ-007`).
    func verifiedFace(size: CGFloat, bold: Bool, italic: Bool) -> NSFont? {
        guard registerIfNeeded().isAvailable, let descriptor = descriptors[FaceKey(bold: bold, italic: italic)] else { return nil }
        return CTFontCreateWithFontDescriptor(descriptor, size, nil) as NSFont
    }

    /// Verified face at `size`, or `nil` while unavailable.
    func font(size: CGFloat, bold: Bool, italic: Bool) -> NSFont? {
        verifiedFace(size: size, bold: bold, italic: italic)
    }

    /// PostScript name of the verified face, or `nil` while unavailable.
    func postScriptName(bold: Bool, italic: Bool) -> String? {
        guard registerIfNeeded().isAvailable, let descriptor = descriptors[FaceKey(bold: bold, italic: italic)] else { return nil }
        return CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String
    }
}
#endif
