import Foundation

/// Supported native Zero-WebKit diagram families in Markdown Preview (`REQ-004`, `AR-002`, `SEC-004`).
public enum MarkdownDiagramKind: String, Equatable, Sendable {
    case markmap
    case flowchart
    case sequence
    case state
}

/// Visual node shape in `flowchart` / `stateDiagram` blocks (`REQ-004`).
public enum FlowchartNodeShape: String, Equatable, Sendable {
    case rect
    case rounded
    case stadium
    case diamond
    case circle
}

/// Visual connector stroke style (`REQ-004`).
public enum DiagramEdgeStyle: String, Equatable, Sendable {
    case solid
    case dotted
    case thick
}

/// Primary layout axis for `flowchart` / `graph` / `stateDiagram` diagrams (`REQ-004`).
public enum DiagramDirection: String, Equatable, Sendable {
    case leftToRight
    case topToBottom
    case rightToLeft
    case bottomToTop
}

/// 2D layout coordinate in unscaled diagram points (`100%` baseline) (`REQ-004`).
public struct DiagramPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Positioned hierarchical node in a `Markmap` or `mindmap` layout (`REQ-004`).
public struct MindmapPositionedNode: Equatable, Sendable {
    public let id: Int
    public let parentID: Int?
    public let label: String
    public let depth: Int
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(id: Int, parentID: Int?, label: String, depth: Int, x: Double, y: Double, width: Double, height: Double) {
        self.id = id
        self.parentID = parentID
        self.label = label
        self.depth = depth
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Positioned node in a `flowchart`, `graph`, or `stateDiagram` layout (`REQ-004`).
public struct GraphPositionedNode: Equatable, Sendable {
    public let id: String
    public let label: String
    public let shape: FlowchartNodeShape
    public let subgraphTitle: String?
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(id: String, label: String, shape: FlowchartNodeShape, subgraphTitle: String?, x: Double, y: Double, width: Double, height: Double) {
        self.id = id
        self.label = label
        self.shape = shape
        self.subgraphTitle = subgraphTitle
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Positioned directed edge in a `flowchart`, `graph`, or `stateDiagram` layout (`REQ-004`).
public struct GraphPositionedEdge: Equatable, Sendable {
    public let fromID: String
    public let toID: String
    public let label: String?
    public let style: DiagramEdgeStyle
    public let fromPoint: DiagramPoint
    public let toPoint: DiagramPoint

    public init(fromID: String, toID: String, label: String?, style: DiagramEdgeStyle, fromPoint: DiagramPoint, toPoint: DiagramPoint) {
        self.fromID = fromID
        self.toID = toID
        self.label = label
        self.style = style
        self.fromPoint = fromPoint
        self.toPoint = toPoint
    }
}

/// Positioned message arrow in a `sequenceDiagram` layout (`REQ-004`).
public struct SequenceMessageLayout: Equatable, Sendable {
    public let fromLane: Int
    public let toLane: Int
    public let label: String
    public let isDashed: Bool
    public let rowY: Double

    public init(fromLane: Int, toLane: Int, label: String, isDashed: Bool, rowY: Double) {
        self.fromLane = fromLane
        self.toLane = toLane
        self.label = label
        self.isDashed = isDashed
        self.rowY = rowY
    }
}

/// Immutable, pre-laid-out vector diagram model ready for zoom-scaled SwiftUI `Canvas` rendering (`REQ-004`, `AR-004`).
public enum MarkdownDiagramModel: Equatable, Sendable {
    case mindmap(nodes: [MindmapPositionedNode], canvasWidth: Double, canvasHeight: Double)
    case graph(kind: MarkdownDiagramKind, direction: DiagramDirection, nodes: [GraphPositionedNode], edges: [GraphPositionedEdge], canvasWidth: Double, canvasHeight: Double)
    case sequence(participants: [String], laneCenters: [Double], messages: [SequenceMessageLayout], canvasWidth: Double, canvasHeight: Double)

    public var kind: MarkdownDiagramKind {
        switch self {
        case .mindmap: return .markmap
        case .graph(let k, _, _, _, _, _): return k
        case .sequence: return .sequence
        }
    }
}

/// Outcome of bounded native diagram parsing (`CWE-400`, `CWE-674`, `SEC-004`).
public enum MarkdownDiagramParseOutcome: Equatable, Sendable {
    case diagram(MarkdownDiagramModel)
    case unsupportedOrOversized
}

/// Single key/value display entry for the structured YAML frontmatter preview card (`REQ-003`).
public struct GFMPreviewFrontmatterEntry: Equatable, Sendable {
    public let key: String
    public let displayValue: String

    public init(key: String, displayValue: String) {
        self.key = key
        self.displayValue = displayValue
    }
}

/// Enriched GFM preview document carrying structured YAML frontmatter entries, fence language tags, and pre-laid-out native diagrams (`REQ-003`, `REQ-004`).
public struct GFMPreviewEnrichedDocument: Equatable, Sendable {
    public let revision: BufferRevision
    public let frontmatterEntries: [GFMPreviewFrontmatterEntry]
    public let blocks: [GFMPreviewBlock]
    public let orderedOrdinals: [Int]
    public let imageEntriesByBlock: [[GFMPreviewImageEntry]]
    public let fenceLanguagesByBlock: [String?]
    public let diagramsByBlock: [MarkdownDiagramModel?]

    public init(
        revision: BufferRevision,
        frontmatterEntries: [GFMPreviewFrontmatterEntry] = [],
        blocks: [GFMPreviewBlock],
        fenceLanguagesByBlock: [String?] = [],
        diagramsByBlock: [MarkdownDiagramModel?] = []
    ) {
        self.revision = revision
        self.frontmatterEntries = frontmatterEntries
        self.blocks = blocks
        self.orderedOrdinals = MarkdownPreviewProjector.computeOrderedOrdinals(for: blocks)
        self.imageEntriesByBlock = MarkdownPreviewProjector.computeImageEntries(for: blocks)
        self.fenceLanguagesByBlock = fenceLanguagesByBlock
        self.diagramsByBlock = diagramsByBlock
    }
}
