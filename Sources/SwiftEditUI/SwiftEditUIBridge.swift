import Foundation
import SwiftEditCore

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Host UI platform compiled into `SwiftEditUI` via `#if os(macOS)` and `#if os(iOS)` guards (`AR-003`).
public enum SwiftEditUIPlatform: String, Sendable {
    case macOS
    case iOS
    case unsupported
}

/// Platform compilation bridge isolating `AppKit` and `UIKit` imports outside `SwiftEditCore` (`AR-003`, `AR-006`).
public enum SwiftEditUIBridge {
    /// Active UI platform resolved at compile time.
    public static var activePlatform: SwiftEditUIPlatform {
        #if os(macOS)
        return .macOS
        #elseif os(iOS)
        return .iOS
        #else
        return .unsupported
        #endif
    }
}
