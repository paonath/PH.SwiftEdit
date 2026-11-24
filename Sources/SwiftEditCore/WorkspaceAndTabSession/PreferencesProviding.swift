import Foundation

/// Narrow key-value storage seam isolating preferences and MRU stores from host `UserDefaults` / `cfprefsd` during unit tests (`AR-007`, `PERF-003`, `TEST-001`).
public protocol PreferencesProviding: Sendable {
    func string(forKey defaultName: String) -> String?
    func integer(forKey defaultName: String) -> Int
    func double(forKey defaultName: String) -> Double
    func bool(forKey defaultName: String) -> Bool
    func data(forKey defaultName: String) -> Data?
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

/// Non-conforming Foundation bridge preventing intra-type method-name collisions with `PreferencesProviding` in static call graphs (`AR-007`).
private struct FoundationUserDefaultsBridge: @unchecked Sendable {
    let defaults: UserDefaults

    func readString(_ key: String) -> String? { defaults.string(forKey: key) }
    func readInteger(_ key: String) -> Int { defaults.integer(forKey: key) }
    func readDouble(_ key: String) -> Double { defaults.double(forKey: key) }
    func readBool(_ key: String) -> Bool { defaults.bool(forKey: key) }
    func readData(_ key: String) -> Data? { defaults.data(forKey: key) }
    func readObject(_ key: String) -> Any? { defaults.object(forKey: key) }
    func writeValue(_ value: Any?, key: String) { defaults.set(value, forKey: key) }
    func deleteValue(_ key: String) { defaults.removeObject(forKey: key) }
}

/// Production `PreferencesProviding` adapter backed by the app container's `UserDefaults.standard` (default when `suiteName == nil`) or an explicit suite (`PERF-003`).
public final class UserDefaultsPreferencesStore: PreferencesProviding, @unchecked Sendable {
    private let bridge: FoundationUserDefaultsBridge

    public init(suiteName: String? = nil) {
        if let suiteName, let suiteDefaults = UserDefaults(suiteName: suiteName) {
            self.bridge = FoundationUserDefaultsBridge(defaults: suiteDefaults)
        } else {
            self.bridge = FoundationUserDefaultsBridge(defaults: .standard)
        }
    }

    public func string(forKey defaultName: String) -> String? {
        bridge.readString(defaultName)
    }

    public func integer(forKey defaultName: String) -> Int {
        bridge.readInteger(defaultName)
    }

    public func double(forKey defaultName: String) -> Double {
        bridge.readDouble(defaultName)
    }

    public func bool(forKey defaultName: String) -> Bool {
        bridge.readBool(defaultName)
    }

    public func data(forKey defaultName: String) -> Data? {
        bridge.readData(defaultName)
    }

    public func object(forKey defaultName: String) -> Any? {
        bridge.readObject(defaultName)
    }

    public func set(_ value: Any?, forKey defaultName: String) {
        bridge.writeValue(value, key: defaultName)
    }

    public func removeObject(forKey defaultName: String) {
        bridge.deleteValue(defaultName)
    }
}

/// Thread-safe in-memory `PreferencesProviding` implementation eliminating `UserDefaults` / `cfprefsd` persistence teardown across parallel Swift Testing runs (`PERF-003`, `TEST-003`).
public final class InMemoryKeyValueStore: PreferencesProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Any]

    public init(initialValues: [String: Any] = [:]) {
        self.storage = initialValues
    }

    public func string(forKey defaultName: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let s = storage[defaultName] as? String {
            return s
        }
        if let n = storage[defaultName] as? NSNumber {
            return n.stringValue
        }
        return nil
    }

    public func integer(forKey defaultName: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        if let i = storage[defaultName] as? Int {
            return i
        }
        if let n = storage[defaultName] as? NSNumber {
            return n.intValue
        }
        if let s = storage[defaultName] as? String {
            return Int(s) ?? 0
        }
        return 0
    }

    public func double(forKey defaultName: String) -> Double {
        lock.lock()
        defer { lock.unlock() }
        if let d = storage[defaultName] as? Double {
            return d
        }
        if let n = storage[defaultName] as? NSNumber {
            return n.doubleValue
        }
        if let s = storage[defaultName] as? String {
            return Double(s) ?? 0
        }
        return 0
    }

    public func bool(forKey defaultName: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if let b = storage[defaultName] as? Bool {
            return b
        }
        if let n = storage[defaultName] as? NSNumber {
            return n.boolValue
        }
        if let s = storage[defaultName] as? String {
            return (s as NSString).boolValue
        }
        return false
    }

    public func data(forKey defaultName: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[defaultName] as? Data
    }

    public func object(forKey defaultName: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        return storage[defaultName]
    }

    public func set(_ value: Any?, forKey defaultName: String) {
        lock.lock()
        defer { lock.unlock() }
        if let value {
            storage[defaultName] = value
        } else {
            storage.removeValue(forKey: defaultName)
        }
    }

    public func removeObject(forKey defaultName: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: defaultName)
    }
}
