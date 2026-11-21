import Foundation
import SwiftUI

/// Pure SwiftUI vector rendering of the official Concept E2 Feather-in-Inverted-Triangle brand logo (`docs/design/assets/logo-e2-refined.svg`) (`UI-001`).
public struct SwiftEditBrandLogoView: View {
    private static let groundColor = RGBAColorToken(hex: SwiftEditBrandLogoGeometry.groundHex).swiftUIColor
    private static let strokeColor = RGBAColorToken(hex: SwiftEditBrandLogoGeometry.triangleStrokeHex).swiftUIColor
    private static let topColor = RGBAColorToken(hex: SwiftEditBrandLogoGeometry.featherTopHex).swiftUIColor
    private static let bottomColor = RGBAColorToken(hex: SwiftEditBrandLogoGeometry.featherBottomHex).swiftUIColor
    private static let allBarbs: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (292, 186, 262, 174), (292, 204, 260, 192), (292, 222, 258, 210),
        (292, 240, 258, 228), (292, 258, 258, 246), (292, 276, 258, 264),
        (292, 294, 259, 282), (292, 312, 261, 300), (292, 330, 262, 318),
        (292, 348, 264, 336), (292, 366, 268, 354),
        (292, 204, 318, 194), (292, 222, 320, 212), (292, 240, 322, 230),
        (292, 258, 322, 248), (292, 276, 320, 266), (292, 294, 316, 284),
        (292, 312, 313, 302), (292, 330, 310, 320),
    ]

    public let size: CGFloat

    public init(size: CGFloat = CGFloat(SwiftEditBrandLogoGeometry.topBarLogoSize)) {
        self.size = size
    }

    public var body: some View {
        Canvas { context, canvasSize in
            let scale = min(canvasSize.width, canvasSize.height) / CGFloat(SwiftEditBrandLogoGeometry.viewBoxSize)

            // Rounded square ground (#0B0614, rx=96/512)
            let bgRect = CGRect(x: 0, y: 0, width: 512 * scale, height: 512 * scale)
            let bgPath = Path(roundedRect: bgRect, cornerRadius: CGFloat(SwiftEditBrandLogoGeometry.cornerRadius) * scale)
            context.fill(bgPath, with: .color(Self.groundColor))

            // Inverted triangle outline (#A78BFA, stroke-width=16)
            var triangle = Path()
            triangle.move(to: CGPoint(x: 56 * scale, y: 96 * scale))
            triangle.addLine(to: CGPoint(x: 456 * scale, y: 96 * scale))
            triangle.addLine(to: CGPoint(x: 256 * scale, y: 460 * scale))
            triangle.closeSubpath()
            context.stroke(
                triangle,
                with: .color(Self.strokeColor),
                style: StrokeStyle(lineWidth: 16 * scale, lineJoin: .round)
            )

            // Feather group transform: translate(262 250) scale(0.74) translate(-300 -305)
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                let tx = (262 + (x - 300) * 0.74) * scale
                let ty = (250 + (y - 305) * 0.74) * scale
                return CGPoint(x: tx, y: ty)
            }

            var feather = Path()
            feather.move(to: pt(282, 470))
            feather.addLine(to: pt(290, 432))
            feather.addCurve(to: pt(326, 262), control1: pt(322, 402), control2: pt(330, 330))
            feather.addCurve(to: pt(372, 178), control1: pt(322, 222), control2: pt(340, 192))
            feather.addCurve(to: pt(265, 160), control1: pt(350, 148), control2: pt(300, 126))
            feather.addCurve(to: pt(244, 330), control1: pt(240, 185), control2: pt(240, 260))
            feather.addCurve(to: pt(268, 420), control1: pt(246, 368), control2: pt(254, 400))
            feather.addLine(to: pt(264, 458))
            feather.addLine(to: pt(260, 472))
            feather.closeSubpath()

            context.fill(
                feather,
                with: .linearGradient(
                    Gradient(colors: [Self.topColor, Self.bottomColor]),
                    startPoint: pt(290, 140),
                    endPoint: pt(290, 472)
                )
            )

            // Central rachis (#0B0614)
            var rachis = Path()
            rachis.move(to: pt(292, 160))
            rachis.addCurve(to: pt(290, 432), control1: pt(294, 250), control2: pt(294, 350))
            context.stroke(
                rachis,
                with: .color(Self.groundColor),
                style: StrokeStyle(lineWidth: 7 * 0.74 * scale, lineCap: .round)
            )

            // Feather barbs (#0B0614)
            var barbs = Path()
            for (x1, y1, x2, y2) in Self.allBarbs {
                barbs.move(to: pt(x1, y1))
                barbs.addLine(to: pt(x2, y2))
            }
            context.stroke(
                barbs,
                with: .color(Self.groundColor),
                style: StrokeStyle(lineWidth: 9 * 0.74 * scale, lineCap: .round)
            )
        }
        .frame(width: size, height: size)
        .accessibilityLabel("SwiftEdit Brand Logo")
    }
}
