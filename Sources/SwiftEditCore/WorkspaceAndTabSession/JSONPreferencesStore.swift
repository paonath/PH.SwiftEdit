import Foundation

/// Thread-safe JSON-backed `PreferencesProviding` store persisting user settings in `~/.SwiftEdit/settings.json` (`DATA-008`).
///
/// Design invariants:
/// - Creates `~/.SwiftEdit` (`0700` POSIX permissions) on demand and writes `settings.json` atomically with pretty-printed, sorted keys.
/// - Tolerates missing, empty, or malformed JSON files gracefully (fail-closed to empty defaults without crashing).
/// - Uses `JSONValue` codable wrapper so `Bool`, `Int`, `Double`, `String`, and `Data` round-trip with exact types.
public final class JSONPreferencesStore: PreferencesProviding, @unchecked Sendable {
    public let fileURL: URL
    private let lock = NSLock()
    private let writeLock = NSLock()
    private var storage: [String: JSONValue]
    private var batchDepth = 0
    private var batchDirty = false
    private var directoryEnsured = false

    fileprivate enum JSONValue: Codable, Equatable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case base64Data(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let b = try? container.decode(Bool.self) {
                self = .bool(b)
            } else if let i = try? container.decode(Int.self) {
                self = .int(i)
            } else if let d = try? container.decode(Double.self) {
                self = .double(d)
            } else if let s = try? container.decode(String.self) {
                self = .string(s)
            } else {
                throw DecodingError.typeMismatch(
                    JSONValue.self,
                    DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON preference value")
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let s): try container.encode(s)
            case .int(let i): try container.encode(i)
            case .double(let d): try container.encode(d)
            case .bool(let b): try container.encode(b)
            case .base64Data(let b64): try container.encode(b64)
            }
        }
    }

    /// Resolves the canonical `~/.SwiftEdit` directory in the user's real home directory.
    public static func defaultConfigDirectoryURL() -> URL {
        let home: URL
        #if os(macOS)
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            home = URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        } else {
            home = FileManager.default.homeDirectoryForCurrentUser
        }
        #else
        home = FileManager.default.homeDirectoryForCurrentUser
        #endif
        return home.appendingPathComponent(".SwiftEdit", isDirectory: true)
    }

    /// Resolves the canonical `~/.SwiftEdit/settings.json` file URL.
    public static func defaultSettingsFileURL() -> URL {
        defaultConfigDirectoryURL().appendingPathComponent("settings.json", isDirectory: false)
    }

    public init(fileURL: URL = JSONPreferencesStore.defaultSettingsFileURL()) {
        self.fileURL = fileURL.standardizedFileURL
        self.storage = Self.loadFromDisk(at: self.fileURL)
    }

    /// Ensures the `~/.SwiftEdit` directory and `settings.json` exist on disk, persisting current entries.
    public func ensurePersisted() {
        flushLatestSnapshotToDisk()
    }

    public func string(forKey defaultName: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        switch storage[defaultName] {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .bool(let b): return b ? "true" : "false"
        case .base64Data, .none: return nil
        }
    }

    public func integer(forKey defaultName: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        switch storage[defaultName] {
        case .int(let i): return i
        case .double(let d): return Int(d)
        case .bool(let b): return b ? 1 : 0
        case .string(let s): return Int(s) ?? 0
        case .base64Data, .none: return 0
        }
    }

    public func double(forKey defaultName: String) -> Double {
        lock.lock()
        defer { lock.unlock() }
        switch storage[defaultName] {
        case .double(let d): return d
        case .int(let i): return Double(i)
        case .bool(let b): return b ? 1.0 : 0.0
        case .string(let s): return Double(s) ?? 0.0
        case .base64Data, .none: return 0.0
        }
    }

    public func bool(forKey defaultName: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        switch storage[defaultName] {
        case .bool(let b): return b
        case .int(let i): return i != 0
        case .double(let d): return d != 0
        case .string(let s): return (s as NSString).boolValue
        case .base64Data, .none: return false
        }
    }

    public func data(forKey defaultName: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        switch storage[defaultName] {
        case .base64Data(let b64), .string(let b64):
            return Data(base64Encoded: b64)
        default:
            return nil
        }
    }

    public func object(forKey defaultName: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        switch storage[defaultName] {
        case .string(let s): return s
        case .int(let i): return i
        case .double(let d): return d
        case .bool(let b): return b
        case .base64Data(let b64): return Data(base64Encoded: b64)
        case .none: return nil
        }
    }

    /// Executes multiple `set` operations and flushes a single atomic JSON write if any key changed.
    public func performBatch(_ updates: () -> Void) {
        lock.lock()
        batchDepth += 1
        lock.unlock()

        updates()

        lock.lock()
        batchDepth -= 1
        let shouldFlush = batchDepth == 0 && batchDirty
        if shouldFlush {
            batchDirty = false
        }
        lock.unlock()

        if shouldFlush {
            flushLatestSnapshotToDisk()
        }
    }

    public func set(_ value: Any?, forKey defaultName: String) {
        if prefsApplyValueUnderLock(value, forKey: defaultName) {
            flushLatestSnapshotToDisk()
        }
    }

    public func removeObject(forKey defaultName: String) {
        set(nil, forKey: defaultName)
    }
}

private extension JSONPreferencesStore {
    func prefsApplyValueUnderLock(_ value: Any?, forKey defaultName: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let encoded = value.map(Self.prefsEncodeAnyValue)
        let changed = prefsUpdateStorageEntry(encoded, forKey: defaultName)
        guard changed else { return false }

        if batchDepth > 0 {
            batchDirty = true
            return false
        }
        return true
    }

    func prefsUpdateStorageEntry(_ encoded: JSONValue?, forKey key: String) -> Bool {
        if let encoded {
            let changed = storage[key] != encoded
            storage[key] = encoded
            return changed
        }
        return storage.removeValue(forKey: key) != nil
    }

    static func prefsEncodeAnyValue(_ value: Any) -> JSONValue {
        if let b = value as? Bool { return .bool(b) }
        if let i = value as? Int { return .int(i) }
        if let d = value as? Double { return .double(d) }
        if let s = value as? String { return .string(s) }
        if let data = value as? Data { return .base64Data(data.base64EncodedString()) }
        return .string(String(describing: value))
    }

    static func loadFromDisk(at url: URL) -> [String: JSONValue] {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return [:] }
        return (try? JSONDecoder().decode([String: JSONValue].self, from: data)) ?? [:]
    }

    /// Serializes disk writes under `writeLock` and snapshots `storage` inside it so concurrent writers can never overwrite newer settings with an older snapshot.
    func flushLatestSnapshotToDisk() {
        writeLock.lock()
        defer { writeLock.unlock() }
        lock.lock()
        let dict = storage
        let needsDir = !directoryEnsured
        lock.unlock()

        let dir = fileURL.deletingLastPathComponent()
        do {
            if needsDir {
                try FileManager.default.createDirectory(
                    at: dir,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700]
                )
                lock.lock()
                directoryEnsured = true
                lock.unlock()
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(dict)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Non-fatal: keep in-memory state consistent even if disk is temporarily read-only.
        }
    }
}
