import AppKit
import Common

open class Window: TreeNode, Hashable {
    let windowId: UInt32
    let app: any AbstractApp
    var lastFloatingSize: CGSize?
    var isFullscreen: Bool = false
    var noOuterGapsInFullscreen: Bool = false
    var layoutReason: LayoutReason = .standard

    @MainActor
    init(id: UInt32, _ app: any AbstractApp, lastFloatingSize: CGSize?, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) {
        self.windowId = id
        self.app = app
        self.lastFloatingSize = lastFloatingSize
        super.init(parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    @MainActor static func get(byId windowId: UInt32) -> Window? { // todo make non optional
        isUnitTest
            ? Workspace.all.flatMap { $0.allLeafWindowsRecursive }.first(where: { $0.windowId == windowId })
            : MacWindow.allWindowsMap[windowId]
    }

    @MainActor
    func closeAxWindow() { die("Not implemented") }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(windowId)
    }

    func getAxSize() async throws -> CGSize? { die("Not implemented") }
    var title: String { get async throws { die("Not implemented") } }
    var isMacosFullscreen: Bool { get async throws { false } }
    var isMacosMinimized: Bool { get async throws { false } } // todo replace with enum MacOsWindowNativeState { normal, fullscreen, invisible }
    var isHiddenInCorner: Bool { die("Not implemented") }
    @MainActor
    func nativeFocus() { die("Not implemented") }
    func getAxRect() async throws -> Rect? { die("Not implemented") }
    func getCenter() async throws -> CGPoint? { try await getAxRect()?.center }

    func setAxFrame(_ topLeft: CGPoint?, _ size: CGSize?) { die("Not implemented") }
}

enum LayoutReason {
    case standard
    /// Reason for the cur temp layout is macOS native fullscreen, minimize, or hide
    case macos(prevBinding: BindingDataSnapshot)
}

struct BindingDataSnapshot {
    private weak var _parent: TreeNode?
    let parentKind: NonLeafTreeNodeKind
    let adaptiveWeight: CGFloat
    let index: Int
    private let childWeights: [TreeNodeWeightSnapshot]

    var parent: NonLeafTreeNodeObject? { _parent as? NonLeafTreeNodeObject }

    @MainActor
    init(_ data: BindingData, childWeights: [TreeNodeWeightSnapshot]) {
        _parent = data.parent
        parentKind = data.parent.kind
        adaptiveWeight = data.adaptiveWeight
        index = data.index
        self.childWeights = childWeights
    }

    @MainActor
    func restoreChildWeights() {
        guard let parent = parent as? TilingContainer, parent.layout == .tiles else { return }
        for childWeight in childWeights {
            childWeight.restore(in: parent)
        }
    }
}

struct TreeNodeWeightSnapshot {
    private weak var _node: TreeNode?
    private let weight: CGFloat

    @MainActor
    static func snapshot(from parent: NonLeafTreeNodeObject?) -> [TreeNodeWeightSnapshot] {
        guard let parent = parent as? TilingContainer, parent.layout == .tiles else { return [] }
        return parent.children.map { TreeNodeWeightSnapshot(node: $0, weight: $0.getWeight(parent.orientation)) }
    }

    private init(node: TreeNode, weight: CGFloat) {
        _node = node
        self.weight = weight
    }

    @MainActor
    func restore(in parent: TilingContainer) {
        guard let node = _node, node.parent === parent else { return }
        node.setWeight(parent.orientation, weight)
    }
}

extension Window {
    var isFloating: Bool { parent is Workspace } // todo drop. It will be a source of bugs when sticky is introduced

    @discardableResult
    @MainActor
    func bindAsFloatingWindow(to workspace: Workspace) -> BindingData? {
        bind(to: workspace, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }

    func asMacWindow() -> MacWindow { self as! MacWindow }
}
