import Darwin
import Dispatch
import Foundation
import Observation
import SwiftEditCore

/// Confined `@MainActor @Observable` monitor tracking external on-disk modifications for open file-backed tabs (`REQ-006`, `BC-008`, `DATA-006`, `SEC-003`).
///
/// Opens non-blocking `O_EVTONLY | O_CLOEXEC` file descriptors with `DispatchSourceFileSystemObject` vnode event masks (`[.write, .rename, .delete, .attrib]`) and deterministic `close(fd)` cancel handlers with zero static or runtime recursion (`CWE-674`).
@MainActor
@Observable
public final class ExternalFileChangeMonitor {
    struct WatchedEntry {
        var url: URL
        var scopeURL: URL?
        var lastKnownDigest: UInt64
        var descriptor: Int32
        var source: (any DispatchSourceFileSystemObject)?
    }

    public private(set) var conflictedTabIDs: Set<DocumentID> = []
    public private(set) var diskSnapshotsByTabID: [DocumentID: DocumentSnapshot] = [:]
    @ObservationIgnored private var watchedByTabID: [DocumentID: WatchedEntry] = [:]
    @ObservationIgnored public var onDiskEvent: (@MainActor (DocumentID) -> Void)?

    public init() {}

    /// Number of currently open `O_EVTONLY` file descriptors managed by this monitor (`N7`).
    public var activeDescriptorCount: Int {
        watchedByTabID.values.reduce(0) { $0 + ($1.descriptor >= 0 ? 1 : 0) }
    }

    /// Snapshot of currently watched document tab identifiers (`REQ-006`).
    public var watchedTabIDs: [DocumentID] {
        Array(watchedByTabID.keys)
    }

    /// Registers or refreshes vnode watching for a file-backed `tabID`, recording `knownText` to suppress self-initiated save notifications (`REQ-006`).
    public func registerWatch(tabID: DocumentID, url: URL, scopeURL: URL?, knownText: String) {
        if let previous = watchedByTabID.removeValue(forKey: tabID) {
            Self.teardownVnodeSource(previous)
        }
        let standardized = url.standardizedFileURL
        let digest = Self.fnv1aDigest(knownText)
        let attached = attachVnodeDescriptor(for: tabID, at: standardized)
        watchedByTabID[tabID] = WatchedEntry(
            url: standardized,
            scopeURL: scopeURL?.standardizedFileURL,
            lastKnownDigest: digest,
            descriptor: attached.fd,
            source: attached.source
        )
    }

    /// Re-attaches the `O_EVTONLY` descriptor if the previous vnode experienced an atomic `.rename` or `.delete` replacement (`REQ-006`).
    public func rearmIfRenamedOrDeleted(tabID: DocumentID) {
        guard let entry = watchedByTabID[tabID] else { return }
        let mask = entry.source?.data ?? []
        guard entry.descriptor < 0 || mask.contains(.rename) || mask.contains(.delete) else { return }
        Self.teardownVnodeSource(entry)
        let reattached = attachVnodeDescriptor(for: tabID, at: entry.url)
        var updated = entry
        updated.descriptor = reattached.fd
        updated.source = reattached.source
        watchedByTabID[tabID] = updated
    }

    /// Updates the recorded content digest after a self-save or clean reload without reopening an unchanged vnode (`REQ-006`).
    public func recordKnownText(_ text: String, for tabID: DocumentID) {
        guard var entry = watchedByTabID[tabID] else { return }
        entry.lastKnownDigest = Self.fnv1aDigest(text)
        watchedByTabID[tabID] = entry
    }

    /// Stops watching `tabID`, clears any staged conflict, and deterministically closes its `O_EVTONLY` descriptor (`N7`).
    public func unwatch(tabID: DocumentID) {
        conflictedTabIDs.remove(tabID)
        diskSnapshotsByTabID.removeValue(forKey: tabID)
        if let removed = watchedByTabID.removeValue(forKey: tabID) {
            Self.teardownVnodeSource(removed)
        }
    }

    /// Stops watching all tabs and closes every managed `O_EVTONLY` descriptor (`MEM-003`, `N7`).
    public func unwatchAll() {
        let entries = Array(watchedByTabID.values)
        watchedByTabID.removeAll()
        conflictedTabIDs.removeAll()
        diskSnapshotsByTabID.removeAll()
        for entry in entries {
            Self.teardownVnodeSource(entry)
        }
    }

    public func watchedURL(for tabID: DocumentID) -> URL? {
        watchedByTabID[tabID]?.url
    }

    public func watchedScope(for tabID: DocumentID) -> URL? {
        watchedByTabID[tabID]?.scopeURL
    }

    public func lastKnownDigest(for tabID: DocumentID) -> UInt64? {
        watchedByTabID[tabID]?.lastKnownDigest
    }

    public func stageConflict(for tabID: DocumentID, diskSnapshot: DocumentSnapshot) {
        conflictedTabIDs.insert(tabID)
        diskSnapshotsByTabID[tabID] = diskSnapshot
    }

    public func clearConflict(for tabID: DocumentID) {
        conflictedTabIDs.remove(tabID)
        diskSnapshotsByTabID.removeValue(forKey: tabID)
    }

    /// Computes a deterministic 64-bit FNV-1a digest over UTF-8 text bytes (`REQ-006`).
    public static func fnv1aDigest(_ text: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private func attachVnodeDescriptor(
        for tabID: DocumentID,
        at url: URL
    ) -> (fd: Int32, source: (any DispatchSourceFileSystemObject)?) {
        let fd = Darwin.open(url.path, O_EVTONLY | O_CLOEXEC)
        guard fd >= 0 else { return (-1, nil) }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .attrib],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.onDiskEvent?(tabID)
            }
        }
        src.setCancelHandler {
            Darwin.close(fd)
        }
        src.resume()
        return (fd, src)
    }

    private static func teardownVnodeSource(_ entry: WatchedEntry) {
        if let source = entry.source {
            source.cancel()
        } else if entry.descriptor >= 0 {
            Darwin.close(entry.descriptor)
        }
    }
}
