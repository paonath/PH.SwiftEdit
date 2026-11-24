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

    private static func scanBiDiControlScalars(in text: String) -> [BiDiControlCharacterWarning] {
        let mayContainBiDi: Bool = text.utf8.withContiguousStorageIfAvailable { buf -> Bool in
            guard let base = buf.baseAddress, buf.isEmpty == false else { return false }
            let count = buf.count
            return memchr(base, 0xE2, count) != nil || memchr(base, 0xD8, count) != nil
        } ?? true
        guard mayContainBiDi else { return [] }

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
            if scalar.value == 0x0A {
                line += 1
            } else if scalar.value == 0x0D {
                let nextIndex = scalars.index(after: index)
                if nextIndex == scalars.endIndex || scalars[nextIndex].value != 0x0A {
                    line += 1
                }
            }
            utf16Offset += scalar.utf16.count
            index = scalars.index(after: index)
        }
        return warnings
    }

    private static func bidiDescriptor(for value: UInt32) -> (hex: String, name: String)? {
        switch value {
        case 0x202A: return ("U+202A", "LEFT-TO-RIGHT EMBEDDING")
        case 0x202B: return ("U+202B", "RIGHT-TO-LEFT EMBEDDING")
        case 0x202C: return ("U+202C", "POP DIRECTIONAL FORMATTING")
        case 0x202D: return ("U+202D", "LEFT-TO-RIGHT OVERRIDE")
        case 0x202E: return ("U+202E", "RIGHT-TO-LEFT OVERRIDE")
        case 0x2066: return ("U+2066", "LEFT-TO-RIGHT ISOLATE")
        case 0x2067: return ("U+2067", "RIGHT-TO-LEFT ISOLATE")
        case 0x2068: return ("U+2068", "FIRST STRONG ISOLATE")
        case 0x2069: return ("U+2069", "POP DIRECTIONAL ISOLATE")
        case 0x061C: return ("U+061C", "ARABIC LETTER MARK")
        default: return nil
        }
    }
}
