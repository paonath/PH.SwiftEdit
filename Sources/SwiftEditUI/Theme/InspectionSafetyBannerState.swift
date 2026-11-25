import Foundation
import SwiftEditCore

/// Inline warning descriptor emitted when Unicode bidirectional control characters are present (`UI-008`).
public struct BiDiControlCharacterWarning: Equatable, Sendable {
    public let utf16Offset: Int
    public let line: Int
    public let scalarHex: String
    public let name: String

    public init(utf16Offset: Int, line: Int, scalarHex: String, name: String) {
        self.utf16Offset = utf16Offset
        self.line = line
        self.scalarHex = scalarHex
        self.name = name
    }
}

/// Canonicalized external URI handoff descriptor requiring user confirmation before opening (`UI-008`, `SEC-004`).
public struct ExternalURIConfirmationPrompt: Equatable, Sendable {
    public let scheme: String
    public let canonicalURI: String
    public let requiresUserConfirmation: Bool

    public init(scheme: String, canonicalURI: String, requiresUserConfirmation: Bool) {
        self.scheme = scheme
        self.canonicalURI = canonicalURI
        self.requiresUserConfirmation = requiresUserConfirmation
    }
}

/// Evaluates UI safety banner state and external URI confirmation prompts for an inspected `DocumentSnapshot` (`UI-008`, `DATA-003`, `SEC-004`, `SEC-012`).
public struct InspectionSafetyBannerState: Equatable, Sendable {
    public static let allowedExternalSchemes: Set<String> = ["https", "http", "mailto"]

    public let isBinaryReadOnlyBannerVisible: Bool
    public let canSave: Bool
    public let canFormat: Bool
    public let canPinTab: Bool
    public let bidiWarnings: [BiDiControlCharacterWarning]

    public init(
        isBinaryReadOnlyBannerVisible: Bool,
        canSave: Bool,
        canFormat: Bool,
        canPinTab: Bool,
        bidiWarnings: [BiDiControlCharacterWarning]
    ) {
        self.isBinaryReadOnlyBannerVisible = isBinaryReadOnlyBannerVisible
        self.canSave = canSave
        self.canFormat = canFormat
        self.canPinTab = canPinTab
        self.bidiWarnings = bidiWarnings
    }

    public static func evaluate(snapshot: DocumentSnapshot) -> InspectionSafetyBannerState {
        if snapshot.isBinaryReadOnly {
            return InspectionSafetyBannerState(
                isBinaryReadOnlyBannerVisible: true,
                canSave: false,
                canFormat: false,
                canPinTab: false,
                bidiWarnings: []
            )
        }
        let warnings = scanBiDiControlScalars(in: snapshot.text)
        return InspectionSafetyBannerState(
            isBinaryReadOnlyBannerVisible: false,
            canSave: true,
            canFormat: snapshot.isDegradedPlainText == false,
            canPinTab: true,
            bidiWarnings: warnings
        )
    }

    public static func prepareExternalURIConfirmation(rawURI: String) -> ExternalURIConfirmationPrompt? {
        let trimmed = rawURI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              allowedExternalSchemes.contains(scheme),
              let canonical = components.url?.absoluteString else {
            return nil
        }
        if (scheme == "https" || scheme == "http"), (components.host ?? "").isEmpty {
            return nil
        }
        if scheme == "mailto", components.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        return ExternalURIConfirmationPrompt(
            scheme: scheme,
            canonicalURI: canonical,
            requiresUserConfirmation: true
        )
    }

    private static let bidiDescriptorsByScalar: [UInt32: (hex: String, name: String)] = [
        0x202A: ("U+202A", "LEFT-TO-RIGHT EMBEDDING"),
        0x202B: ("U+202B", "RIGHT-TO-LEFT EMBEDDING"),
        0x202C: ("U+202C", "POP DIRECTIONAL FORMATTING"),
        0x202D: ("U+202D", "LEFT-TO-RIGHT OVERRIDE"),
        0x202E: ("U+202E", "RIGHT-TO-LEFT OVERRIDE"),
        0x2066: ("U+2066", "LEFT-TO-RIGHT ISOLATE"),
        0x2067: ("U+2067", "RIGHT-TO-LEFT ISOLATE"),
        0x2068: ("U+2068", "FIRST STRONG ISOLATE"),
        0x2069: ("U+2069", "POP DIRECTIONAL ISOLATE"),
        0x061C: ("U+061C", "ARABIC LETTER MARK"),
    ]

    private static func scanBiDiControlScalars(in text: String) -> [BiDiControlCharacterWarning] {
        guard textMayContainBiDiBytes(text) else { return [] }

        var warnings: [BiDiControlCharacterWarning] = []
        let scalars = text.unicodeScalars
        var index = scalars.startIndex
        var utf16Offset = 0
        var line = 1

        while index < scalars.endIndex {
            let scalar = scalars[index]
            if let descriptor = bidiDescriptor(for: scalar.value) {
                warnings.append(BiDiControlCharacterWarning(
                    utf16Offset: utf16Offset,
                    line: line,
                    scalarHex: descriptor.hex,
                    name: descriptor.name
                ))
            }
            line += lineIncrement(at: index, in: scalars)
            utf16Offset += scalar.utf16.count
            index = scalars.index(after: index)
        }
        return warnings
    }

    private static func textMayContainBiDiBytes(_ text: String) -> Bool {
        text.utf8.withContiguousStorageIfAvailable { buf -> Bool in
            guard let base = buf.baseAddress, buf.isEmpty == false else { return false }
            let count = buf.count
            return memchr(base, 0xE2, count) != nil || memchr(base, 0xD8, count) != nil
        } ?? true
    }

    private static func lineIncrement(
        at index: String.UnicodeScalarView.Index,
        in scalars: String.UnicodeScalarView
    ) -> Int {
        let value = scalars[index].value
        if value == 0x0A { return 1 }
        guard value == 0x0D else { return 0 }
        let nextIndex = scalars.index(after: index)
        return (nextIndex == scalars.endIndex || scalars[nextIndex].value != 0x0A) ? 1 : 0
    }

    private static func bidiDescriptor(for value: UInt32) -> (hex: String, name: String)? {
        bidiDescriptorsByScalar[value]
    }
}
