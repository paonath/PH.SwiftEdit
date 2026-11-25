import Foundation
import SwiftUI

/// SwiftEdit Line icon set: minimal Zed/Lucide-style outline icons drawn in code on a `24×24` grid (`UI-001` v1.7.0).
///
/// - Every icon is original vector geometry (lines, rounded rects, circles, quadratic curves), so no asset catalog,
///   download or third-party licence is involved; the Concept E2 logo is **not** part of this set and stays unchanged.
/// - The stroke is `2` grid units (`~1.33 pt` at `16 pt`), round caps and joins; colour comes from `foregroundStyle`.
/// - `rawValue` is a stable semantic name, so `SwiftEditCore` catalogs (e.g. contextual actions) can refer to icons
///   without depending on SwiftUI.
public enum AppIcon: String, CaseIterable, Sendable {
    case close, closeCircle, check, checkCircle, plus, minus, minusCircle, dot
    case chevronLeft, chevronRight, chevronUp, chevronDown
    case code, braces, parentheses
    case search, sidebar, terminal, keyboard, lock
    case folder, folderUp, file, fileText, filePlus, fileBinary
    case eye, eyeOff, save, saveAs, duplicate, alignLeft, indent
    case imageOff, warning, error, refresh, typography, download, live, pause
    case pin, pinOff, diff, sun, moon, monitor, zoomIn, zoomOut, menu, microphone
}

/// Path builder on the `24×24` icon grid.
struct AppIconPathBuilder {
    private(set) var stroke = Path()
    private(set) var fill = Path()

    mutating func line(_ points: [(CGFloat, CGFloat)], closed: Bool = false) {
        guard let first = points.first else { return }
        stroke.move(to: CGPoint(x: first.0, y: first.1))
        for point in points.dropFirst() { stroke.addLine(to: CGPoint(x: point.0, y: point.1)) }
        if closed { stroke.closeSubpath() }
    }

    mutating func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, r: CGFloat = 2) {
        stroke.addRoundedRect(in: CGRect(x: x, y: y, width: w, height: h), cornerSize: CGSize(width: r, height: r))
    }

    mutating func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, filled: Bool = false) {
        let rect = CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)
        if filled { fill.addEllipse(in: rect) } else { stroke.addEllipse(in: rect) }
    }

    /// Arc starting at `start` degrees (0 = +x, 90 = down) sweeping `sweep` degrees visually clockwise.
    mutating func arc(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, start: Double, sweep: Double) {
        let startPoint = CGPoint(x: cx + r * CGFloat(cos(start * .pi / 180)), y: cy + r * CGFloat(sin(start * .pi / 180)))
        stroke.move(to: startPoint)
        stroke.addRelativeArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: .degrees(start), delta: .degrees(sweep))
    }

    /// Polyline with quadratic corners: each element is either a point `(x, y)` or a control/end pair.
    mutating func curve(_ start: (CGFloat, CGFloat), _ segments: [Segment], closed: Bool = false) {
        stroke.move(to: CGPoint(x: start.0, y: start.1))
        for segment in segments {
            switch segment {
            case .to(let x, let y): stroke.addLine(to: CGPoint(x: x, y: y))
            case .quad(let cx, let cy, let x, let y): stroke.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cx, y: cy))
            }
        }
        if closed { stroke.closeSubpath() }
    }

    enum Segment {
        case to(CGFloat, CGFloat)
        case quad(CGFloat, CGFloat, CGFloat, CGFloat)
    }
}

extension AppIcon {
    /// Grid geometry of the icon (stroke part and optional filled part).
    var geometry: AppIconPathBuilder {
        var b = AppIconPathBuilder()
        switch self {
        case .close:
            b.line([(6, 6), (18, 18)]); b.line([(18, 6), (6, 18)])
        case .closeCircle:
            b.circle(12, 12, 9); b.line([(9, 9), (15, 15)]); b.line([(15, 9), (9, 15)])
        case .check:
            b.line([(5, 12.5), (10, 17.5), (19, 7)])
        case .checkCircle:
            b.circle(12, 12, 9); b.line([(8, 12.5), (11, 15.5), (16, 9.5)])
        case .plus:
            b.line([(12, 5), (12, 19)]); b.line([(5, 12), (19, 12)])
        case .minus:
            b.line([(5, 12), (19, 12)])
        case .minusCircle:
            b.circle(12, 12, 9); b.line([(8, 12), (16, 12)])
        case .dot:
            b.circle(12, 12, 4, filled: true)
        case .chevronLeft:
            b.line([(15, 6), (9, 12), (15, 18)])
        case .chevronRight:
            b.line([(9, 6), (15, 12), (9, 18)])
        case .chevronUp:
            b.line([(6, 15), (12, 9), (18, 15)])
        case .chevronDown:
            b.line([(6, 9), (12, 15), (18, 9)])
        case .code:
            b.line([(8, 7), (3, 12), (8, 17)]); b.line([(16, 7), (21, 12), (16, 17)]); b.line([(14, 5), (10, 19)])
        case .braces:
            b.curve((9, 4), [.quad(6, 4, 6, 7), .to(6, 10), .quad(6, 12, 4, 12), .quad(6, 12, 6, 14), .to(6, 17), .quad(6, 20, 9, 20)])
            b.curve((15, 4), [.quad(18, 4, 18, 7), .to(18, 10), .quad(18, 12, 20, 12), .quad(18, 12, 18, 14), .to(18, 17), .quad(18, 20, 15, 20)])
        case .parentheses:
            b.curve((9, 4), [.quad(4.5, 12, 9, 20)]); b.curve((15, 4), [.quad(19.5, 12, 15, 20)])
        case .search:
            b.circle(11, 11, 7); b.line([(16, 16), (20.5, 20.5)])
        case .sidebar:
            b.rect(3, 4, 18, 16, r: 2.5); b.line([(9, 4), (9, 20)])
        case .terminal:
            b.line([(4, 7), (9, 12), (4, 17)]); b.line([(12, 17), (20, 17)])
        case .keyboard:
            b.rect(2.5, 6, 19, 12, r: 2)
            for x in stride(from: CGFloat(6), through: 18, by: 4) { b.line([(x, 10), (x + 0.01, 10)]) }
            b.line([(8, 14.5), (16, 14.5)])
        case .lock:
            b.rect(5, 11, 14, 10, r: 2); b.curve((8, 11), [.to(8, 8), .quad(8, 4, 12, 4), .quad(16, 4, 16, 8), .to(16, 11)])
        case .folder:
            Self.folderOutline(&b)
        case .folderUp:
            Self.folderOutline(&b); b.line([(12, 16.5), (12, 10.5)]); b.line([(9.5, 13), (12, 10.5), (14.5, 13)])
        case .file:
            Self.fileOutline(&b)
        case .fileText:
            Self.fileOutline(&b); b.line([(9, 13), (15, 13)]); b.line([(9, 17), (15, 17)]); b.line([(9, 9), (10.5, 9)])
        case .filePlus:
            Self.fileOutline(&b); b.line([(12, 11), (12, 17)]); b.line([(9, 14), (15, 14)])
        case .fileBinary:
            Self.fileOutline(&b); b.line([(9.5, 12), (9.5, 17)]); b.rect(12, 12, 3, 5, r: 1.5)
        case .eye:
            Self.eyeOutline(&b)
        case .eyeOff:
            Self.eyeOutline(&b); b.line([(4, 4), (20, 20)])
        case .save:
            b.rect(4, 4, 16, 16, r: 2); b.line([(8, 4), (8, 9), (15, 9), (15, 4)]); b.line([(8, 20), (8, 14), (16, 14), (16, 20)])
        case .saveAs:
            b.line([(12, 4), (12, 14.5)]); b.line([(7.5, 10), (12, 14.5), (16.5, 10)])
            b.curve((4, 15), [.to(4, 18.5), .quad(4, 20, 5.5, 20), .to(18.5, 20), .quad(20, 20, 20, 18.5), .to(20, 15)])
        case .duplicate:
            b.rect(9, 9, 12, 12, r: 2); b.curve((15, 9), [.to(15, 5), .quad(15, 3, 13, 3), .to(5, 3), .quad(3, 3, 3, 5), .to(3, 13), .quad(3, 15, 5, 15), .to(9, 15)])
        case .alignLeft:
            b.line([(4, 6), (20, 6)]); b.line([(4, 10), (14, 10)]); b.line([(4, 14), (20, 14)]); b.line([(4, 18), (12, 18)])
        case .indent:
            b.line([(11, 6), (20, 6)]); b.line([(11, 10), (20, 10)]); b.line([(11, 14), (20, 14)]); b.line([(4, 18), (20, 18)])
            b.line([(4, 7.5), (7, 10), (4, 12.5)])
        case .imageOff:
            b.rect(3, 3, 18, 18, r: 2.5); b.circle(9, 9, 1.75); b.line([(21, 15), (16, 10), (7, 19)]); b.line([(3, 3), (21, 21)])
        case .warning:
            b.curve((12, 3.5), [.to(21.4, 19.2), .quad(22, 20.5, 20.6, 20.5), .to(3.4, 20.5), .quad(2, 20.5, 2.6, 19.2)], closed: true)
            b.line([(12, 9.5), (12, 13.5)]); b.line([(12, 17), (12.01, 17)])
        case .error:
            b.line([(8, 3), (16, 3), (21, 8), (21, 16), (16, 21), (8, 21), (3, 16), (3, 8)], closed: true)
            b.line([(9, 9), (15, 15)]); b.line([(15, 9), (9, 15)])
        case .refresh:
            b.arc(12, 12, 8, start: 20, sweep: 300); b.line([(19.2, 3.2), (18.2, 6.9), (14.4, 6.2)])
        case .typography:
            b.line([(3.5, 19), (8.5, 5), (13.5, 19)]); b.line([(5.5, 14), (11.5, 14)]); b.circle(18, 16, 2.5); b.line([(20.5, 12.5), (20.5, 19)])
        case .download:
            b.circle(12, 12, 9); b.line([(12, 7.5), (12, 15.5)]); b.line([(8.5, 12), (12, 15.5), (15.5, 12)])
        case .live:
            b.circle(12, 12, 1.75, filled: true)
            b.arc(12, 12, 5, start: 135, sweep: 90); b.arc(12, 12, 5, start: -45, sweep: 90)
            b.arc(12, 12, 9, start: 140, sweep: 80); b.arc(12, 12, 9, start: -40, sweep: 80)
        case .pause:
            b.circle(12, 12, 9); b.line([(10, 9), (10, 15)]); b.line([(14, 9), (14, 15)])
        case .pin:
            Self.pinOutline(&b)
        case .pinOff:
            Self.pinOutline(&b); b.line([(3, 3), (21, 21)])
        case .diff:
            b.rect(3, 4, 18, 16, r: 2.5); b.line([(12, 4), (12, 20)]); b.line([(5.5, 12), (9, 12)])
            b.line([(16.5, 10.25), (16.5, 13.75)]); b.line([(14.75, 12), (18.25, 12)])
        case .sun:
            b.circle(12, 12, 4)
            for i in 0..<8 {
                let a = Double(i) * .pi / 4
                b.line([(12 + 7 * CGFloat(cos(a)), 12 + 7 * CGFloat(sin(a))), (12 + 9.5 * CGFloat(cos(a)), 12 + 9.5 * CGFloat(sin(a)))])
            }
        case .moon:
            b.curve((19.5, 14.5), [.quad(18, 20, 11.5, 20), .quad(4, 20, 4, 12), .quad(4, 5.5, 10.5, 4.3), .quad(7.5, 8.5, 10, 12), .quad(13, 16, 19.5, 14.5)], closed: true)
        case .monitor:
            b.rect(3, 4, 18, 12, r: 2); b.line([(8, 20), (16, 20)]); b.line([(12, 16), (12, 20)])
        case .zoomIn:
            b.circle(11, 11, 7); b.line([(16, 16), (20.5, 20.5)]); b.line([(11, 8), (11, 14)]); b.line([(8, 11), (14, 11)])
        case .zoomOut:
            b.circle(11, 11, 7); b.line([(16, 16), (20.5, 20.5)]); b.line([(8, 11), (14, 11)])
        case .menu:
            b.line([(4, 7), (20, 7)]); b.line([(4, 12), (20, 12)]); b.line([(4, 17), (20, 17)])
        case .microphone:
            // Rounded microphone capsule, cradle arc, vertical stand, and horizontal base on the 24x24 grid (`UI-001`, `REQ-031-02`).
            b.rect(9, 3, 6, 11, r: 3)
            b.arc(12, 11, 6, start: 0, sweep: 180)
            b.line([(12, 17), (12, 21)]); b.line([(8, 21), (16, 21)])
        }
        return b
    }

    private static func folderOutline(_ b: inout AppIconPathBuilder) {
        b.curve((3, 7), [.quad(3, 5, 5, 5), .to(9.5, 5), .to(11.5, 7), .to(19, 7), .quad(21, 7, 21, 9), .to(21, 17), .quad(21, 19, 19, 19), .to(5, 19), .quad(3, 19, 3, 17)], closed: true)
    }

    private static func fileOutline(_ b: inout AppIconPathBuilder) {
        b.curve((14, 3), [.to(7, 3), .quad(5, 3, 5, 5), .to(5, 19), .quad(5, 21, 7, 21), .to(17, 21), .quad(19, 21, 19, 19), .to(19, 8)], closed: true)
        b.line([(14, 3), (14, 8), (19, 8)])
    }

    private static func eyeOutline(_ b: inout AppIconPathBuilder) {
        b.curve((2, 12), [.quad(7, 5, 12, 5), .quad(17, 5, 22, 12), .quad(17, 19, 12, 19), .quad(7, 19, 2, 12)], closed: true)
        b.circle(12, 12, 3)
    }

    private static func pinOutline(_ b: inout AppIconPathBuilder) {
        b.line([(12, 17), (12, 22)])
        b.line([(9, 3), (15, 3)])
        b.curve((10, 3), [.to(10, 9.5), .to(6.5, 13.3), .quad(6, 13.9, 6, 14.8), .to(6, 17), .to(18, 17), .to(18, 14.8), .quad(18, 13.9, 17.5, 13.3), .to(14, 9.5), .to(14, 3)])
    }
}

/// Which part of an icon a shape renders.
enum AppIconPart: Sendable {
    case stroke, fill
}

/// Scales the `24×24` geometry of `icon` into the available rect.
struct AppIconShape: Shape {
    let icon: AppIcon
    let part: AppIconPart

    func path(in rect: CGRect) -> Path {
        let geometry = icon.geometry
        let source = part == .stroke ? geometry.stroke : geometry.fill
        let scale = min(rect.width, rect.height) / 24
        let transform = CGAffineTransform(translationX: rect.minX + (rect.width - 24 * scale) / 2, y: rect.minY + (rect.height - 24 * scale) / 2)
            .scaledBy(x: scale, y: scale)
        return source.applying(transform)
    }
}

#if os(macOS)
/// Renders an `AppIcon` at `size` points in the current `foregroundStyle`; decorative by default (`UI-010`).
public struct AppIconView: View {
    public let icon: AppIcon
    public let size: CGFloat
    /// Stroke multiplier (`1` = 2 grid units); `0.85` for dense chrome, `1.15` for emphasis.
    public var weight: CGFloat
    /// VoiceOver label; `nil` keeps the icon decorative (hidden).
    public var label: String?

    public init(_ icon: AppIcon, size: CGFloat = 14, weight: CGFloat = 1, label: String? = nil) {
        self.icon = icon
        self.size = size
        self.weight = weight
        self.label = label
    }

    public var body: some View {
        let lineWidth = max(1, size / 24 * 2 * weight)
        ZStack {
            AppIconShape(icon: icon, part: .stroke)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            AppIconShape(icon: icon, part: .fill)
                .fill()
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(label ?? "")
        .accessibilityHidden(label == nil)
    }
}
#endif
